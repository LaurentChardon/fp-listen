#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.9 2004-12-23 19:50:09 dan Exp $
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

					# move the files to the retry directory
					mv $i ${BASEDIR}/${q}/msgs/FreeBSD/retry/

					if [ -f  ${BASEDIR}/${q}/msgs/FreeBSD/recent/${basename}.xml ]
					then
						mv  ${BASEDIR}/${q}/msgs/FreeBSD/recent/${basename}.xml ${BASEDIR}/${q}/msgs/FreeBSD/retry/
					fi

					if [ -f  ${BASEDIR}/${q}/msgs/FreeBSD/recent/${basename}.errors ]
					then
						mv  ${BASEDIR}/${q}/msgs/FreeBSD/recent/${basename}.errors ${BASEDIR}/${q}/msgs/FreeBSD/retry/
					fi

					if [ -f  ${BASEDIR}/${q}/msgs/FreeBSD/recent/${basename}.loading ]
					then
						mv  ${BASEDIR}/${q}/msgs/FreeBSD/recent/${basename}.loading ${BASEDIR}/${q}/msgs/FreeBSD/retry/
					fi
				fi
			done
		else
			echo "nothing found there"
		fi
		sleep 3
	done
done
