#!/bin/sh
touch ${HOME}/laststarted
#echo start
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
#	echo .
	sleep 1
done
