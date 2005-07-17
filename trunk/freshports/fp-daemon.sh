#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.10 2005-07-17 15:28:29 dan Exp $
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

for q in $QUEUES
	do

	if [ ! -d ${SCRIPTDIR}/${q}/scripts ]
	then
		echo "Required directory does not exist: ${SCRIPTDIR}/${q}/scripts/"
		exit
	fi

	if [ ! -d ${BASEDIR}/${q}/msgs/FreeBSD/incoming ]
	then
		echo "Required directory does not exist: ${BASEDIR}/${q}/msgs/FreeBSD/incoming"
		exit
	fi

	if [ ! -d ${BASEDIR}/${q}/msgs/FreeBSD/recent/ ]
	then
		echo "Required directory does not exist: ${BASEDIR}/${q}/msgs/FreeBSD/recent/"
		exit
	fi

	if [ ! -d ${BASEDIR}/${q}/msgs/FreeBSD/retry/ ]
	then
		echo "Required directory does not exist: ${BASEDIR}/${q}/msgs/FreeBSD/retry/"
		exit
	fi
done

while .
	do
	for q in $QUEUES
		do
		cd ${SCRIPTDIR}/${q}/scripts/

		INCOMING=${BASEDIR}/${q}/msgs/FreeBSD/incoming
		echo "looking in ${INCOMING}"
		FILES=`echo ${INCOMING}/*`

		if [ "$FILES" != "${INCOMING}/*" ]
		then
			for i in $FILES
				do
				echo "processing $i"

				./freebsd-cvs.sh $i

				RESULT=$?
				echo result=$RESULT
				basename=`basename ${i}`
				if [ $RESULT -eq 0 ]
				then
					mv ${i} ${BASEDIR}/${q}/msgs/FreeBSD/recent/${basename}.raw
				else
					echo $i fails....

					# move the original email to the retry directory
					mv $i ${BASEDIR}/${q}/msgs/FreeBSD/retry/

					# and any other files as well
					mv  ${BASEDIR}/${q}/msgs/FreeBSD/recent/${basename}.* ${BASEDIR}/${q}/msgs/FreeBSD/retry/
				fi
			done
		else
			echo "nothing found there"
		fi
		sleep 3
	done
done
