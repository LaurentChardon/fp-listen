#!/bin/sh
# Copyright Dan Langille dan@langille.org
#
# This script originated as fp-daemon.sh sometime around 2000.
#
# Back then, it was run via https://cr.yp.to/daemontools.html
# This was several years before daemon(8) became available.
#
# The script was converted to run under daemon(8) in Jul 2020.
#
# I say converted, when really all that happened was:
#
# * creation of an rc.d script
# * package modification to install in different locations
# * logger(1) calls changed to echo(1)
#
# The script itself wasn't modified much in this conversion.
#

# include our local parameters

. /usr/local/etc/freshports/freshports.sh

CP='/bin/cp'

# we do not use -i because that would fail when re re-run a commit
MV='/bin/mv'

RM='/bin/rm'

PERL='/usr/local/bin/perl'

#
# sanity checking upon startup
#

check_for_jobs() {
	#
	# This flag file is only set by a job run by this script.
	# A race condition should never arise.
	#
	FLAG="${FRESHPORTS_FLAGDIR}/job_waiting"
	if [ -f ${FLAG} ]
	then
		echo 'yes, there is a job waiting'
		${PERL} ./job-waiting.pl
		if [ $? -eq 0 ]
		then
			echo "job-waiting.pl finishes normally"
		else
			echo "FATAL job-waiting.pl finished with an error"
		fi
		rm ${FLAG}
	fi
}

echo "starting up!"

if [ ! -d ${SCRIPTDIR} ]
then
	echo "Required directory does not exist: ${SCRIPTDIR}"
	exit
fi

# NOTE this is under the ingress user:
if [ ! -d ${INGRESS_MSGDIR}/incoming ]
then
	echo "Required directory does not exist: ${FRESHPORTS_MSGDIR}/incoming/"
	exit
fi

if [ ! -d ${FRESHPORTS_MSGDIR}/recent ]
then
	echo "Required directory does not exist: ${FRESHPORTS_MSGDIR}/recent/"
	exit
fi

if [ ! -d ${FRESHPORTS_MSGDIR}/retry ]
then
	echo "Required directory does not exist: ${FRESHPORTS_MSGDIR}/retry/"
	exit	
fi

echo incoming: ${INGRESS_MSGDIR}/incoming
echo recent:   ${FRESHPORTS_MSGDIR}/recent
echo recent:   ${FRESHPORTS_MSGDIR}/retry
echo ready

while :
	do
	cd ${SCRIPTDIR}

	OUTPUT="${FRESHPORTS_MSGDIR}/recent"
	INCOMING=${INGRESS_MSGDIR}/incoming
	FILES=`echo ${INCOMING}/*`

	if [ -e 'OFFLINE' ]
	then
		echo "system is OFFLINE: ${SCRIPTDIR}/OFFLINE exists"
		break
	else
		# id the list of files is not just the directory name...
		if [ "$FILES" != "${INCOMING}/*" ]
		then
			echo "found stuff in ${INCOMING}"
			for file in $FILES
			do
				if [ -e 'OFFLINE' ]
				then
					echo "system is OFFLINE: ${SCRIPTDIR}/OFFLINE exists"
					break
				else
					# file is a fully qualfied pathname, not relative.
					# e.g. /var/db/freshports/message-queues/incoming/2020.07.02.13.35.18.000000.1b49ab9b7bb15abe91a9e0610fa676053f8fe021.xml
					echo "processing ${file}"

					# e.g. 2020.07.02.13.35.18.000000.1b49ab9b7bb15abe91a9e0610fa676053f8fe021.xml
					filename=`basename ${file}`

					#
					# load the XML into the database
					#

					echo "loading that XML into the database via load_xml_into_db_git.pl"

					echo ${PERL} ${SCRIPTDIR}/load_xml_into_db_git.pl ${file} ${OUTPUT}/${filename}.loading ${OUTPUT}/${filename}.errors
					${PERL} ${SCRIPTDIR}/load_xml_into_db_git.pl ${file} > ${OUTPUT}/${filename}.loading 2>${OUTPUT}/${filename}.errors
					RESULT=$?

					if [ -f ${OUTPUT}/${filename}.errors ]
					then
						#  found errors
						if [ -s ${OUTPUT}/${filename}.errors ]
						then
							# do nothing, leave that file there.
						else
							rm ${OUTPUT}/${filename}.errors
						fi
					fi

					echo "XML loading finished"

					echo "result=$RESULT"
					basename=`basename ${file}`
					if [ $RESULT -eq 0 ]
					then
						# the output of the command is enclosed in "''" in case the ls output starts with a - and would therefore be interpreted as an argument
 						echo "'`ls -l ${file}`'"
						echo "'`ls -ld ${FRESHPORTS_MSGDIR}/incoming/`'"
						echo "'`ls -ld ${FRESHPORTS_MSGDIR}/recent/`'"

						# use -p to preserve mtime
						${CP} -p ${file} ${OUTPUT}

						# using mv caused: /usr/local/bin/readproctitle service errors: ...message-queues/recent/2019.07.15.15.42.07.48391.txt.raw: set owner/group (was: 10002/10001): Operation not permitted\nmv: /var/db/freshports/message-queues/recent/2019.07.15.15.43.31.53460.txt.raw: set owner/group (was: 10002/10001): Operation not permitted\nmv: /var/db/freshports/message-queues/recent/2019.07.15.15.45.39.56551.txt.raw: set owner/group (was: 10002/10001): Operation not permitted\n
						# even when using this example:
						# [dan@dev-ingress01:~] $ ls -l ~ingress/message-queues/ ~freshports/message-queues/
						# /var/db/freshports/message-queues/:
						# total 248
						# drwxr-xr-x  18 freshports  freshports   18 Jul  2 03:16 archive
						# 
						# drwxr-xr-x  10 freshports  freshports   18 Jun 10 22:03 retry
						# 
						# /var/db/ingress/message-queues/:
						# total 3
						# drwxr-xr-x  2 root     ingress     10 Mar 20 13:53 DUPS
						# drwxrwxr-x  2 ingress  freshports   2 Jul 15 15:29 incoming
						# 
						${RM} ${file}
					else
						echo "${file} fails...."

						# move the original email to the retry directory
						${MV} ${file} ${FRESHPORTS_MSGDIR}/retry/

						# and any other files as well
						${MV}  ${FRESHPORTS_MSGDIR}/recent/${filename}.* ${FRESHPORTS_MSGDIR}/retry/
					fi

					check_for_jobs
				fi
			done
		else
			check_for_jobs
		fi
	fi
	sleep 3
done
