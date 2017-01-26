#!/usr/bin/env python
#
# $Id: fp-listen.py,v 1.8 2007-10-12 16:32:34 dan Exp $
#
# This program listens for events on the database and processes them
#

import sys
import psycopg2
import select

import os	# for deleting cache files
import syslog	# for logging
import glob	# for glob
import shutil	# for rmtree

import urllib	# for fetching files

import config 	# my configuration items
from config import *

DSN = 'host=' + config.HOST + ' dbname=' + config.DBNAME + ' user=' + DBUSER + ' password=' + config.PASSWORD

def RemoveCacheEntry():
  syslog.syslog(syslog.LOG_NOTICE, 'checking for cache entries to remove...')
  dbh = psycopg2.connect(DSN)
  curs = dbh.cursor()

  curs.execute("SELECT id, port_id, category, port FROM cache_clearing_ports ORDER BY id")
  NumRows = curs.rowcount
  dbh.commit();
  if (NumRows > 0):
    syslog.syslog(syslog.LOG_NOTICE, 'COUNT: %d entries to process' % (NumRows))
    for row in curs.dictfetchall():
      filenameglob = config.PORT_CACHE_PATH % (row['category'], row['port'])
      syslog.syslog(syslog.LOG_NOTICE, 'removing glob %s' % (filenameglob))

      try:
        for filename in glob.glob(filenameglob):
          syslog.syslog(syslog.LOG_NOTICE, 'removing %s' % (filename))
          if os.path.isfile(filename):
            os.remove(filename)
          else:
            shutil.rmtree(filename)

      except OSError, err:
        if err[0] == 2:
          pass  # no file to delete, so no worries
          
        else:
          syslog.syslog(syslog.LOG_CRIT, 'ERROR: error deleting cache entry.  Error message is %s' % (err))
          continue
        # end if
        
      syslog.syslog(syslog.LOG_NOTICE, "DELETE FROM cache_clearing_ports WHERE id = %d" % (row['id']))
      curs.execute("DELETE FROM cache_clearing_ports WHERE id = %d" % (row['id']))
      dbh.commit()

    # end for
  else:
    syslog.syslog(syslog.LOG_ERR, 'ERROR: No cached entries found for removal')
  # end if
    
  syslog.syslog(syslog.LOG_NOTICE, 'finished')
  return NumRows

def ClearDateCacheEntries():
  syslog.syslog(syslog.LOG_NOTICE, 'checking for cache date to remove...')
  dbh = psycopg2.connect(DSN)
  curs = dbh.cursor()

  curs.execute("SELECT id, date_to_clear FROM cache_clearing_dates ORDER BY id")
  NumRows = curs.rowcount
  dbh.commit();
  if (NumRows > 0):
    syslog.syslog(syslog.LOG_NOTICE, 'COUNT: %d entries to process' % (NumRows))
    for row in curs.dictfetchall():
      syslog.syslog(syslog.LOG_NOTICE, 'looking at %s' % (row['date_to_clear']))
      filenameglob = config.DATE_CACHE_PATH % (row['date_to_clear'].strftime('%Y'), row['date_to_clear'].strftime('%m'), row['date_to_clear'].strftime('%d'))
      syslog.syslog(syslog.LOG_NOTICE, 'removing glob %s' % (filenameglob))

      try:
        for filename in glob.glob(filenameglob):
          syslog.syslog(syslog.LOG_NOTICE, 'removing %s' % (filename))
          if os.path.isfile(filename):
            os.remove(filename)
          else:
            shutil.rmtree(filename)

      except OSError, err:
        if err[0] == 2:
          pass  # no file to delete, so no worries
          
        else:
          syslog.syslog(syslog.LOG_CRIT, 'ERROR: error deleting cache entry.  Error message is %s' % (err))
          continue
        # end if
        
      syslog.syslog(syslog.LOG_NOTICE, "DELETE FROM cache_clearing_dates WHERE id = %d" % (row['id']))
      curs.execute("DELETE FROM cache_clearing_dates WHERE id = %d" % (row['id']))
      dbh.commit()

    # end for
  else:
    syslog.syslog(syslog.LOG_ERR, 'ERROR: No cached entries found for removal')
  # end if
    
  syslog.syslog(syslog.LOG_NOTICE, 'finished')
  return NumRows

def Touch(File):
  if not os.path.exists(File):
    fd = open(File, 'aos.O_WRONLY | os.O_NONBLOCK | os.O_CREAT | os.O_NOCTTY | os.O_APPEND')
    fd.close()
  os.utime(File, None)

def ProcessCategoryNew():
  syslog.syslog(syslog.LOG_NOTICE, 'We have a new category')
  
  urllib.urlretrieve("http://www.freebsd.org/cgi/cvsweb.cgi/~checkout~/www/en/ports/categories?rev=HEAD;content-type=text%2Fplain", '/usr/websites/freshports.org/dynamic/caching/tmp/categories');
  Touch(WWWENPortsCategoriesFlag)
  Touch(JOBWAITING)

def ProcessPortsMoved():
  syslog.syslog(syslog.LOG_NOTICE, 'processing ports/MOVED')

def ProcessPortsUpdating():
  syslog.syslog(syslog.LOG_NOTICE, 'processing ports/UPDATING')

def ProcessVUXML():
  syslog.syslog(syslog.LOG_NOTICE, 'processing ports/security/portaudit/vuln.xml')

syslog.openlog('fp-listen')

syslog.syslog(syslog.LOG_NOTICE, 'Starting up')

conn = psycopg2.connect(DSN)
conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

curs = conn.cursor()

curs.execute("SELECT name, script_name FROM listen_for ORDER BY id")
listens_for = curs.fetchall()

listens = dict()
print "These are the (event name, script name) pairs we are ready for:"
for listen in listens_for:
  curs.execute("LISTEN %s" % listen[0])
  listens[listen[0]] = listen[1]
  print "('%s', '%s')" % (listen[0], listen[1])

while 1:
  if select.select([conn],[],[],5)==([],[],[]):
    syslog.syslog(syslog.LOG_NOTICE, 'timeout! *************')
  else:
    conn.poll()
    #curs.execute("SELECT 1")
    syslog.syslog(syslog.LOG_NOTICE, 'Just woke up! *************')
    while conn.notifies:
      notify = conn.notifies.pop(0);
      # in real life, do something with each...
      syslog.syslog(syslog.LOG_NOTICE, "Got NOTIFY: %d, %s, %s" % (notify.pid, notify.channel, notify.payload));
#      syslog.syslog(syslog.LOG_NOTICE, "got %s and I need to call %s" % (notify[0], listens[notify[0]]))
      if listens.has_key(notify.channel):
        syslog.syslog(syslog.LOG_NOTICE, "found key %s" % (notify.channel));
        if listens[notify.channel]   == 'listen_port':
          RemoveCacheEntry()
        elif listens[notify.channel] == 'listen_ports_moved':
          ProcessPortsMoved()
        elif listens[notify.channel] == 'listen_ports_updating':
          ProcessPortsUpdating()
        elif listens[notify.channel] == 'listen_vuxml':
          ProcessVUXML()
        elif listens[notify.channel] == 'listen_category_new':
          ProcessCategoryNew()
        elif listens[notify.channel] == 'listen_date_updated':
          ClearDateCacheEntries()
        else:
          syslog.syslog(syslog.LOG_ERR, "Code does not know what to do when '%s' is found." % notify.channel)
      else:
        syslog.syslog(syslog.LOG_NOTICE, 'no such key in listens array for %s!' % (notify.channel))

logging.error('terminating')
