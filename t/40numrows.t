#!/usr/local/bin/perl
#
#   $Id: 40numrows.t,v 1.1805 1997/09/03 12:22:35 joe Exp $
#
#   This tests, whether the number of rows can be retrieved.
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


#
#   Include lib.pl
#
use DBI;
$driver = "";
foreach $file ("lib.pl", "t/lib.pl") {
    do $file; if ($@) { print STDERR "Error while executing lib.pl: $@\n";
			   exit 10;
		      }
    if ($driver ne '') {
	last;
    }
}

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
    Test($state or ($dbh = DBI->connect($test_dsn, $test_user,
					$test_password)))
	or ServerError();

    #
    #   Find a possible new table name
    #
    Test($state or ($table = FindNewTable($dbh)))
	   or DbiError($dbh->err, $dbh->errstr);

    #
    #   Create a new table; EDIT THIS!
    #
    Test($state or ($def = TableDefinition($table,
					   ["id",   "INTEGER",  4, 0],
					   ["name", "CHAR",    64, 0]),
		    $dbh->do($def)))
	   or DbiError($dbh->err, $dbh->errstr);


    #
    #   This section should exercise the sth->rows
    #   method by preparing a statement, then finding the
    #   number of rows within it.
    #   Prior to execution, this should fail. After execution, the
    #   number of rows affected by the statement will be returned.
    #
    Test($state or $dbh->do("INSERT INTO $table"
			    . " VALUES( 1, 'Alligator Descartes' )"))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($cursor = $dbh->prepare("SELECT * FROM $table"
					   . " WHERE id = 1")))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->execute)
           or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($numrows = $cursor->rows) == 1)
           or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->finish)
           or DbiError($dbh->err, $dbh->errstr);

    Test($state or undef $cursor or 1);

    Test($state or $dbh->do("INSERT INTO $table"
			    . " VALUES( 2, 'Jochen Wiedmann' )"))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($cursor = $dbh->prepare("SELECT * FROM $table"
					    . " WHERE id >= 1")))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->execute)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($numrows = $cursor->rows) == 2)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->finish)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or undef $cursor or 1);

    Test($state or $dbh->do("INSERT INTO $table"
			    . " VALUES(3, 'Tim Bunce')"))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($cursor = $dbh->prepare("SELECT * FROM $table"
					    . " WHERE id >= 2")))
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->execute)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or ($numrows = $cursor->rows) == 2)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or $cursor->finish)
	   or DbiError($dbh->err, $dbh->errstr);

    Test($state or undef $cursor or 1);

    #
    #   Finally drop the test table.
    #
    Test($state or $dbh->do("DROP TABLE $table"))
	   or DbiError($dbh->err, $dbh->errstr);

}
