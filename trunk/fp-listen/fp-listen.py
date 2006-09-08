#!/usr/bin/env python
#
# This program listens for events on the database and processes them
#

#
# configuration items
#
DSN = 'dbname=freshports.org user=dan'
CACHEPATH = '/usr/websites/beta.freshports.org/dynamic/caching/cache/ports/%s/%s.Details.html'

import sys, psycopg, select

import os		# for deleting cache files
import syslog	# for logging

def RemoveCacheEntry():
  syslog.syslog(syslog.LOG_NOTICE, 'removing cache entries')
  dbh = psycopg.connect(DSN)
  dbh.autocommit(0)
  curs = dbh.cursor()

  first_row = 1;  
  curs.execute("SELECT id, port_id, category, port FROM cache_clearing_ports ORDER BY id")
  NumRows = curs.rowcount
  if (NumRows > 0):
    for row in curs.dictfetchall():
      if (first_row):
        min_id = row['id']
        max_id = row['id']
        first_row = 0
      # end if

      min_id = min(row['id'], min_id)
      max_id = max(row['id'], max_id)
      # other processing goes here

      syslog.syslog(syslog.LOG_NOTICE, 'removing %s/%s' % (row['category'], row['port']))

# OSError: [Errno 2] No such file or directory: '/usr/websites/beta.freshports.org/dynamic/caching/cache/ports/devel/py-sip.Details.html'
#
      filename = CACHEPATH % (row['category'], row['port'])
      try:
        os.remove(filename)
      except OSError, err:
        if err[0] == 2:
          continue  # no file to delete, so no worries
          
        else:
          syslog.syslog(syslog.LOG_CRIT, 'ERROR: error deleting cache entry.  Error message is %s' % (err))
          continue
        # end if
        
    syslog.syslog(syslog.LOG_NOTICE, 'removing %s entries between %s and %s' % (NumRows, min_id, max_id))
    curs.execute("DELETE FROM cache_clearing_ports WHERE id BETWEEN %d AND %d", (min_id, max_id))
#    dbh.commit()
        

    # end for
  else:
    syslog.syslog(syslog.LOG_ERR, 'No cached entries found for removal')
  # end if
    
  syslog.syslog(syslog.LOG_NOTICE, 'finished')
  return NumRows

def ProcessPortsMoved():
  syslog.syslog(syslog.LOG_NOTICE, 'processing ports/MOVED')

def ProcessPortsUpdating():
  syslog.syslog(syslog.LOG_NOTICE, 'processing ports/UPDATING')

def ProcessVUXML():
  syslog.syslog(syslog.LOG_NOTICE, 'processing ports/security/portaudit/vuln.xml')

syslog.openlog('fp-listen')

syslog.syslog(syslog.LOG_NOTICE, 'Starting up')

print "Opening connection using dns:", DSN
conn = psycopg.connect(DSN)
conn.autocommit(1)

curs = conn.cursor()

curs.execute("SELECT name, script_name FROM listen_for ORDER BY id")
listens_for = curs.fetchall()

listens = dict()
for listen in listens_for:
  curs.execute("LISTEN %s" % listen[0])
  listens[listen[0]] = listen[1]
  print listen

print "Now listening..."
while 1:
  select.select([curs],[],[])==([],[],[])
  curs.execute("SELECT 1")
  syslog.syslog(syslog.LOG_NOTICE, 'Just work up')
  notifies = curs.notifies()
  for n in notifies:
    print "got %s" % n[0]
    print "this is index %s" % listens[n[0]]
    # in real life, do something with each...
    print "got %s and I need to call %s" % (n[0], listens[n[0]])
    syslog.syslog(syslog.LOG_NOTICE, "got %s and I need to call %s" % (n[0], listens[n[0]]))
    if listens.has_key(n[0]):
      if listens[n[0]]   == 'listen_port':
        RemoveCacheEntry()
      elif listens[n[0]] == 'listen_ports_moved':
        ProcessPortsMoved()
      elif listens[n[0]] == 'listen_ports_updating':
        ProcessPortsUpdating()
      elif listens[n[0]] == 'listen_vuxml':
        ProcessVUXML()
      else:
        syslog.syslog(syslog.LOG_ERR, "Code does not know what to do when '%s' is found." % n[0])
    else:
      syslog.syslog(syslog.LOG_NOTICE, 'no such key!')

logging.error('terminating')
