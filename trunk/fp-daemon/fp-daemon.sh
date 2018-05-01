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
					${LOGGER} -t ${LOGGERTAG} "processing $i"

					/bin/sh ./freebsd-cvs.sh $i

					RESULT=$?
					${LOGGER} -t ${LOGGERTAG} "result=$RESULT"
					basename=`basename ${i}`
					if [ $RESULT -eq 0 ]
					then
						mv ${i} ${BASEDIR}/message-queues/recent/${basename}.raw
					else
						${LOGGER} -t ${LOGGERTAG} "$i fails...."

						# move the original email to the retry directory
						mv $i ${BASEDIR}/message-queues/retry/

						# and any other files as well
						mv  ${BASEDIR}/message-queues/recent/${basename}.* ${BASEDIR}/message-queues/retry/
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
