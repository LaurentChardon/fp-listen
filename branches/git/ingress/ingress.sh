#!/bin/sh
#
# $Id: fp-daemon.sh,v 1.17 2006-11-10 14:08:26 dan Exp $
#
# Copyright (c) 2001-2003 DVL Software
#
#
# include our local parameters

. /usr/local/etc/freshports/ingress.sh

CP='/bin/cp'

# we do not use -i because that would fail when re re-run a commit
MV='/bin/mv'

RM='/bin/rm'

PERL='/usr/local/bin/perl'

#
# sanity checking upon startup
#

check_for_jobs() {
	#
	# This flag file is only set by a job run by this script.
	# A race condition should never arise.
	#
	FLAG="${INGRESS_FLAGDIR}/job_waiting"
	if [ -f ${FLAG} ]
	then
		cd ${SCRIPTDIR}
		echo "yes, there is a job waiting"
		echo "running ${PERL} ./job-waiting.pl"
		echo "from directory  ${SCRIPTDIR}"
		ls -l ./job-waiting.pl
		${PERL} ./job-waiting.pl
		if [ $? -eq 0 ]
		then
			echo "job-waiting.pl finishes normally"
		else
			echo "FATAL job-waiting.pl finished with an error: $?"
		fi
		rm ${FLAG}
	fi
}

echo "starting up!"

if [ ! -d ${SCRIPTDIR} ]
then
	echo "Required directory does not exist: ${SCRIPTDIR}"
	exit
fi

if [ ! -d ${INGRESS_MSGDIR}/incoming ]
then
	echo "Required directory does not exist: ${INGRESS_MSGDIR}/incoming"
	exit
fi

echo incoming: ${INGRESS_MSGDIR}/incoming
echo ready

while :
	do
	cd ${SCRIPTDIR}

	INCOMING=${INGRESS_MSGDIR}/incoming

	if [ -e 'OFFLINE' ]
	then
		echo "system is OFFLINE: ${SCRIPTDIR}/OFFLINE exists"
		break
	else
		check_for_jobs
	fi
	sleep 3
done
