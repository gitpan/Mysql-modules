#!/usr/local/bin/perl
#
#   $Id: 40listfields.t,v 1.1805 1997/09/03 12:22:34 joe Exp $
#
#   This is a test for statement attributes being present appropriately.
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
#@DRIVERS_DENIED = ();


#
#   Make -w happy
#
$test_dsn = '';
$test_user = '';
$test_password = '';
$COL_KEY = '';


#
#   Include lib.pl
#
use DBI;
use vars qw($verbose);

$driver = "";
foreach $file ("lib.pl", "t/lib.pl") {
    do $file; if ($@) { print STDERR "Error while executing lib.pl: $@\n";
			   exit 10;
		      }
    if ($driver ne '') {
	last;
    }
}


@table_def = (
	      ["id",   "INTEGER",  4, $COL_KEY],
	      ["name", "CHAR",    64, $COL_NULLABLE]
	     );

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
#   Main loop; leave this untouched, put tests after creating
#   the new table.
#
while (Testing()) {
    #
    #   Connect to the database
    Test($state or $dbh = DBI->connect($test_dsn, $test_user, $test_password))
	or ServerError();

    #
    #   Find a possible new table name
    #
    Test($state or $table = FindNewTable($dbh))
	   or DbiError($dbh->err, $dbh->errstr);

    #
    #   Create a new table
    #
    Test($state or ($def = TableDefinition($table, @table_def),
		    $dbh->do($def)))
	   or DbiError($dbh->err, $dbh->errstr);


    Test($state or $cursor = $dbh->prepare("SELECT * FROM $table"))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->execute)
	   or DbiError($cursor->err, $cursor->errstr);

    my $res;
    Test($state or (($res = $cursor->{'NUM_OF_FIELDS'}) == @table_def))
	   or DbiError($cursor->err, $cursor->errstr);
    if (!$state && $verbose) {
	printf("Number of fields: %s\n", defined($res) ? $res : "undef");
    }

    Test($state or ($ref = $cursor->{'NAME'})  &&  @$ref == @table_def
	            &&  $$ref[0] eq $table_def[0][0]
		    &&  $$ref[1] eq $table_def[1][0])
	   or DbiError($cursor->err, $cursor->errstr);
    if (!$state && $verbose) {
	print "Names:\n";
	for ($i = 0;  $i < @$ref;  $i++) {
	    print "    ", $$ref[$i], "\n";
	}
    }

    Test($state or ($ref = $cursor->{'NULLABLE'})  &&  @$ref == @table_def
		    &&  !($$ref[0] xor ($table_def[0][3] & $COL_NULLABLE))
		    &&  !($$ref[1] xor ($table_def[1][3] & $COL_NULLABLE)))
	   or DbiError($cursor->err, $cursor->errstr);
    if (!$state && $verbose) {
	print "Nullable:\n";
	for ($i = 0;  $i < @$ref;  $i++) {
	    print "    ", ($$ref[$i] & $COL_NULLABLE) ? "yes" : "no", "\n";
	}
    }

    Test($state or undef $cursor  ||  1);


    #
    #   Finally drop the test table.
    #
    Test($state or $dbh->do("DROP TABLE $table"))
	   or DbiError($dbh->err, $dbh->errstr);

}
