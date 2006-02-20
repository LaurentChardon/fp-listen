#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.12 2006-02-20 17:41:40 dan Exp $
#
# Copyright (c) 2001-2003 DVL Software
#
#
# include our local parameters
#
. config.sh

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
		logger fp-damon 'yes, there is a job waiting'
		perl ./job-waiting.pl

		rm ${FLAG}
	fi
}


for q in $QUEUES
	do

	if [ ! -d ${SCRIPTDIR}/${q}/scripts ]
	then
		logger fp-daemon "Required directory does not exist: ${SCRIPTDIR}/${q}/scripts/"
		exit
	fi

	if [ ! -d ${BASEDIR}/${q}/msgs/FreeBSD/incoming ]
	then
		logger fp-daemon "Required directory does not exist: ${BASEDIR}/${q}/msgs/FreeBSD/incoming"
		exit
	fi

	if [ ! -d ${BASEDIR}/${q}/msgs/FreeBSD/recent/ ]
	then
		logger fp-daemon "Required directory does not exist: ${BASEDIR}/${q}/msgs/FreeBSD/recent/"
		exit
	fi

	if [ ! -d ${BASEDIR}/${q}/msgs/FreeBSD/retry/ ]
	then
		logger fp-daemon "Required directory does not exist: ${BASEDIR}/${q}/msgs/FreeBSD/retry/"
		exit
	fi
done

while .
	do
	for q in $QUEUES
		do
		cd ${SCRIPTDIR}/${q}/scripts/

		if [ -e 'OFFLINE' ]
		then
			logger fp-daemon "system is OFFLINE: ${SCRIPTDIR}/${q}/scripts/OFFLINE exists"
		else
			INCOMING=${BASEDIR}/${q}/msgs/FreeBSD/incoming
			FILES=`echo ${INCOMING}/*`

			if [ "$FILES" != "${INCOMING}/*" ]
			then
				logger fp-daemon "found stuff in ${INCOMING}"
				for i in $FILES
					do
					logger fp-daemon "processing $i"

					./freebsd-cvs.sh $i

					RESULT=$?
					logger fp-daemon "result=$RESULT"
					basename=`basename ${i}`
					if [ $RESULT -eq 0 ]
					then
						mv ${i} ${BASEDIR}/${q}/msgs/FreeBSD/recent/${basename}.raw
					else
						logger fp-daemon "$i fails...."

						# move the original email to the retry directory
						mv $i ${BASEDIR}/${q}/msgs/FreeBSD/retry/

						# and any other files as well
						mv  ${BASEDIR}/${q}/msgs/FreeBSD/recent/${basename}.* ${BASEDIR}/${q}/msgs/FreeBSD/retry/
					fi

					check_for_jobs
				done
			else
				check_for_jobs
				logger fp-daemon "nothing found ${INCOMING}"
			fi
		fi
		sleep 3
	done
done
