#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.5 2002-03-22 15:06:47 dan Exp $
#
# Copyright (c) 2001-2002 DVL Software
#
BASEDIR=${HOME}
MSGSDIR=${BASEDIR}/msgs/FreeBSD/incoming

cd ${MSGSDIR}
while .
	do
	FILES=`echo *`

	if [ "$FILES" != "*" ]
	then
		for i in $FILES
			do
			${BASEDIR}/scripts/freebsd-cvs.sh $i

			RESULT=$?

			echo result=$RESULT

			if [ $RESULT -eq 0 ]
			then
				mv $i ${BASEDIR}/msgs/FreeBSD/raw/
			else
				echo $i fails....
				mv $i ${BASEDIR}/msgs/FreeBSD/retry/
			fi
		done
	fi
	sleep 1
done
