#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.14 2006-09-11 23:05:21 dan Exp $
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
	FLAG="${SCRIPTDIR}/${q}/dynamic/job_waiting"
	if [ -f ${FLAG} ]
	then
		logger -t ${LOGGERTAG} 'yes, there is a job waiting'
		perl ./job-waiting.pl

		rm ${FLAG}
	fi
}

logger -t ${LOGGERTAG} "starting up!"

for q in $QUEUES
	do

	if [ ! -d ${SCRIPTDIR}/${q}/scripts ]
	then
		logger -t ${LOGGERTAG} "Required directory does not exist: ${SCRIPTDIR}/${q}/scripts/"
		exit
	fi

	if [ ! -d ${BASEDIR}/${q}/msgs/FreeBSD/incoming ]
	then
		logger -t ${LOGGERTAG} "Required directory does not exist: ${BASEDIR}/${q}/msgs/FreeBSD/incoming"
		exit
	fi

	if [ ! -d ${BASEDIR}/${q}/msgs/FreeBSD/recent/ ]
	then
		logger -t ${LOGGERTAG} "Required directory does not exist: ${BASEDIR}/${q}/msgs/FreeBSD/recent/"
		exit
	fi

	if [ ! -d ${BASEDIR}/${q}/msgs/FreeBSD/retry/ ]
	then
		logger -t ${LOGGERTAG} "Required directory does not exist: ${BASEDIR}/${q}/msgs/FreeBSD/retry/"
		exit
	fi
done

echo things

while .
	do
	for q in $QUEUES
		do
		cd ${SCRIPTDIR}/${q}/scripts/

		INCOMING=${BASEDIR}/${q}/msgs/FreeBSD/incoming
		FILES=`echo ${INCOMING}/*`

		if [ -e 'OFFLINE' ]
		then
			logger -t ${LOGGERTAG} "system is OFFLINE: ${SCRIPTDIR}/${q}/scripts/OFFLINE exists"
			break
		else
			if [ "$FILES" != "${INCOMING}/*" ]
			then
				logger -t ${LOGGERTAG} "found stuff in ${INCOMING}"
				for i in $FILES
				do
					if [ -e 'OFFLINE' ]
					then
						logger -t ${LOGGERTAG} "system is OFFLINE: ${SCRIPTDIR}/${q}/scripts/OFFLINE exists"
						break
					else
						logger -t ${LOGGERTAG} "processing $i"

						./freebsd-cvs.sh $i

						RESULT=$?
						logger -t ${LOGGERTAG} "result=$RESULT"
						basename=`basename ${i}`
						if [ $RESULT -eq 0 ]
						then
							mv ${i} ${BASEDIR}/${q}/msgs/FreeBSD/recent/${basename}.raw
						else
							logger -t ${LOGGERTAG} "$i fails...."

							# move the original email to the retry directory
							mv $i ${BASEDIR}/${q}/msgs/FreeBSD/retry/

							# and any other files as well
							mv  ${BASEDIR}/${q}/msgs/FreeBSD/recent/${basename}.* ${BASEDIR}/${q}/msgs/FreeBSD/retry/
						fi

						check_for_jobs
					fi
				done
			else
				check_for_jobs
#				logger -t ${LOGGERTAG} "nothing found ${INCOMING}"
			fi
		fi
		sleep 3
	done
done
