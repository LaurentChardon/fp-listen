#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.17 2006-11-10 14:08:26 dan Exp $
#
# Copyright (c) 2001-2003 DVL Software
#
#
# include our local parameters

. /usr/local/etc/freshports/daemon-config.sh

LOGGERTAG='fp-freshports'

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
		${LOGGER} -t ${LOGGERTAG} 'yes, there is a job waiting'
		${PERL} ./job-waiting.pl
		if [ $? -eq 0 ]
		then
			${LOGGER} -t ${LOGGERTAG} "job-waiting.pl finishes normally"
		else
			${LOGGER} -t ${LOGGERTAG} "FATAL job-waiting.pl finished with an error"
		fi
		rm ${FLAG}
	fi
}

${LOGGER} -t ${LOGGERTAG} "starting up!"

if [ ! -d ${SCRIPTDIR} ]
then
	${LOGGER} -t ${LOGGERTAG} "Required directory does not exist: ${SCRIPTDIR}"
	exit
fi

if [ ! -d ${FRESHPORTS_MSGDIR}/recent ]
then
	${LOGGER} -t ${LOGGERTAG} "Required directory does not exist: ${FRESHPORTS_MSGDIR}/recent/"
	exit
fi

if [ ! -d ${FRESHPORTS_MSGDIR}/retry ]
then
	${LOGGER} -t ${LOGGERTAG} "Required directory does not exist: ${FRESHPORTS_MSGDIR}/retry/"
	exit	
fi

while :
	do
	cd ${SCRIPTDIR}

	OUTPUT="${FRESHPORTS_MSGDIR}/recent"
	INCOMING=${INGRESS_MSGDIR}/incoming
	FILES=`echo ${INCOMING}/*`

	if [ -e 'OFFLINE' ]
	then
		${LOGGER} -t ${LOGGERTAG} "system is OFFLINE: ${SCRIPTDIR}/OFFLINE exists"
		break
	else
		# id the list of files is not just the directory name...
		if [ "$FILES" != "${INCOMING}/*" ]
		then
			${LOGGER} -t ${LOGGERTAG} "found stuff in ${INCOMING}"
			for file in $FILES
			do
				if [ -e 'OFFLINE' ]
				then
					${LOGGER} -t ${LOGGERTAG} "system is OFFLINE: ${SCRIPTDIR}/OFFLINE exists"
					break
				else
					# file is a fully qualfied pathname, not relative.
					# e.g. /var/db/freshports/message-queues/incoming/2020.07.02.13.35.18.000000.1b49ab9b7bb15abe91a9e0610fa676053f8fe021.xml
					${LOGGER} -t ${LOGGERTAG} "processing ${file}"

					# e.g. 2020.07.02.13.35.18.000000.1b49ab9b7bb15abe91a9e0610fa676053f8fe021.xml
					filename=`basename ${file}`

					#
					# load the XML into the database
					#

					${LOGGER} -t ${LOGGERTAG} "loading that XML into the database via load_xml_into_db_git.pl"

					${LOGGER} -t ${LOGGERTAG} ${PERL} ${SCRIPTDIR}/load_xml_into_db_git.pl ${file} ${OUTPUT}/${filename}.loading ${OUTPUT}/${filename}.errors
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

					${LOGGER} -t ${LOGGERTAG} "XML loading finished"

					${LOGGER} -t ${LOGGERTAG} "result=$RESULT"
					basename=`basename ${file}`
					if [ $RESULT -eq 0 ]
					then
						# the output of the command is enclosed in "''" in case the ls output starts with a - and would therefore be interpreted as an argument
 						${LOGGER} -t ${LOGGERTAG} "'`ls -l ${file}`'"
						${LOGGER} -t ${LOGGERTAG} "'`ls -ld ${FRESHPORTS_MSGDIR}/incoming/`'"
						${LOGGER} -t ${LOGGERTAG} "'`ls -ld ${FRESHPORTS_MSGDIR}/recent/`'"

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
						${LOGGER} -t ${LOGGERTAG} "${file} fails...."

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
