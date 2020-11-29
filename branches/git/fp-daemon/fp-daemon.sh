#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.17 2006-11-10 14:08:26 dan Exp $
#
# Copyright (c) 2001-2003 DVL Software
#
#
# include our local parameters

. /usr/local/etc/freshports/fp-daemon.sh

CP='/bin/cp'

# we do not use -i because that would fail when re re-run a commit
MV='/bin/mv'

RM='/bin/rm'

#
# sanity checking upon startup
#

echo "starting up!"

if [ ! -d ${SCRIPTDIR} ]
then
	echo "Required directory does not exist: ${SCRIPTDIR}"
	exit
fi

if [ ! -d ${FP_DAEMON_INGRESSDIR}/message-queues/incoming ]
then
	echo "Required directory does not exist: ${FP_DAEMON_INGRESSDIR}/message-queues/incoming"
	exit
fi

while :
	do
	cd ${SCRIPTDIR}

	INCOMING=${FP_DAEMON_INGRESSDIR}/message-queues/incoming
	FILES=`echo ${INCOMING}/*`

	if [ -e 'OFFLINE' ]
	then
		echo "system is OFFLINE: ${SCRIPTDIR}/OFFLINE exists"
		break
	else
		if [ "$FILES" != "${INCOMING}/*" ]
		then
			echo "found stuff in ${INCOMING}"
			for i in $FILES
			do
				if [ -e 'OFFLINE' ]
				then
					echo "system is OFFLINE: ${SCRIPTDIR}/OFFLINE exists"
					break
				else
					echo "processing ${i}"

					# yes, this says cvs, but it can also do svn
					/bin/sh ./freebsd-cvs.sh ${i}

					RESULT=$?
					echo "result=$RESULT"
					basename=`basename ${i}`
					if [ $RESULT -eq 0 ]
					then
						echo "'`ls -l ${i}`'"
						echo "'`ls -ld /var/db/ingress/message-queues/incoming`'"

						# use -p to preserve mtime
						${CP} -p ${i} ~ingress/message-queues/recent/${basename}.raw

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
						echo "${i} fails...."

						# move the original email to the retry directory
						${MV} ${i} ~ingress/message-queues/retry/

						# and any other files as well
						${MV}  ~ingress/message-queues/recent/${basename}.* ~ingress/message-queues/retry/
					fi

				fi
			done
		fi
	fi
	sleep 3
done
