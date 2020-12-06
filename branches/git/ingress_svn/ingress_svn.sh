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

. /usr/local/etc/freshports/ingress_svn.sh

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
	if [ ! -d ${INGRESS_SVN_BASEDIR}/message-queues/${dir} ]
	then
		echo "Required directory does not exist: ${INGRESS_SVN_BASEDIR}/message-queues/${dir}"
		exit
	fi
done

while :
	do
	
	# sure, we do this every loop.  No big deal.
	cd ${SCRIPTDIR}

	INCOMING=${INGRESS_SVN_BASEDIR}/message-queues/incoming
	SPOOLING=${INGRESS_SVN_BASEDIR}/message-queues/spooling

	#
	# this will be a list of files with full paths, or "/var/db/ingress_svn/message-queues/incoming/*"
	# e.g. /var/db/ingress_svn/message-queues/incoming/2020.12.05.20.15.17.14743.txt
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
					echo /usr/local/bin/perl ${SCRIPTDIR}/process_mail.pl from ${i} into ${SPOOLING}/${FILE}.xml errors to ${SPOOLING}/${FILE}.errors
					     /usr/local/bin/perl ${SCRIPTDIR}/process_mail.pl <    ${i} >    ${SPOOLING}/${FILE}.xml         2>${SPOOLING}/${FILE}.errors

					RESULT=$?

					if [ -f ${XML}/${FILE}.errors ]
					then
					#  found errors
					   if [ ! -s $XML/${FILE}.errors ]
					   then
					      # remove zero-length files
					      $RM $XML/${FILE}.errors
					   fi
					fi

					echo "result=$RESULT"
					if [ $RESULT -eq 0 ]
					then
						# move the XML file into the ~ingress/message-queues/incoming
						echo "- '`ls -l ${i}`'"
						echo "- '`ls -ld ${INGRESS_BASEDIR}/message-queues/incoming`'"

						# move the XML into the incoming queue
						# we spool, THEN move to avoid race conditions on reading and processing partially composed XML
						${MV} -i ${SPOOLING}/${FILE}.xml ${INGRESS_BASEDIR}/message-queues/incoming/
					else
						echo "${i} fails...."

						# move the original email to the retry directory
						${MV} ${i} ${INGRESS_SVN_BASEDIR}/message-queues/retry/

						# and any other files as well
						${MV} ${SPOOLING}/${FILE}.* ${INGRESS_SVN_BASEDIR}/message-queues/retry/
					fi

				fi
			done
		fi
	fi
	sleep 3
done
