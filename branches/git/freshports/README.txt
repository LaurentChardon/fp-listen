Copyright Dan Langille dan@langille.org

This script processes incoming XML files and loads them into the database.
It also looks for signals and invokes job-waiting.pl - this allows
various tasks to be serialized instead of parallel.  Some things should
occur serially. You don't want two updates needing the working copy of the
repo in two different states.  Someone will go home crying.

The configuration file is expected at /usr/local/etc/freshports/fp-freshports.sh

Yes, the configuration file and the script have the same name.
