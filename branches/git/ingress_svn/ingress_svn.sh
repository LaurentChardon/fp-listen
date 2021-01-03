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

# the -f was added in to cope wtih a permission issue
# the file was chown root
# /var/db/ingress_svn/message-queues/incoming/2021.01.01.18.10.38.42274.txt
RM='/bin/rm -f'

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
REQUIRED_DIRS="incoming retry spooling"
for dir in $REQUIRED_DIRS
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
	FILES=$(echo ${INCOMING}/*)

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

					FILE=$(basename ${i})
					# get the filename without the .txt extension
					FILE_basename=$(basename $FILE .txt)
					#
					# convert the raw file to XML
					#
					echo "$0 converting to XML via process_mail.pl"
					echo /usr/local/bin/perl ${SCRIPTDIR}/process_mail.pl from ${i} into ${SPOOLING}/${FILE_basename}.xml errors to ${SPOOLING}/${FILE_basename}.errors
					     /usr/local/bin/perl ${SCRIPTDIR}/process_mail.pl <    ${i} >    ${SPOOLING}/${FILE_basename}.xml         2>${SPOOLING}/${FILE_basename}.errors

					RESULT=$?

					echo ${SPOOLING}/${FILE_basename}.errors for errors
					if [ -f ${SPOOLING}/${FILE_basename}.errors ]
					then
					#  found errors
					   if [ ! -s ${SPOOLING}/${FILE_basename}.errors ]
					   then
					      # remove zero-length files
					      echo "removing the zero length error file: ${SPOOLING}/${FILE_basename}.errors"
					      $RM ${SPOOLING}/${FILE_basename}.errors
					   fi
					fi

					echo "result=$RESULT"
					if [ $RESULT -eq 0 ]
					then
						# move the XML file into the ~ingress/message-queues/incoming
						echo "$(ls -ld ${i} ${INGRESS_BASEDIR}/message-queues/incoming ${FRESHPORTS_BASEDIR}/message-queues/recent/)"

						# move the XML into the incoming queue
						# we spool, THEN move to avoid race conditions on reading and processing partially composed XML
						${MV} -i ${SPOOLING}/${FILE_basename}.xml ${INGRESS_BASEDIR}/message-queues/incoming/
						RESULT=$?
						if [ $? -ne 0 ]
						then
							echo "FATAL ERROR: '$RESULT' - cannot move ${SPOOLING}/${FILE_basename}.xml to ${INGRESS_BASEDIR}/message-queues/incoming/"
							exit 12
						fi
						
						# move the incoming email to the ingress recent directory
						# we do a copy, not a move to avoid this error:
						# mv: /var/db/freshports/message-queues/recent/2020.07.11.07.46.58.18048.txt: set owner/group (was: 10002/10001): Operation not permitted
						#
						${CP} -p ${i} ${FRESHPORTS_BASEDIR}/message-queues/recent/
						# if we copied, remove
						if [ -f ${FRESHPORTS_BASEDIR}/message-queues/recent/${FILE_basename}.txt ]
						then
							${RM} ${i}
						else
							echo "FATAL ERROR: cannot copy ${i} to ${FRESHPORTS_BASEDIR}/message-queues/recent/${FILE_basename}.txt"
							exit 13
						fi
					else
						echo "${i} fails...."

						# move the original email to the retry directory
						${MV} ${i} ${INGRESS_SVN_BASEDIR}/message-queues/retry/

						# and any other files as well
						${MV} ${SPOOLING}/${FILE_basename}.* ${INGRESS_SVN_BASEDIR}/message-queues/retry/
					fi

				fi
#				echo doing an EXIT AFTER ONLY ONE FILE
#				exit
			done
		fi
	fi
	sleep 3
done
