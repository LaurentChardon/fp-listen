#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.3 2002-02-22 17:03:37 dan Exp $
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
		done
	fi
	sleep 1
done
