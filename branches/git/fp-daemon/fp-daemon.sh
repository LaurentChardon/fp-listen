#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.17 2006-11-10 14:08:26 dan Exp $
#
# Copyright (c) 2001-2003 DVL Software

# This is based on the original fp-daemon which converted incoming emails to
# XML and loads them into the database.
#
# This script now converts incoming emails to XML and places them into a queue
# to be processed.
#
# * incoming email is dropped into ~freshports/message-queues/incoming by maildrop
#
# * XML is moved into ~ingress/message-queues/incoming
#
# * errors are moved to ~freshports/messages-queues/retry
# 
#
#
# include our local parameters

. /usr/local/etc/freshports/freshports.sh

CP='/bin/cp'

# we do not use -i because that would fail when re re-run a commit
MV='/bin/mv'

RM='/bin/rm'

#
# sanity checking upon startup
#

echo "starting up!"

# verify we can find our scripts
if [ ! -d ${SCRIPTDIR} ]
then
	echo "Required directory does not exist: ${SCRIPTDIR}"
	exit
fi

# verify we can find the XML destination
if [ ! -d ${INGRESS_BASEDIR}/message-queues/incoming ]
then
	echo "Required directory does not exist: ${INGRESS_BASEDIR}/message-queues/incoming"
	exit
fi

# do we have our own directory queues?
for dir in "incoming retry spooling"
do
	if [ ! -d ${FRESHPORTS_BASEDIR}/message-queues/${dir} ]
	then
		echo "Required directory does not exist: ${FRESHPORTS_BASEDIR}/message-queues/${dir}"
		exit
	fi
done

while :
	do
	cd ${SCRIPTDIR}

	INCOMING=${FRESHPORTS_BASEDIR}/message-queues/incoming
	SPOOLING=${FRESHPORTS_BASEDIR}/message-queues/spooling"

	#
	# this will be a list of files with full paths, or "/var/db/freshports/message-queues/incoming/*"
	# e.g. /var/db/freshports/message-queues/incoming/2020.12.05.20.15.17.14743.txt
	#
	FILES=`echo ${INCOMING}/*`

	if [ -e 'OFFLINE' ]
	then
		echo "system is OFFLINE: ${SCRIPTDIR}/OFFLINE exists"
		break
	else
		# if we found something
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

					FILE=`basename ${i}` 
					#
					# convert the raw file to XML
					#
					echo "$0 converting to XML via process_mail.pl"
					echo /usr/local/bin/perl ${SCRIPTDIR}/process_mail.pl from ${i} into ${XML}/${FILE}.xml errors to ${XML}/${FILE}.errors
					/usr/local/bin/perl ${SCRIPTDIR}/process_mail.pl < ${i} > ${XML}/${FILE}.xml 2>${XML}/${FILE}.errors

					RESULT=$?

					if [ -f ${XML}/${FILE}.errors ]
					then
					#  found errors
					   if [ ! -s $XML/${FILE}.errors ]
					   then
					      rm $XML/${FILE}.errors
					   fi
					fi

					echo "result=$RESULT"
					basename=`basename ${i}`
					if [ $RESULT -eq 0 ]
					then
						# move the XML file into the ~ingress/message-queues/incoming
						echo "- '`ls -l ${i}`'"
						echo "- '`ls -ld ${FRESHPORTS_BASEDIR}/message-queues/recent/`'"

						# move the XML into the incoming queue
						${MV} -i ${XML}/${FILE}.xml ${INGRESS_BASEDIR}/message-queues/incoming/
					else
						echo "${i} fails...."

						# move the original email to the retry directory
						${MV} ${i} ${FRESHPORTS_BASEDIR}/message-queues/retry/

						# and any other files as well
						${MV} ${FRESHPORTS_BASEDIR}/message-queues/recent/${basename}.* ${FRESHPORTS_BASEDIR}/message-queues/retry/
					fi
				fi
			done
		fi
	fi
	sleep 3
done
