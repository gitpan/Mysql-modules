#   Hej, Emacs, give us -*- perl mode here!
#
#   $Id: lib.pl,v 1.1810 1997/09/12 23:54:35 joe Exp $
#
#   lib.pl is the file where database specific things should live,
#   whereever possible. For example, you define certain constants
#   here and the like.
#

require 5.003;
use strict;
use vars qw($driver);


#
#   Driver name; EDIT THIS!
#
$driver = 'mysql';


#
#   DSN being used; EDIT THIS!
#
if (!defined($::test_dsn = $ENV{'TEST_DSN'})) {
    $::test_dsn = "DBI:$driver:test";
}
if (!defined($::test_user = $ENV{'TEST_USER'})) {
    $::test_user = '';
}
if (!defined($::test_password = $ENV{'TEST_PASSWORD'})) {
    $::test_password = '';
}



#
#   This function generates a list of tables associated to a
#   given DSN. Highly DBMS specific, EDIT THIS!
#
sub ListTables($) {
    my($dbh) = @_;
    my(@tables);

    if ($driver eq 'mysql'  ||  $driver eq 'mSQL') {
	if (!defined(@tables = $dbh->func('_ListTables'))  ||  $dbh->errstr) {
	    return undef;
	}
    } else {
	die("ListTables() not implemented for your driver\n");
    }
    @tables;
}
$::listTablesHook = \&ListTables;


#   This function generates a mapping of ANSI type names to
#   database specific type names; it is called by TableDefinition().
#   EDIT THIS!
#
sub AnsiTypeToDb ($;$) {
    my ($type, $size) = @_;
    my ($ret);
    if ($driver eq 'mysql') {
	if ((lc $type) eq 'blob') {
	    if ($size >= 1 << 16) {
		$ret = 'MEDIUMBLOB';
	    } else {
		$ret = 'BLOB';
	    }
	} elsif ((lc $type) eq 'int'  ||  (lc $type) eq 'integer') {
	    $ret = $type;
	} elsif ((lc $type) eq 'char') {
	    $ret = "CHAR($size)";
	} else {
	    warn "Unknown type $type\n";
	    $ret = $type;
	}
    } elsif ($driver eq 'mSQL' || $driver eq 'mSQL1') {
	if ((lc $type) eq 'int'  ||  (lc $type) eq 'integer') {
	    $ret = $type;
	} elsif ((lc $type) eq 'char') {
	    $ret = "CHAR($size)";
	} else {
	    warn "Unknown type $type\n";
	    $ret = $type;
	}
    } else {
	die("AnsiTypeToDb() not implemented for your driver\n");
    }
    $ret;
}


#
#   This function generates a table definition based on an
#   input list. The input list consists of references, each
#   reference referring to a single column. The column
#   reference consists of column name, type, size and a bitmask of
#   certain flags, namely
#
#       $COL_NULLABLE - true, if this column may contain NULL's
#       $COL_KEY - true, if this column is part of the table's
#           primary key
#
#   Hopefully there's no big need for you to modify this function,
#   if your database conforms to ANSI specifications. EDIT THIS!
#

$::COL_NULLABLE = 1;
$::COL_KEY = 2;

sub TableDefinition ($@) {
    my($tablename, @cols) = @_;
    my($def);

    if ($driver eq 'mysql' || $driver eq 'mSQL'  ||  $driver eq 'mSQL1') {
	#
	#   Should be acceptable for most ANSI conformant databases;
	#
	#   msql 1 uses a non-ANSI definition of the primary key: A
	#   column definition has the attribute "PRIMARY KEY". On
	#   the other hand, msql 2 uses the ANSI fashion ...
	#
	my($col, @keys, @colDefs, $keyDef);

	#
	#   Count number of keys
	#
	@keys = ();
	foreach $col (@cols) {
	    if ($$col[2] & $::COL_KEY) {
		push(@keys, $$col[0]);
	    }
	}
	if (@keys > 1  &&  ($driver eq 'mSQL'  ||  $driver eq 'mSQL1')) {
	    warn "Warning: Your test won't run with msql 1\n";
	}

	foreach $col (@cols) {
	    my $colDef = $$col[0] . " " . AnsiTypeToDb($$col[1], $$col[2]);
	    if (($$col[3] & $::COL_KEY)  &&  @keys == 1  &&
		($driver eq 'mSQL'  ||  $driver eq 'mSQL1')) {
		$colDef .= " PRIMARY KEY";
	    } elsif (!($$col[3] & $::COL_NULLABLE)) {
		$colDef .= " NOT NULL";
	    }
	    push(@colDefs, $colDef);
	}
	if (@keys > 1  ||
	    (@keys == 1  &&  $driver ne 'mSQL'  &&  $driver ne 'mSQL1')) {
	    $keyDef = ", PRIMARY KEY (" . join(", ", @keys) . ")";
	} else {
	    $keyDef = "";
	}
	$def = sprintf("CREATE TABLE %s (%s%s)", $tablename,
		       join(", ", @colDefs), $keyDef);
    } else {
	die("TableDefinition() not implemented for your driver\n");
    }
    if ($::verbose) {
	print "Table definition: $def\n";
    }
    $def;
}


#
#   The Testing() function builds the frame of the test; it can be called
#   in many ways, see below.
#
#   Usually there's no need for you to modify this function.
#
#       Testing() (without arguments) indicates the beginning of the
#           main loop; it will return, if the main loop should be
#           entered (which will happen twice, once with $state = 1 and
#           once with $state = 0)
#       Testing('off') disables any further tests until the loop ends
#       Testing('group') indicates the begin of a group of tests; you
#           may use this, for example, if there's a certain test within
#           the group that should make all other tests fail.
#       Testing('disable') disables further tests within the group; must
#           not be called without a preceding Testing('group'); by default
#           tests are enabled
#       Testing('enabled') reenables tests after calling Testing('disable')
#       Testing('finish') terminates a group; any Testing('group') must
#           be paired with Testing('finish')
#
#   You may nest test groups.
#
{
    # Note the use of the pairing {} in order to get local, but static,
    # variables.
    my (@stateStack, $count, $off);

    $count = 0;

    sub Testing(;$) {
	my ($command) = shift;
	if (!defined($command)) {
	    @stateStack = ();
	    $off = 0;
	    if ($count == 0) {
		++$count;
		$::state = 1;
	    } elsif ($count == 1) {
		my($d);
		if (@::DRIVERS_ALLOWED) {
		    $off = 1;
		    foreach ($d) {
			if ($d eq $driver) {
			    $off = 0;
			    last;
			}
		    }
		} else {
		    $off = 0;
		    foreach $d (@::DRIVERS_DENIED) {
			if ($d eq $driver) {
			    $off = 1;
			    last;
			}
		    }
		}
		if ($off) {
		    print "1..0\n";
		    exit 0;
		}
		++$count;
		$::state = 0;
		print "1..$::numTests\n";
	    } else {
		return 0;
	    }
	    if ($off) {
		$::state = 1;
	    }
	    $::numTests = 0;
	} elsif ($command eq 'off') {
	    $off = 1;
	    $::state = 0;
	} elsif ($command eq 'group') {
	    push(@stateStack, $::state);
	} elsif ($command eq 'disable') {
	    $::state = 0;
	} elsif ($command eq 'enable') {
	    if ($off) {
		$::state = 0;
	    } else {
		my $s;
		$::state = 1;
		foreach $s (@stateStack) {
		    if (!$s) {
			$::state = 0;
			last;
		    }
		}
	    }
	    return;
	} elsif ($command eq 'finish') {
	    $::state = pop(@stateStack);
	} else {
	    die("Testing: Unknown argument\n");
	}
	return 1;
    }


#
#   Read a single test result
#
    sub Test ($;$$) {
	my($result, $error, $diag) = @_;
	++$::numTests;
	if ($count == 2) {
	    if ($::verbose && defined($diag)) {
	        printf("$diag%s", (($diag =~ /\n$/) ? "" : "\n"));
	    }
	    if ($::state || $result) {
		print "ok $::numTests\n";
		return 1;
	    } else {
		printf("not ok $::numTests%s\n",
			(defined($error) ? " $error" : ""));
		return 0;
	    }
	}
	return 1;
    }
}


#
#   Print a DBI error message
#
sub DbiError ($$) {
    my($rc, $err) = @_;
    if ($::verbose) {
	print "Test $::numTests: DBI error $rc, $err\n";
    }
}


#
#   This functions generates a list of possible DSN's aka
#   databases and returns a possible table name for a new
#   table being created.
#
{
    my(@tables, $testtable, $listed);

    $testtable = "testaa";
    $listed = 0;

    sub FindNewTable($) {
	my($dbh) = @_;

	if (!$listed  &&  !defined(@tables = &$::listTablesHook($dbh))) {
	    return '';
	}
	$listed = 1;

	# A small loop to find a free test table we can use to mangle stuff in
	# and out of. This starts at testaa and loops until testaz, then testba
	# - testbz and so on until testzz.
	my $foundtesttable = 1;
	my $table;
	while ($foundtesttable) {
	    $foundtesttable = 0;
	    foreach $table (@tables) {
		if ($table eq $testtable) {
		    $testtable++;
		    $foundtesttable = 1;
		}
	    }
	}
	$table = $testtable;
	$testtable++;
	$table;
    }
}
