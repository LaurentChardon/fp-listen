Copyright Dan Langille - dan@langille.org

The configuration file is /usr/local/etc/freshports/fp-ingress.sh

Yes, the script and its configuration file have the same name.

This script listens for signals, invokes job-waiting.pl, which then takes the
appropriate action.

From the original svn cp of this directory:

Copy this over for use as an ingress daemon:

* receives notice of new commits via signals
* creates XML
* moves XMl into ~ingress/message-queues/incoming directory

Potential signals

* commits waiting
  * which repo?
  * commit hash?

* run single commt
  * which repo?
  * commit hash?

* hooks - I imagine hooks will be intercepted externally and signals raised

* email - If commit emails are implemented, that could also raise a signal
