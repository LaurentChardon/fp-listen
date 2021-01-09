#
# $Id: README.txt,v 1.2 2006-09-13 22:33:40 dan Exp $
#
# Copyright (c) 2001-2006 DVL Software
#

Things to change before running:

run      - name of user under which script will run
env/HOME - home directory of user

This directory should be accessible by the above mentioned user.

e.g. chown dan:dan .

To clear stale cache entries, this query example may be useful:

SELECT 'rm /usr/websites/beta.freshports.org/dynamic/caching/cache/ports/' || category || '/' || name || '.Detail.html'
  FROM ports_all PA, commit_log CL, commit_log_ports CLP
 WHERE CL.date_added between '2006-09-11' and '2006-09-14'
   AND CL.id = CLP.commit_log_id
   AND CLP.port_id = PA.id;
