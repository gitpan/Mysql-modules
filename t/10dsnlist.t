#!/usr/local/bin/perl
#
#   $Id: 10dsnlist.t,v 1.1804 1997/08/30 15:11:07 joe Exp $
#
#   This test creates a database and drops it. Should be executed
#   after listdsn.
#


#
#   List of drivers that may execute this test; if this list is
#   empty, than any driver may execute the test.
#
#@DRIVERS_ALLOWED = ();


#
#   List of drivers that may not execute this test; this list is
#   only used if @DRIVERS_ALLOWED is empty
#
@DRIVERS_DENIED = @DRIVERS_DENIED = ('pNET');


#
#   Include lib.pl
#
use DBI 0.88;
$driver = "";
$test_dsn = $test_user = $test_password = ""; # Hate -w  :-)
foreach $file ("lib.pl", "t/lib.pl") {
    do $file; if ($@) { print STDERR "Error while executing lib.pl: $@\n";
			   exit 10;
		      }
    if ($driver ne '') {
	last;
    }
}
if ($verbose) { print "Driver is $driver\n"; }

sub ServerError() {
    print STDERR ("Cannot connect: ", $DBI::errstr, "\n",
	"\tEither your server is not up and running or you have no\n",
	"\tpermissions for acessing the DSN $test_dsn.\n",
	"\tThis test requires a running server and write permissions.\n",
	"\tPlease make sure your server is running and you have\n",
	"\tpermissions, then retry.\n");
    exit 10;
}

#
#   Main loop; leave this untouched, put tests into the loop
#
while (Testing()) {
    # Check if the server is awake.
    $dbh = undef;
    Test($state or ($dbh = DBI->connect($test_dsn, $test_user,
					$test_password)))
	or ServerError();

    Test($state or defined(@dsn = DBI->data_sources($driver)));
    if (!$state  &&  $verbose) {
	my $d;
	print "List of $driver data sources:\n";
	foreach $d (@dsn) {
	    print "    $d\n";
	}
	print "List ends.\n";
    }
}
