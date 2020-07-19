#!/bin/sh
#
# $Id: config.sh.sample,v 1.2 2004-08-13 01:58:35 dan Exp $
#
# Copyright (c) 2001-2003 DVL Software
#

PERL="/usr/local/bin/perl"

SCRIPTDIR="/usr/local/libexec/freshports"

# this is also repeated in the freshports config file 
# for ingress user
INGRESS_BASEDIR="/var/db/ingress"
INGRESS_MSGDIR="${INGRESS_BASEDIR}/message-queues"

INGRESS_FLAGDIR="${INGRESS_BASEDIR}/signals"
