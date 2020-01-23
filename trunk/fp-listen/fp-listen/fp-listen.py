#!/usr/bin/env python
#
# $Id: fp-listen.py,v 1.8 2007-10-12 16:32:34 dan Exp $
#
# This program listens for events on the database and processes them
#

import sys
import psycopg2
import psycopg2.extensions
import psycopg2.extras
import select

import os	# for deleting cache files
import syslog	# for logging
import glob	# for glob
import shutil	# for rmtree

import urllib	# for fetching files

import configparser # for fp-listen.ini parsing

from pathlib import Path # for removing files from cache dir


config = configparser.ConfigParser()
config.read('/usr/local/etc/freshports/fp-listen.ini')

DSN = 'host=' + config['database']['HOST'] + ' dbname=' + config['database']['DBNAME'] + ' user=' + config['database']['DBUSER'] + ' password=' + config['database']['PASSWORD']

def RemoveCacheEntry():
  syslog.syslog(syslog.LOG_NOTICE, 'checking for cache entries to remove...')
  dbh = psycopg2.connect(DSN)
  curs = dbh.cursor(cursor_factory=psycopg2.extras.DictCursor)

  curs.execute("SELECT id, port_id, category, port FROM cache_clearing_ports ORDER BY id")
  NumRows = curs.rowcount
  dbh.commit();
  if (NumRows > 0):
    syslog.syslog(syslog.LOG_NOTICE, 'COUNT: %d entries to process' % (NumRows))
    rows = curs.fetchall()
    for row in rows:
      filenameglob = config['dirs']['PORT_CACHE_PATH'] % (row['category'], row['port'])
      syslog.syslog(syslog.LOG_NOTICE, 'removing glob %s' % (filenameglob))

      try:
        for filename in glob.glob(filenameglob):
          syslog.syslog(syslog.LOG_NOTICE, 'removing %s' % (filename))
          if os.path.isfile(filename):
            os.remove(filename)
          else:
            shutil.rmtree(filename)

      except FileNotFoundError:
        syslog.syslog(syslog.LOG_CRIT, 'could not find file for deletion %s' % (filename))

      except:
        syslog.syslog(syslog.LOG_CRIT, 'ERROR: error deleting cache entry.  Error message is %s' % (sys.exc_info()[0]))
        # if we can't delete it, do not remove it from cache
        continue

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
  curs = dbh.cursor(cursor_factory=psycopg2.extras.DictCursor)

  curs.execute("SELECT id, date_to_clear FROM cache_clearing_dates ORDER BY id")
  NumRows = curs.rowcount
  dbh.commit();
  if (NumRows > 0):
    syslog.syslog(syslog.LOG_NOTICE, 'COUNT: %d entries to process' % (NumRows))
    rows = curs.fetchall()
    for row in rows:
      syslog.syslog(syslog.LOG_NOTICE, 'looking at %s' % (row['date_to_clear']))
      filenameglob = config['dirs']['DATE_CACHE_PATH'] % (row['date_to_clear'].strftime('%Y'), row['date_to_clear'].strftime('%m'), row['date_to_clear'].strftime('%d'))
      syslog.syslog(syslog.LOG_NOTICE, 'removing glob %s' % (filenameglob))

      try:
        for filename in glob.glob(filenameglob):
          syslog.syslog(syslog.LOG_NOTICE, 'removing %s' % (filename))
          if os.path.isfile(filename):
            os.remove(filename)
          else:
            shutil.rmtree(filename)

      except FileNotFoundError:
        syslog.syslog(syslog.LOG_CRIT, 'could not find file for deletion %s' % (filename))
        pass  # no file to delete, so no worries

      except:
        syslog.syslog(syslog.LOG_CRIT, 'ERROR: error deleting cache entry.  Error message is %s' % (sys.exc_info()[0]))
        continue

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
  Touch(config['flags']['WWWENPortsCategoriesFlag'])
  Touch(config['flags']['JOBWAITING'])

def ProcessPortsMoved():
  syslog.syslog(syslog.LOG_NOTICE, 'processing ports/MOVED')

def ProcessPortsUpdating():
  syslog.syslog(syslog.LOG_NOTICE, 'processing ports/UPDATING')

def ProcessVUXML():
  syslog.syslog(syslog.LOG_NOTICE, 'processing ports/security/portaudit/vuln.xml')
  
def ClearMiscCaches():
  syslog.syslog(syslog.LOG_NOTICE, 'invoked: ClearMiscCaches()');
  
  filenameglob = config['dirs']['NEWS_CACHE_PATH'];
  syslog.syslog(syslog.LOG_NOTICE, 'ClearMiscCaches() is clearing %s' % (filenameglob));

  filenameglob = config['dirs']['NEWS_CACHE_PATH'];
  syslog.syslog(syslog.LOG_NOTICE, 'ClearMiscCaches() is clearing %s' % (filenameglob));

  for filename in Path(filenameglob).iterdir():
    syslog.syslog(syslog.LOG_NOTICE, 'removing %s' % (filename))
    try:
      if Path(filename).is_file():
        Path(filename).unlink()
      else:
        shutil.rmtree(filename)
    
    except FileNotFoundError:
      syslog.syslog(syslog.LOG_CRIT, 'could not find file for deletion %s' % (filename))
      pass  # no file to delete, so no worries

    except:
      syslog.syslog(syslog.LOG_CRIT, 'ERROR: error deleting cache entry.  Error message is %s' % (sys.exc_info()[0]))
      continue

           

  filenameglob = config['dirs']['NEWS_CACHE_DIR'];
  syslog.syslog(syslog.LOG_NOTICE, 'ClearMiscCaches() is clearing %s' % (filenameglob));

  for filename in glob.glob(filenameglob):
    syslog.syslog(syslog.LOG_NOTICE, 'removing %s' % (filename))
    try:
      if os.path.isfile(filename):
        os.remove(filename)
      else:
        shutil.rmtree(filename)

    except FileNotFoundError:
        syslog.syslog(syslog.LOG_CRIT, 'could not find file for deletion %s' % (filename))
        pass  # no file to delete, so no worries

    except:
        syslog.syslog(syslog.LOG_CRIT, 'ERROR: error deleting cache entry.  Error message is %s' % (sys.exc_info()[0]))
        continue

syslog.openlog(ident='fp-listen', facility=syslog.LOG_LOCAL3)

syslog.syslog(syslog.LOG_NOTICE, 'Starting up - this should not occur often')

conn = psycopg2.connect(DSN)
conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

curs = conn.cursor()

curs.execute("SELECT name, script_name FROM listen_for ORDER BY id")
listens_for = curs.fetchall()

listens = dict()
print ("These are the (event name, script name) pairs we are ready for:")
for listen in listens_for:
  curs.execute("LISTEN %s" % listen[0])
  listens[listen[0]] = listen[1]
  print ("('%s', '%s')" % (listen[0], listen[1]))

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
      if notify.channel in listens:
        syslog.syslog(syslog.LOG_NOTICE, "found key %s" % (notify.channel));
        clear_cache = True;
        if listens[notify.channel]   == 'listen_port':
          syslog.syslog(syslog.LOG_NOTICE, "invoking RemoveCacheEntry()");
          RemoveCacheEntry()
        elif listens[notify.channel] == 'listen_ports_moved':
          syslog.syslog(syslog.LOG_NOTICE, "invoking ProcessPortsMoved()");
          ProcessPortsMoved()
        elif listens[notify.channel] == 'listen_ports_updating':
          syslog.syslog(syslog.LOG_NOTICE, "invoking ProcessPortsUpdating()");
          ProcessPortsUpdating()
        elif listens[notify.channel] == 'listen_vuxml':
          syslog.syslog(syslog.LOG_NOTICE, "invoking ProcessVUXML()");
          ProcessVUXML()
        elif listens[notify.channel] == 'listen_category_new':
          syslog.syslog(syslog.LOG_NOTICE, "invoking ProcessCategoryNew()");
          ProcessCategoryNew()
        elif listens[notify.channel] == 'listen_date_updated':
          syslog.syslog(syslog.LOG_NOTICE, "invoking ClearDateCacheEntries()");
          ClearDateCacheEntries()
        else:
          clear_cache = False;
          syslog.syslog(syslog.LOG_ERR, "Code does not know what to do when '%s' is found." % notify.channel)
          
        if clear_cache:
          syslog.syslog(syslog.LOG_NOTICE, "invoking ClearMiscCaches()");
          ClearMiscCaches()

      else:
        syslog.syslog(syslog.LOG_NOTICE, 'no such key in listens array for %s!' % (notify.channel))

logging.error('terminating')
