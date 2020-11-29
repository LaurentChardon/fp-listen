Copyright Dan Langille - dan@langille.org

The configuration file is /usr/local/etc/freshports/fp-daemon.sh

Yes, the script and its configuration file have the same name.

This script listens for signals, invokes job-waiting.pl, which then takes the
appropriate action. We can't have both ingress and fp-daemon.sh invoking
job-waiting.  Perhaps only one will invoke it and it will process signals for
both git and svn jobs.

This code originated at freshports-1/daemontools/trunk/fp-daemon where it was
managed by daemontools.

This git branch code will use damon(8)
