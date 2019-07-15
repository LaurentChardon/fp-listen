#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.17 2006-11-10 14:08:26 dan Exp $
#
# Copyright (c) 2001-2003 DVL Software
#
#
# include our local parameters

. config.sh

LOGGERTAG='fp-daemon'

CP='/bin/cp'

# we do not use -i because that would fail when re re-run a commit
MV='/bin/mv'

RM='/bin/rm'

#
# sanity checking upon startup
#

check_for_jobs() {
	#
	# This flag file is only set by a job run by this script.
	# A race condition should never arise.
	#
	FLAG="${FLAGDIR}/job_waiting"
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

if [ ! -d ${INGRESSDIR}/message-queues/incoming ]
then
	${LOGGER} -t ${LOGGERTAG} "Required directory does not exist: ${INGRESSDIR}/message-queues/incoming"
	exit
fi

if [ ! -d ${BASEDIR}/message-queues/recent/ ]
then
	${LOGGER} -t ${LOGGERTAG} "Required directory does not exist: ${BASEDIR}/message-queues/recent/"
	exit
fi

if [ ! -d ${BASEDIR}/message-queues/retry/ ]
then
	${LOGGER} -t ${LOGGERTAG} "Required directory does not exist: ${BASEDIR}/message-queues/retry/"
	exit
fi

while :
	do
	cd ${SCRIPTDIR}

	INCOMING=${INGRESSDIR}/message-queues/incoming
	FILES=`echo ${INCOMING}/*`

	if [ -e 'OFFLINE' ]
	then
		${LOGGER} -t ${LOGGERTAG} "system is OFFLINE: ${SCRIPTDIR}/OFFLINE exists"
		break
	else
		if [ "$FILES" != "${INCOMING}/*" ]
		then
			${LOGGER} -t ${LOGGERTAG} "found stuff in ${INCOMING}"
			for i in $FILES
			do
				if [ -e 'OFFLINE' ]
				then
					${LOGGER} -t ${LOGGERTAG} "system is OFFLINE: ${SCRIPTDIR}/OFFLINE exists"
					break
				else
					${LOGGER} -t ${LOGGERTAG} "processing ${i}"

					/bin/sh ./freebsd-cvs.sh ${i}

					RESULT=$?
					${LOGGER} -t ${LOGGERTAG} "result=$RESULT"
					basename=`basename ${i}`
					if [ $RESULT -eq 0 ]
					then
						${LOGGER} -t ${LOGGERTAG} - "'`ls -l ${i}`'"
						${LOGGER} -t ${LOGGERTAG} - "'`ls -ld /var/db/ingress/message-queues/incoming`'"
						${LOGGER} -t ${LOGGERTAG} - "'`ls -ld ${BASEDIR}/message-queues/recent/`'"
						${CP} ${i} ${BASEDIR}/message-queues/recent/${basename}.raw
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
						${RM} ${i}
					else
						${LOGGER} -t ${LOGGERTAG} "${i} fails...."

						# move the original email to the retry directory
						${MV} ${i} ${BASEDIR}/message-queues/retry/

						# and any other files as well
						${MV}  ${BASEDIR}/message-queues/recent/${basename}.* ${BASEDIR}/message-queues/retry/
					fi

					check_for_jobs
				fi
			done
		else
			check_for_jobs
			${LOGGER} -t ${LOGGERTAG} "nothing found ${INCOMING}"
		fi
	fi
	sleep 3
done
