#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.4 2002-02-24 02:31:04 dan Exp $
#
# Copyright (c) 2001-2002 DVL Software
#
MSGSDIR=${HOME}/msgs/FreeBSD/incoming

cd ${MSGSDIR}
while .
	do
	FILES=`echo *`

	if [ "$FILES" != "*" ]
	then
		for i in $FILES
			do
			$HOME/scripts/freebsd-cvs.sh $i

			RESULT=$?

			echo result=$RESULT

			if [ $RESULT -eq 0 ]
			then
				mv $i $HOME/msgs/FreeBSD/raw/
			else
				echo $i fails....
				mv $i $HOME/msgs/FreeBSD/retry/
			fi
		done
	fi
	sleep 1
done
