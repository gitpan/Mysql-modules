#!/usr/local/bin/perl
#
#   $Id: 00base.t,v 1.1809 1997/09/12 18:35:06 joe Exp $
#
#   This is the base test, tries to install the drivers. Should be
#   executed as the very first test.
#


#
#   Include lib.pl
#
$driver = "";
foreach $file ("lib.pl", "t/lib.pl") {
    do $file; if ($@) { print STDERR "Error while executing lib.pl: $@\n";
			   exit 10;
		      }
    if ($driver ne '') {
	last;
    }
}
if ($verbose) { print "Driver is $driver\n"; }

# Base DBD Driver Test

print "1..$tests\n";

require DBI;
print "ok 1\n";

import DBI;
print "ok 2\n";

$switch = DBI->internal;
(ref $switch eq 'DBI::dr') ? print "ok 3\n" : print "not ok 3\n";

# This is a special case. install_driver should not normally be used.
$drh = DBI->install_driver($driver);

(ref $drh eq 'DBI::dr') ? print "ok 4\n" : print "not ok 4\n";

if ($drh->{Version}) {
    print "ok 5\n";
    if ($verbose) {
	print "Driver version is ", $drh->{Version}, "\n";
    }
}

BEGIN { $tests = 5 }
exit 0;
# end.
