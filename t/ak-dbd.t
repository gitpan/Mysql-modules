#!/usr/local/bin/perl
#
#   $Id: ak-dbd.t,v 1.1806 1997/09/03 22:41:04 joe Exp $
#
#   This is a skeleton test. For writing new tests, take this file
#   and modify/extend it.
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
use vars qw($test_dsn $test_user $test_password $driver $verbose $state);
use vars qw($COL_NULLABLE $COL_KEY);
$test_dsn = '';
$test_user = '';
$test_password = '';


#
#   Include lib.pl
#
use DBI;
use strict;
$driver = "";
{   my $file;
    foreach $file ("lib.pl", "t/lib.pl") {
	do $file; if ($@) { print STDERR "Error while executing lib.pl: $@\n";
			    exit 10;
			}
	if ($driver ne '') {
	    last;
	}
    }
}

my $test_db = '';
my $test_hostname = 'localhost';

if ($test_dsn =~ /^DBI\:[^\:]+\:/) {
    $test_db = $';
    if ($test_db =~ /:/) {
	$test_db = $`;
	$test_hostname = $';
    }
}

sub ErrMsg (@) {
    if ($verbose) {
	print (@_);
    }
}

sub ErrMsgF (@) {
    if ($verbose) {
	printf (@_);
    }
}


#
#   Main loop; leave this untouched, put tests after creating
#   the new table.
#
while (Testing()) {
    #
    #   Connect to the database
    my($dbh, $sth, $test_table, $query);
    $test_table = '';  # Avoid warnings for undefined variables.
    Test($state or ($dbh = DBI->connect($test_dsn, $test_user,
					$test_password)))
	or ErrMsg("Cannot connect: $DBI::errstr.\n");

    #
    #   Find a possible new table name
    #
    Test($state or $test_table = FindNewTable($dbh)) or !$verbose
	or ErrMsg("Cannot get table name: $dbh->errstr.\n");

    #
    #   Create a new table; EDIT THIS!
    #
    Test($state or ($query = TableDefinition($test_table,
				     ["id",   "INTEGER",  4, $COL_NULLABLE],
				     ["name", "CHAR",    64, $COL_NULLABLE]),
		    $dbh->do($query)))
	or ErrMsg("Cannot create table: query $query error $dbh->errstr.\n");

    #
    #   and here's the right place for inserting new tests:
    #
    Test($state or $dbh->quote('tast1'))
	or ErrMsgF("quote('tast1') returned %s.\n", $dbh->quote('tast1'));

    ### ...and disconnect
    Test($state or $dbh->disconnect)
	or ErrMsg("\$dbh->disconnect() failed!\n",
		  "Make sure your server is still functioning",
		  "correctly, and check to make\n",
		  "sure your network isn\'t malfunctioning in the",
		  "case of the server running on a remote machine.\n");

    ### Now, re-connect again so that we can do some more complicated stuff..
    Test($state or ($dbh = DBI->connect($test_dsn, $test_user,
					$test_password)))
	or ErrMsg("reconnect failed: $DBI::errstr\n");

    ### List all the tables in the selected database........
    ### This test for mSQL and mysql only.
    if ($driver eq 'mysql'  or $driver eq 'mSQL' or $driver eq 'mSQL1') {
	Test($state or $dbh->func('_ListTables'))
	    or ErrMsgF("_ListTables failed: $dbh->errstr.\n"
		       . "This could be due to the fact you have no tables,"
		       . " but I hope not. You\n"
		       . "could try running '%s -h %s %s' and see if it\n"
		       . "reports any information about your database,"
		       . " or errors.\n",
		       ($driver eq 'mysql') ? "mysqlshow" : "relshow",
		       $test_hostname, $test_db);
    }

    Test($state or $dbh->do("DROP TABLE $test_table"))
	or ErrMsg("Dropping table failed: $dbh->errstr.\n");
    Test($state or ($query = TableDefinition($test_table,
				     ["id",   "INTEGER",  4, $COL_NULLABLE],
				     ["name", "CHAR",    64, $COL_NULLABLE]),
		    $dbh->do($query)))
        or ErrMsg("create failed, query $query, error $dbh->errstr.\n");

    ### Get some meta-data for the table we've just created...
    if ($driver eq 'mysql' or $driver eq 'mSQL1' or $driver eq 'mSQL') {
	my $ref;
	Test($state or ($ref = $dbh->func($test_table, '_ListFields')))
	    or ErrMsg("_ListFields failed: $dbh->errstr.\n");
    }

    ### Insert a row into the test table.......
    Test($state or ($dbh->do("INSERT INTO $test_table VALUES(1,"
			     . " 'Alligator Descartes')")))
         or ErrMsg("INSERT failed: $dbh->errstr.\n");

    ### ...and delete it........
    Test($state or $dbh->do("DELETE FROM $test_table WHERE id = 1"))
         or ErrMsg("Cannot delete row: $dbh->errstr.\n");
    Test($state or ($sth = $dbh->prepare("SELECT * FROM $test_table"
                                         . " WHERE id = 1")))
         or ErrMsg("Cannot select: $dbh->errstr.\n");

    # This should fail with error message: We "forgot" execute.
    Test($state or !$sth->fetchrow)
         or ErrMsg("Missing error report from fetchrow.\n");

    Test($state or $sth->execute)
         or ErrMsg("execute SELECT failed: $dbh->errstr.\n");

    # This should fail without error message: No rows returned.
    my(@row, $ref);
    {
        local($^W) = 0;
        Test($state or !defined($ref = $sth->fetch))
	    or ErrMsgF("Unexpected row returned by fetchrow: $ref\n".
		       scalar(@row));
    }

    # Now try a "finish"
    Test($state or $sth->finish)
	or ErrMsg("sth->finish failed: $sth->errstr.\n");

    # Call destructors:
    Test($state or (undef $sth || 1));

    ### This section should exercise the sth->func( '_NumRows' ) private
    ###  method by preparing a statement, then finding the number of rows
    ###  within it. Prior to execution, this should fail. After execution,
    ###  the number of rows affected by the statement will be returned.
    Test($state or ($dbh->do($query = "INSERT INTO $test_table VALUES"
			               . " (1, 'Alligator Descartes' )")))
	or ErrMsgF("INSERT failed: query $query, error %s.\n", $dbh->errstr);
    Test($state or ($sth = $dbh->prepare($query = "SELECT * FROM $test_table"
					          . " WHERE id = 1")))
	or ErrMsgF("prepare failed: query $query, error %s.\n", $dbh->errstr);
    if ($driver eq 'mysql'  ||  $driver eq 'mSQL'  ||  $driver eq 'mSQL1') {
	Test($state or defined($sth->func('_NumRows')))
	    or ErrMsg("_NumRows returning result before 'execute'.\n");
    }
    Test($state or defined($sth->rows))
	or ErrMsg("sth->rows returning result before 'execute'.\n");


    Test($state or $sth->execute)
	or ErrMsgF("execute failed: query $query, error %s.\n", $sth->errstr);
    if ($driver eq 'mysql'  ||  $driver eq 'mSQL'  ||  $driver eq 'mSQL1') {
	Test($state or ($sth->func('_NumRows') == 1))
	    or ErrMsgF("_NumRows returned wrong result %s after 'execute'.\n",
		       $sth->func('_NumRows'));
    }
    Test($state or $sth->rows == 1)
	or ErrMsgF("sth->rows returned wrong result %s after 'execute'.\n",
		   $sth->rows);
    Test($state or $sth->finish)
	or ErrMsgF("finish failed: %s.\n", $sth->errstr);
    Test($state or (undef $sth or 1));

    ### Test whether or not a field containing a NULL is returned correctly
    ### as undef, or something much more bizarre
    $query = "INSERT INTO $test_table VALUES ( NULL, 'NULL-valued id' )";
    Test($state or $dbh->do($query))
	or ErrMsgF("INSERT failed: query $query, error %s.\n", $dbh->errstr);
    $query = "SELECT id FROM $test_table WHERE id = NULL";
    Test($state or ($sth = $dbh->prepare($query)))
	or ErrMsgF("Cannot prepare, query = $query, error %s.\n",
		   $dbh->errstr);
    Test($state or $sth->execute)
	or ErrMsgF("Cannot execute, query = $query, error %s.\n",
		   $dbh->errstr);
    my $rv;
    Test($state or defined($rv = $sth->fetch))
	or ErrMsgF("fetch failed, error %s.\n", $dbh->errstr);
    Test($state or !defined($$rv[0]))
	or ErrMsgF("Expected NULL value, got %s.\n", $$rv[0]);
    Test($state or $sth->finish)
	or ErrMsgF("finish failed: %s.\n", $sth->errstr);
    Test($state or undef $sth or 1);

    ### Delete the test row from the table
    $query = "DELETE FROM $test_table WHERE id = NULL AND"
        . " name = 'NULL-valued id'";
    Test($state or ($rv = $dbh->do($query)))
        or ErrMsg("DELETE failed: query $query, error %s.\n", $dbh->errstr);

    ### Test whether or not a char field containing a blank is returned
    ###  correctly as blank, or something much more bizarre
    $query = "INSERT INTO $test_table VALUES (2, '')";
    Test($state or $dbh->do($query))
        or ErrMsg("INSERT failed: query $query, error %s.\n", $dbh->errstr);
    $query = "SELECT name FROM $test_table WHERE id = 2 AND name = ''";
    Test($state or ($sth = $dbh->prepare($query)))
        or ErrMsg("prepare failed: query $query, error %s.\n", $dbh->errstr);
    Test($state or $sth->execute)
        or ErrMsg("execute failed: query $query, error %s.\n", $dbh->errstr);
    $rv = undef;
    Test($state or defined($ref = $sth->fetch))
        or ErrMsgF("fetchrow failed: query $query, error %s.\n", $sth->errstr);
    Test($state or (defined($$ref[0])  &&  ($$ref[0] eq '')))
        or ErrMsgF("blank value returned as %s.\n", $$ref[0]);
    Test($state or $sth->finish)
	or ErrMsg("finish failed: $sth->errmsg.\n");
    Test($state or undef $sth or 1);

    ### Delete the test row from the table
    $query = "DELETE FROM $test_table WHERE id = 2 AND name = ''";
    Test($state or $dbh->do($query))
	or ErrMsg("DELETE failed: query $query, error $dbh->errstr.\n");

    ### Test the new funky routines to list the fields applicable to a SELECT
    ### statement, and not necessarily just those in a table...
    $query = "SELECT * FROM $test_table";
    Test($state or ($sth = $dbh->prepare($query)))
	or ErrMsg("prepare failed: query $query, error $dbh->errstr.\n");
    Test($state or $sth->execute)
	or ErrMsg("execute failed: query $query, error $dbh->errstr.\n");
    if ($driver eq 'mysql'  ||  $driver eq 'mSQL'  ||  $driver eq 'mSQL1') {
	Test($state or ($ref = $sth->func('_ListSelectedFields')))
	    or ErrMsg("_ListSelectedFields failed, error $sth->errstr.\n");
    }
    Test($state or $sth->execute)
	or ErrMsg("re-execute failed: query $query, error $dbh->errstr.\n");
    Test($state or (@row = $sth->fetchrow))
	or ErrMsg("Query returned no result, query $query,",
		  " error $sth->errstr.\n");
    Test($state or $sth->finish)
	or ErrMsg("finish failed: $sth->errmsg.\n");
    Test($state or undef $sth or 1);

    ### Insert some more data into the test table.........
    $query = "INSERT INTO $test_table VALUES( 2, 'Gary Shea' )";
    Test($state or $dbh->do($query))
        or ErrMsg("INSERT failed: query $query, error $dbh->errstr.\n");
    $query = "UPDATE $test_table SET id = 3 WHERE name = 'Gary Shea'";
    Test($state or ($sth = $dbh->prepare($query)))
        or ErrMsg("prepare failed: query $query, error $sth->errmsg.\n");
    # This should fail: We "forgot" execute.
    if ($driver eq 'mysql'  ||  $driver eq 'mSQL'  ||  $driver eq 'mSQL1') {
        Test($state or !defined($sth->{'NAME'}))
            or ErrMsg("Expected error without execute, got $ref.\n");
    }
    Test($state or undef $sth or 1);

    ### Drop the test table out of our database to clean up.........
    Test($state or $dbh->do($query))
        or ErrMsg("DROP failed: query $query, error $dbh->errstr.\n");

    Test($state or $dbh->disconnect)
        or ErrMsg("disconnect failed: $dbh->errstr.\n");

    # Are we backwards compatible with the DBD::mSQL testscript connect
    # method that was valid up to version 0.66 or so?

    # undocumented, will go away, transition variable
    if ($driver eq 'mSQL'  ||  $driver eq 'mSQL1') {
        $DBD::mSQL::QUIET = $DBD::mSQL::QUIET = 1;
        $DBD::mysql::QUIET = $DBD::mysql::QUIET = 1;
        # We fill in the username. Bad thing.
        Test($state or ($dbh = DBI->connect($test_hostname, $test_db,
                                            '', $driver)))
            or ErrMsgF("connect failed: %s.\n", $DBI::errstr);
    }
    Test($state or $dbh->disconnect)
        or ErrMsg("disconnect failed: $dbh->errstr.\n");
}

