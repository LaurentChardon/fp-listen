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

import configparser # for fp-listen.ini parsing

from pathlib import Path # for removing files from cache dir

config = configparser.ConfigParser()
config.read('/usr/local/etc/freshports/fp-listen.ini')

DSN = 'host=' + config['database']['HOST'] + ' dbname=' + config['database']['DBNAME'] + ' user=' + config['database']['DBUSER'] + ' password=' + config['database']['PASSWORD'] + "sslmode='require'"

def RemovePortsCacheEntry():
  something_cleared = False
  syslog.syslog(syslog.LOG_NOTICE, 'checking for file entries to remove...')
  dbh = psycopg2.connect(DSN)
  curs = dbh.cursor(cursor_factory=psycopg2.extras.DictCursor)

  # we loop until nothing is found to delete. See comment at end of loop.
  while 1:
    syslog.syslog(syslog.LOG_NOTICE, 'at the top of the loop looking for cache port entries to remove...')
    curs.execute("SELECT id, port_id, category, port FROM cache_clearing_ports ORDER BY id")
    NumRows = curs.rowcount
    dbh.commit();
    if (NumRows > 0):
      something_cleared = True
      syslog.syslog(syslog.LOG_NOTICE, 'COUNT: %d entries to process' % (NumRows))
      rows = curs.fetchall()
      for row in rows:
        #
        # first, we clear the port cache
        #
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
          syslog.syslog(syslog.LOG_CRIT, 'ERROR: error deleting cache port entry.  Error message is %s' % (sys.exc_info()[0]))
          # if we can't delete it, do not remove it from cache
          continue

        #
        # then we delete the category cache
        #
        filenameglob = config['dirs']['CATEGORY_CACHE_PATH'] % (row['category'])
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
          syslog.syslog(syslog.LOG_CRIT, 'ERROR: error deleting port entry.  Error message is %s' % (sys.exc_info()[0]))
          # if we can't delete it, do not remove it from cache
          continue

        syslog.syslog(syslog.LOG_NOTICE, "DELETE FROM cache_clearing_ports WHERE id = %d" % (row['id']))
        curs.execute("DELETE FROM cache_clearing_ports WHERE id = %d" % (row['id']))
        dbh.commit()
      # end for
      syslog.syslog(syslog.LOG_NOTICE, 'at the bottom of the loop looking for port entries to remove...')
    else:
      if something_cleared:
        syslog.syslog(syslog.LOG_NOTICE, 'No cached port entries found for removal')
      else:
        syslog.syslog(syslog.LOG_ERR, 'ERROR: No cached entries found for removal')
      #
      # we stay in this loop until there are no entries to remove
      # this avoids the race condition where more entries are added
      # while we are running. The NOTIFY issued then is missed/squashed/DUNNO.
      #
      break;
    # end if
    
  syslog.syslog(syslog.LOG_NOTICE, 'finished')
  return NumRows

def RemoveFilesCacheEntry():
  # this removes cached entries for MOVED, UPDATING, a Makefille, etc.
  # it was copied from RemovePortsCacheEntry and is not finished yet.
  # dvl- 2023-10-15
  #
  something_cleared = False
  syslog.syslog(syslog.LOG_NOTICE, 'checking for cache file entries to remove...')
  dbh = psycopg2.connect(DSN)
  curs = dbh.cursor(cursor_factory=psycopg2.extras.DictCursor)

  # we loop until nothing is found to delete. See comment at end of loop.
  while 1:
    syslog.syslog(syslog.LOG_NOTICE, 'at the top of the loop looking for cache file entries to remove...')
    curs.execute("SELECT id, pathname FROM cache_clearing_files ORDER BY id")
    NumRows = curs.rowcount
    dbh.commit();
    if (NumRows > 0):
      something_cleared = True
      syslog.syslog(syslog.LOG_NOTICE, 'COUNT: %d entries to process' % (NumRows))
      rows = curs.fetchall()
      for row in rows:
        #
        # we clear the file cache, which be in src, doc, or ports?
        # I think we show history only for /ports, so we can concentrate on that.
        # We also don't distinguish between head and quarterly for non-ports.
        # We can assume anything here is on head and not part of a category or port.
        # That leaves us with Mk, MOVED, UPDATING, etc.
        # so, strip off /ports/head and remove this from the ~freshports/cache/ports/ directory
        #

        # change /ports/head/MOVED
        pathname = row['pathname'].replace('/ports/head/', '/')

        syslog.syslog(syslog.LOG_NOTICE, 'we would be removing: %s' % pathname)
        filenameglob = config['dirs']['FILE_CACHE_PATH'] % (pathname)
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


        syslog.syslog(syslog.LOG_NOTICE, "DELETE FROM cache_clearing_files WHERE id = %d" % (row['id']))
        curs.execute("DELETE FROM cache_clearing_files WHERE id = %d" % (row['id']))
        dbh.commit()
      # end for
      syslog.syslog(syslog.LOG_NOTICE, 'at the bottom of the loop looking for cache entries to remove...')
    else:
      if something_cleared:
        syslog.syslog(syslog.LOG_NOTICE, 'No cached entries found for removal')
      else:
        syslog.syslog(syslog.LOG_ERR, 'ERROR: No cached entries found for removal')
      #
      # we stay in this loop until there are no entries to remove
      # this avoids the race condition where more entries are added
      # while we are running. The NOTIFY issued then is missed/squashed/DUNNO.
      #
      break;
    # end if
    
  syslog.syslog(syslog.LOG_NOTICE, 'finished')
  return NumRows

def PackagesCacheClear():
  # here, we clear out /var/db/freshports/cache/packages
  PKG_ZFS_SNAPSHOT = config['dirs']['PKG_ZFS_SNAPSHOT']
  syslog.syslog(syslog.LOG_NOTICE, "Time to rollback %s" % PKG_ZFS_SNAPSHOT);
  try:
    # this is the name of the zfs filesystem to rollback, including the snapshot name
    if os.system('zfs rollback ' + PKG_ZFS_SNAPSHOT):
      syslog.syslog(syslog.LOG_CRIT, 'ERROR: while in PackagesCacheClear(). zfs rollback failed.')
    else:
      syslog.syslog(syslog.LOG_NOTICE, 'zfs rollback succeeded.')

  except:
    syslog.syslog(syslog.LOG_CRIT, 'ERROR: while in PackagesCacheClear().  Error message is %s' % (sys.exc_info()[0]))

  syslog.syslog(syslog.LOG_NOTICE, "Done with PackagesCacheClear()");

def CommitsCacheClear():
  glob_templates = [ 'COMMIT_CACHE_PATH', 'SANITY_CACHE_PATH', 'SANITY_MAIN_CACHE_PATH' ]
  dbh = psycopg2.connect(DSN)
  curs = dbh.cursor(cursor_factory=psycopg2.extras.DictCursor)

  curs.execute("SELECT commit_to_clear FROM cache_clearing_commits")
  NumRows = curs.rowcount
  dbh.commit();
  if (NumRows > 0):
    syslog.syslog(syslog.LOG_NOTICE, 'COUNT: %d entries to process' % (NumRows))
    rows = curs.fetchall()
    for row in rows:
      for template in glob_templates:
        if (template == 'SANITY_MAIN_CACHE_PATH'):
          filenameglob = config['dirs'][template]
        else:
          filenameglob = config['dirs'][template] % (row['commit_to_clear'])

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
      # endfor templates
    
      syslog.syslog(syslog.LOG_NOTICE, "DELETE FROM cache_clearing_commits WHERE commit_to_clear = '%s'" % (row['commit_to_clear']))
      curs.execute("DELETE FROM cache_clearing_commits WHERE commit_to_clear = '%s'" % (row['commit_to_clear']))
      dbh.commit()

    # end for rows
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
  # the website once did something with this. What, I'm not sure. It fetched the list of categories from a webpage and then processed them...


def ProcessPortsMoved():
  syslog.syslog(syslog.LOG_NOTICE, 'processing ports/MOVED')


def ProcessPortsUpdating():
  syslog.syslog(syslog.LOG_NOTICE, 'processing ports/UPDATING')


def ProcessVUXML():
  syslog.syslog(syslog.LOG_NOTICE, 'processing ports/security/portaudit/vuln.xml')

  
def ClearMiscCaches():
  syslog.syslog(syslog.LOG_NOTICE, 'invoked: ClearMiscCaches()');
  
  news_cache_dir = config['dirs']['NEWS_CACHE_DIR'];
  syslog.syslog(syslog.LOG_NOTICE, 'ClearMiscCaches() is clearing out entries in %s' % (news_cache_dir));

  for filename in Path(news_cache_dir).iterdir():
    syslog.syslog(syslog.LOG_NOTICE, 'ClearMiscCaches() is removing %s' % (filename))
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

  syslog.syslog(syslog.LOG_NOTICE, 'finished: ClearMiscCaches()');
         


syslog.openlog(ident='fp-listen', facility=syslog.LOG_LOCAL3)

syslog.syslog(syslog.LOG_NOTICE, 'Starting up - this should not occur often')

conn = psycopg2.connect(DSN)
conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

curs = conn.cursor()

curs.execute("SELECT name, script_name FROM listen_for ORDER BY id")
listens_for = curs.fetchall()

listens = dict()
syslog.syslog(syslog.LOG_NOTICE, "These are the (event name, script name) pairs we are ready for:")
for listen in listens_for:
  curs.execute("LISTEN %s" % listen[0])
  listens[listen[0]] = listen[1]
  syslog.syslog(syslog.LOG_NOTICE, "('%s', '%s')" % (listen[0], listen[1]))

while 1:
  if select.select([conn],[],[],5)==([],[],[]):
    syslog.syslog(syslog.LOG_NOTICE, 'timeout! *************')
  else:
    conn.poll()
    syslog.syslog(syslog.LOG_NOTICE, 'Just woke up! *************')
    while conn.notifies:
      notify = conn.notifies.pop(0);
      # in real life, do something with each...
      syslog.syslog(syslog.LOG_NOTICE, "Got NOTIFY: pid='%d', channel='%s', payload='%s'" % (notify.pid, notify.channel, notify.payload));
      if notify.channel in listens:
      
        syslog.syslog(syslog.LOG_NOTICE, "found key %s" % (notify.channel));

        clear_cache = True;

        if  listens[notify.channel] == 'listen_port':
          syslog.syslog(syslog.LOG_NOTICE, "invoking RemovePortsCacheEntry()");
          RemovePortsCacheEntry()
        elif listens[notify.channel] == 'listen_file_updated':
          syslog.syslog(syslog.LOG_NOTICE, "invoking RemoveFilesCacheEntry()");
          RemoveFilesCacheEntry()
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
        elif listens[notify.channel] == 'listen_packages_imported':
          syslog.syslog(syslog.LOG_NOTICE, "invoking PackagesCacheClear()");
          PackagesCacheClear()
          # at the time of writing, there was no reason to ClearMiscCaches() when
          # new packages arrive
          clear_cache = False;
        elif listens[notify.channel] == 'listen_commit':
          syslog.syslog(syslog.LOG_NOTICE, "invoking CommitsClearCache()");
          CommitsCacheClear()
        else:
          clear_cache = False;
          syslog.syslog(syslog.LOG_ERR, "Code does not know what to do when '%s' is found." % notify.channel)
          syslog.syslog(syslog.LOG_ERR, "listens[notify.channel='%s']" % listens[notify.channel])
          
        if clear_cache:
          syslog.syslog(syslog.LOG_NOTICE, "invoking ClearMiscCaches()");
          ClearMiscCaches()

      else:
        syslog.syslog(syslog.LOG_NOTICE, 'no such key in listens array for %s!' % (notify.channel))

logging.error('terminating')
