use Config;
use File::Basename qw(&basename &dirname);
# This forces PL files to create target in same directory as PL file.
# This is so that make depend always knows where to find PL derivatives.
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
	if ($Config{osname} eq 'VMS' or $Config{osname} eq 'os2');  # "case-forgiving"

open OUT,">$file" or die "Can\'t create $file: $!";

print "Extracting $file (with variable substitutions)\n";

#
# Start of pmsql and pmysql
#

print OUT <<"!GROK!THIS!";
$Config{'startperl'}
!GROK!THIS!

print OUT <<'!NO!SUBS!';
#
#   dbimon - DBI monitor
#
#
#   Author and Copyright (c) 1997:  Jochen Wiedmann
#                                   Am Eisteich 9
#                                   72555 Metzingen
#                                   Germany
#
#                                   Email: wiedmann@neckar-alb.de
#                                   Phone: +49 7123 14887
#
#   dbimon is based on pmsql, which is
#
#   Copyright 1994-1997  Andreas König
#
#   You may distribute this under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file,
#   with the exception that it cannot be placed on a CD-ROM or similar media
#   for commercial distribution without the prior approval of the author.
#
#   $Id: Makefile.PL,v 1.1804.1.1 1997/08/30 17:03:28 joe Exp $
#
############################################################################
#
#   Required modules
#
require 5.004;
use Carp ();
use strict;      # Enable for testing only, disable for distributions
                 # users won't like this for eval's
use DBI ();
use Term::ReadLine ();


############################################################################
#
#   Constants
#
my $VERSION = sprintf("%d.%02d%02d%02d",
		      split(/\./, substr(q$Revision: 1.1804.1.1 $, 10)));

my @VALID_VARS = ("fancyOutput", "less", "maxColumnLength", "maxRows",
		  "escapeChar", "quoteChar", "sepChar");

############################################################################
#
#   Global variables
#

my $term = undef;
my $prompt = "dbimon> ";
my $batchMode = 0;
my $fancyOutput = 1;
my $less;
my $debugging = 0;

my $driver;
my $dbh;
my $dsn;
my $user;
my $password;

# Variables that may be modified via the 'set' command
my $maxColumnLength = 1024;
my $maxRows         = 100;
my $escapeChar      = '"';
my $quoteChar       = '"';
my $sepChar         = ';';


############################################################################
#
#   Name:    FindExe
#
#   Purpose: Try's to find an executable in the users PATH
#
#   Inputs:  $exe - executable name
#            $path - reference to array of directory names
#
#   Returns: absolute path name of executable, if found; empty string
#            otherwise
#
############################################################################

sub FindExe ($$) {
    my($exe,$path) = @_;
    my($dir);
    for $dir (@$path) {
        my $abs = "$dir/$exe";
        if (-x $abs) {
            return $abs;
        }
    }
    '';
}


############################################################################
#
#   Name:    Connect
#
#   Purpose: Attempts to connect to a database.
#
#   Inputs:  $dsn - datasource name, for example "DBI:mysql:test"
#            $user - user name
#            $pwd - password
#
#   Returns: database handle or 'undef' in case of problems
#
############################################################################

sub Connect ($;$$) {
    my ($ndsn, $nuser, $npassword) = @_;
    my ($dbh);

    if (!defined($ndsn)  ||  $ndsn eq '') {
	print "Missing datasource name.\n";
	return undef;
    }
    if ($ndsn !~ /^DBI:/) {
	$ndsn = "DBI:$ndsn";
    }

    $dbh = eval { DBI->connect($ndsn, $nuser, $npassword); };
    if ($@) {
	print "Failed to connect, perhaps driver problems: $@\n";
	return undef;
    }
    if (!defined($dbh)) {
	my $errmsg = $DBI::errstr;
	print "Failed to connect: $errmsg\n";
	if (!$batchMode  &&  !defined($npassword)  ||  $npassword eq '') {
	    print "This might be due to a missing password. If so, enter\n";
	    print "the password, otherwise just type return: ";
	    $npassword = <STDIN>; chomp $npassword;
	    if (defined($npassword)  &&  $npassword ne '') {
		$dbh = DBI->connect($ndsn, $nuser, $npassword);;
		if (!defined($dbh)) {
		    print "Failed to connect: ", $DBI::errstr, "\n";
		}
	    }
	}
    }

    if ($dbh) {
	if ($ndsn =~ /^DBI\:([^\:]+)\:/) {
	    $driver = $1;
	} else {
	    $driver = undef;
	}
	$dsn = $ndsn;
	$user = $nuser;
	$password = $npassword;
    }

    $dbh;
}


############################################################################
#
#   Name:    Output
#
#   Purpose: Formats and prints a query result.
#
#   Inputs:  $sth - statement handle of query, 'execute' called on
#                this sth
#
#   Returns: Nothing
#
############################################################################

sub Output ($) {
    my ($sth) = @_;
    my $numTruncated = 0;

    if (!open(OUT, (!$batchMode  &&  $less ne 'stdout'  &&  $less ne '') ?
	           "| $less" : ">&STDOUT")) {
#
	print STDERR "Cannot open output channel: $!\n";
	return;
    }

    if (!$fancyOutput) {
	# Output for export is somewhat simpler ...
	my(@res);
	my($ePattern, $qPattern, $null, $ref, $quote);

	# Create a pattern for escaping one column; we escape the
	# $escapeChar, the $quoteChar and \0.
	$quote = defined($quoteChar) ? $quoteChar : "";
	if (defined($escapeChar)  &&  $escapeChar ne '') {
	    $ePattern = $escapeChar;
	    $ePattern =~ s/(.)/\\$1/g;
	    if ($quote ne '') {
		$qPattern = $quote;
		$qPattern =~ s/(.)/\\$1/g;
		if ($ePattern) {
		    $ePattern = "$ePattern|$qPattern";
		} else {
		    $ePattern = $qPattern;
		}
	    }
	    $ePattern = "($ePattern|\\0)";
	} else {
	    $ePattern = '';
	}
	$null = 0;

	# Now the true output
	while (defined($ref = $sth->fetchrow_arrayref())) {
	    my $add = '';
	    my $word;
	    foreach $word (@$ref) {
		if ($ePattern) {
		    $word =~ s/($ePattern)/$escapeChar$1/g;
		}
		printf OUT ("%s%s%s%s", $quote, $word, $quote, $add);
		$add = $sepChar;
	    }
	}
    } else {
	# Here's the really hard part: Fancy output.
	#
	# The most difficult problem is to decide about the field
	# length of a given column.
	my (@lengths);
	my ($i, $numFields, $choosedFields);
	my (@rowBuffer, $lastRowSeen, $ref);

	$numFields = $sth->{'NUM_OF_FIELDS'};
	$choosedFields = 0;


	# First try asking the driver.
	if ($choosedFields < $numFields  &&
	    defined($ref = $sth->{'format_default_size'})) {
	    @lengths = @$ref;
	    for ($i = 0;  $i < $numFields;  $i++) {
		if (defined($lengths[$i] = $$ref[$i])) {
		    $choosedFields++;
		}
	    }
	}


	# The driver gave us no idea.
	# Heuristically we fetch the first $maxRows rows and count the
	# maximum field length.
	$lastRowSeen = 0;
	if ($choosedFields < $numFields) {
	    my ($j, @maxLengths);
	    for ($j = 0;  $j < $maxRows;  $j++) {
		if (!($ref = $sth->fetchrow_arrayref)) {
		    $lastRowSeen = 1;
		    last;
		}
		push(@rowBuffer, [@$ref]);
		for ($i = 0;  $i < $numFields;  $i++) {
		    if (!defined($$ref[$i])) {
			$$ref[$i] = 'NULL';
                    }
		    if (!defined($lengths[$i])) {
			my $len = defined($$ref[$i]) ? length($$ref[$i]) : 0;
			if (!defined($maxLengths[$i])  ||
			    $maxLengths[$i] < $len) {
			    $maxLengths[$i] = $len;
			}
		    }
		}
	    }
	    for ($i = 0;  $i < $numFields;  $i++) {
		if (!defined($lengths[$i])  &&
		    defined($maxLengths[$i])) {
		    $lengths[$i] = $maxLengths[$i];
		}
	    }
	}

	# For columns that are still open: Ask the driver for
	# maximum possible size.
	if ($choosedFields < $numFields  &&
	    defined($ref = $sth->{'format_max_size'})) {
	    for ($i = 0;  $i < $numFields;  $i++) {
		if (defined($$ref[$i])  &&  ($$ref[$i] != -1)  &&
		    !defined($lengths[$i])) {
		    $$ref[$i] = $lengths[$i];
		    ++$choosedFields;
		}
	    }
	}


	# Final criterion for column length: The column name
	my $names;
	if (defined($names = $sth->{'NAME'})) {
	    for ($i = 0;  $i < $numFields;  $i++) {
		if (defined($$names[$i])  &&
		    (!defined($lengths[$i])  ||
		     length($$names[$i]) > $lengths[$i])) {
		    $lengths[$i] = length($$names[$i]);
		}
	    }
	}

	# Determine the order of printing columns. This will usually
	# be 0, 1, 2, etc. If there are still any rows without length
	# information, put them at the end
	my(@aRows, @bRows);
	for ($i = 0;  $i < $numFields;  $i++) {
	    if (!defined($lengths[$i])) {
		$lengths[$i] = 0; # Note, that $lengths[$i] is an integer now
		push(@bRows, $i);
	    } elsif ($lengths[$i] == 0) {
		push(@bRows, $i);
	    } else {
		push(@aRows, $i);
	    }
	    if ($maxColumnLength  &&  ($lengths[$i] > $maxColumnLength)) {
		$lengths[$i] = $maxColumnLength;
	    }
	}
	push(@aRows, @bRows);

	# Create a header line in the format ---|--|-----
	my ($header, $add, $empty);
	foreach $i (@aRows) {
	    $header .= "|" . "-" x $lengths[$i];
	}
	$header .= "|\n";

	# Print table header
	print OUT ($header);
	foreach $i (@aRows) {
	    my $format = sprintf("|%%-%ds", $lengths[$i]);
	    my $name = defined($$names[$i]) ? $$names[$i] : "";
	    if (length($name) > $lengths[$i]) {
		$name = substr(0, $lengths[$i]);
	    }
	    printf OUT ($format, $name);
	}
	printf OUT ("|\n%s", $header);

	# Now create a format string for printing the real data
	my $format = "";
	my $types = $sth->{'format_right_justify'};
	foreach $i (@aRows) {
	    my $len = $lengths[$i];
	    if ($len > $maxColumnLength) {
		$len = $maxColumnLength;
	    }
	    if (defined($$types[$i])  &&  $$types[$i]) {
		$format .= sprintf("|%%-%ds", $len);
	    } else {
		$format .= sprintf("|%%%ds", $len);
	    }
	}
	$format .= "|\n";

	# Believe it or not: Here comes the true print ...
	#
	# Note that we do not fetch another row if $lastRowSeen = 1.
	# The DBI specification would allow us, but let´s be cautious ...
	while (defined($ref = shift @rowBuffer)  ||
	       !$lastRowSeen  &&  defined($ref = $sth->fetchrow_arrayref)) {
	    my ($col, @row);
	    @row = ();
	    foreach $i (@aRows) {
		my $len = $lengths[$i];
		my $col = $$ref[$i];
		if (!defined($col)) {
		    $col = 'NULL';
		} elsif (length($col) > $len) {
		    $col = substr($col, 0, $len);
		    $numTruncated++;
		}
		push(@row, $col);
	    }
	    printf OUT ($format, @row);
	}
	print OUT ($header);
    }

    close(OUT);

    if ($numTruncated) {
	print "Warning: $numTruncated columns have been truncated.\n";
	print "You might suppress truncation by increasing maxColumnLength\n";
	print "or disable truncation by setting maxColumnLength = 0.\n";
    }
}


############################################################################
#
#   Name:    RelShow
#
#   Purpose: Display list of dsn's, tables or fields
#
#   Inputs:  $dsn - undef, if list of dsn's should be displayed,
#                otherwise dsn being displayed
#            $table - undef, if list of tables should be displayed,
#                otherwise table being displayed
#
#   Returns: Nothing
#
############################################################################

sub DisplayList ($$) {
    my ($header, $l) = @_;

    my $len = length($header);
    my $dsn;
    foreach $dsn (@$l) {
	if (length($dsn) > $len) {
	    $len = length($dsn);
	}
    }
    my $format = sprintf("|  %%-%ds  |\n", $len);
    my $bar = "+--" . ("-" x $len) . "--+\n";
    print $bar;
    printf($format, $header);
    print $bar;
    foreach $dsn (@$l) {
	printf($format, $dsn);
    }
    print $bar;
}

sub DsnList() {
    my @l;
    eval { @l = DBI->data_sources($driver); };
    if ($@) {
	@l = ();
    }
    @l;
}

sub TableList ($) {
    my ($rdsn) = shift;
    if ($rdsn !~ /\:/) {
	$rdsn = "DBI:$driver:$rdsn";
    } elsif ($rdsn !~ /\:[^\:]+\:/) {
	$rdsn = "DBI:$rdsn";
    }
    my (@l, $ndbh);
    eval {
	if ($dsn ne $rdsn) {
	    my $ndbh = DBI->connect($rdsn, $user, $password);
	    if ($ndbh) {
		@l = $ndbh->func("_ListTables");
		$ndbh->disconnect;
	    }
	} else {
	    @l = $dbh->func("_ListTables");
	}
    };
    if ($@) {
	@l = ();
    }
    @l;
}

sub FieldList($$;$) {
    my ($rdsn, $table, $dbhRef) = @_;
    if ($rdsn !~ /\:/) {
	$rdsn = "DBI:$driver:$rdsn";
    } elsif ($rdsn !~ /\:[^\:]+\:/) {
	$rdsn = "DBI:$rdsn";
    }
    my ($sth);
    eval {
	if ($dsn ne $rdsn) {
	    my $ndbh = DBI->connect($rdsn, $user, $password);
	    if ($ndbh) {
		$sth = $ndbh->func($table, "_ListFields");
		($sth, $ndbh);
	    } else {
		(undef);
	    }
	} else {
	    $sth = $dbh->func($table, "_ListFields");
	    ($sth);
	}
    };
}

sub RelShow (;$$) {
    my($dsn, $table) = @_;

    if (!defined($dsn)) {
	#
	#  relshow
	#
	if (!defined($driver)) {
	    print("Cannot display datasources: Unable to determine driver\n",
		  " name in dsn $dsn.\n");
	} else {
	    my @l = DsnList();
	    if ($@) {
		print "Cannot get dsn list, perhaps a driver problem: $@.\n";
	    } elsif (!@l) {
		print "No databases found.\n";
	    } else {
		DisplayList("DSN list", \@l);
	    }
	}
	return;
    }

    if (!defined($table)) {
	#
	# relshow database
	#
	my @l = TableList($dsn);
	if (!@l) {
	    print "No tables found.\n";
	} else {
	    DisplayList("Table list", \@l);
	}
	return;
    }

    my ($sth, $ndbh) = FieldList($dsn, $table);

    if ($@) {
	print "Cannot get list, perhaps a driver problem: $@.\n";
    } else {
	#
	# relshow database table
	#
	if (!$sth) {
	    print "Cannot get table list, error", $dbh->errstr, "\n";
	} else {
	    my ($fLen, $tLen, $lLen, $nLen) = (length("Field"),
					       length("Type"),
					       length("Length"),
					       length("Not Null"));
	    my ($numFields, $fRef, $tRef, $lRef, $nRef);
	    eval {
		$numFields = $sth->{'NUM_OF_FIELDS'};
		$fRef = [@{$sth->{'NAME'}}];
		$nRef = [@{$sth->{'NULLABLE'}}];
		$tRef = [@{$sth->{'format_type_name'}}];
		$lRef = [@{$sth->{'length'}}];
	    };
	    if (ref($fRef) ne 'ARRAY') { $fRef = []; };
	    if (ref($nRef) ne 'ARRAY') { $nRef = []; };
	    if (ref($tRef) ne 'ARRAY') { $tRef = []; };
	    if (ref($lRef) ne 'ARRAY') { $lRef = []; };
	    
	    my $i;
	    for ($i = 0;  $i < $numFields;  $i++) {
		if (!defined($$fRef[$i])) {
		    $$fRef[$i] = "unknown";
		}
		if ($fLen < length($$fRef[$i])) {
		    $fLen = length($$fRef[$i]);
		}
		if (!defined($$tRef[$i])) {
		    $$tRef[$i] = "unknown";
		}
		if ($tLen < length($$tRef[$i])) {
		    $tLen = length($$tRef[$i]);
		}
		if (!defined($$lRef[$i])) {
		    $$lRef[$i] = "N/A";
		}
		if ($lLen < length($$lRef[$i])) {
		    $lLen = length($$lRef[$i]);
		}
		if (!defined($$nRef[$i])) {
		    $$nRef[$i] = "  N/A   ";
		} else {
		    $$nRef[$i] = $$nRef[$i] ? "    N   " : "    Y   ";
		}
		if ($nLen < length($$nRef[$i])) {
		    $nLen = length($$nRef[$i]);
		}
	    }
	
	    if ($numFields == 0) {
		print "No fields found ?!?\n";
	    } else {
		my $format = sprintf("| %%-%ds | %%-%ds | %%%ds | %%%ds |\n",
				     $fLen, $tLen, $lLen, $nLen);
		my $bar = "+-" . ("-" x $fLen) . "-+-" . ("-" x $tLen)
		    . "-+-" . ("-" x $lLen) . "-+-" . ("-" x $nLen) . "-+\n";
		print $bar;
		printf($format, "Field", "Type", "Length", "Not Null");
		print $bar;
		my $i;
		for ($i = 0;  $i < $numFields;  $i++) {
		    printf($format, $$fRef[$i], $$tRef[$i], $$lRef[$i],
			   $$nRef[$i]);
		}
		print $bar;
	    }
	    undef $sth;
	}
    }

    if ($ndbh) {
	$ndbh->disconnect;
    }
}


############################################################################
#
#   Name:    GetOrSetVal
#
#   Purpose: Display and modify one internal variable
#
#   Inputs:  $key - variable name
#            $val - variable value; optional; variable will only be
#                queried, if $val is undef
#
#   Returns: List with variable name and current (probably modified)
#            value. $key is undef, if variable name was invalid.
#
############################################################################

sub GetOrSetVal ($;$) {
    my ($key, $val) = @_;

    if ($key =~ /^e(s(c(a(p(e(c(h(ar?)?)?)?)?)?)?)?)?$/i) {
	if (defined($val)) {
	    $escapeChar = $val;
	}
	$val = $escapeChar ? $escapeChar : "off";
	$key = "escapeChar";
    } elsif ($key =~ /^f(a(n(c(y(o(u(t(p(ut?)?)?)?)?)?)?)?)?)?$/i) {
	if (defined($val)) {
	    if ($val =~ /^on$/i) {
		$fancyOutput = 1;
	    } elsif ($val =~ /^off?$/i) {
		$fancyOutput = 0;
	    } else {
		$fancyOutput = $val ? 1 : 0;
	    }
	}
	$val = $fancyOutput ? "on" : "off";
	$key = "fancyOutput";
    } elsif ($key =~ /^l(e(ss?)?)?$/i) {
	if (defined($val)) {
	    if ($val  &&  $val ne 'stdout'  &&  ! -x $val) {
		print "No such executable: $val\n";
		print "Keeping old value.\n";
	    } else {
		$less = $val;
	    }
	}
	$val = ($less && $less ne 'stdout') ? $less : "off";
	$key = "less";
    } elsif ($key =~ /^maxc(o(l(u(m(n(l(e(n(g(th?)?)?)?)?)?)?)?)?)?)?$/i) {
	if (defined($val)) {
	    if ($val =~ /^\d+$/) {
		$maxColumnLength = $val;
	    } elsif ($val eq "off") {
		$maxColumnLength = 0;
	    } else {
		print "Illegal value for maxColumnLength: $val\n";
		print "Keeping old value.\n";
	    }
	}
	$val = $maxColumnLength ? $maxColumnLength : "off";
	$key = "maxColumnLength";
    } elsif ($key =~ /^maxr(o(ws?)?)?$/i) {
	if (defined($val)) {
	    if ($val =~ /^\d+$/) {
		$maxRows = $val;
	    } elsif ($val eq "off") {
		$maxRows = 0;
	    } else {
		print "Illegal value for maxRows: $val\n";
		print "Keeping old value.\n";
	    }
	}
	$val = $maxRows ? $maxRows : "off";
	$key = "maxRows";
    } elsif ($key =~ /q(u(o(t(e(c(h(ar?)?)?)?)?)?)?)?/) {
	if (defined($val)) {
	    $quoteChar = $val;
	}
	$val = $quoteChar ? $quoteChar : "off";
	$key = "quoteChar";
    } elsif ($key =~ /s(e(p(c(h(ar?)?)?)?)?)?/i) {
	if (defined($val)) {
	    $sepChar = $val;
	}
	$val = $sepChar ? $sepChar : "off";
	$key = "sepChar";
    } else {
	$key = undef;
    }

    ($key, $val);
}


############################################################################
#
#   Name:    Set
#
#   Purpose: Display and modify internal variables
#
#   Inputs:  @args - command line arguments
#
#   Returns: Nothing
#
############################################################################

sub Set (@) {
    if (!@_) {
	# Display complete list of arguments
	printf("Current settings:\n" .
	       "         fancyOutput: %s\n", (GetOrSetVal("fancyOutput"))[1]);
	if ($fancyOutput) {
	    my @keys = @VALID_VARS;
	    my $key;
	    shift @keys; # 'fancy' already printed

	    foreach $key (@keys) {
		printf("     %15s: %s\n", $key, (GetOrSetVal($key))[1]);
	    }
	}
    } elsif (@_ == 1  ||  @_ == 2) {
	my($key, $val) = @_;
	($key, $val) = GetOrSetVal($key, $val);
	if (!defined($key)) {
	    printf("Unknown variable: %s.\n", $key);
	} else {
	    printf("Current value of %s: %s\n", $key, $val);
	}
    } else {
	print "Usage: set [<var> [<val]]\n";
    }
}


############################################################################
#
#   Name:    Complete
#
#   Purpose: Simple completion function for ReadLine
#
#   Inputs:  $word - word to complete
#            $line - line to complete
#            $pos - ?
#
#   Returns: Word to complete
#
############################################################################

sub complete_database ($) {
    my $word = shift;
    grep /^(.*\:)\Q$word/, DsnList();
}

sub complete_table ($$) {
    my($word,$line) = @_;
    my($rdsn) = $line =~ /^r\w+\s+(\w+)/;
    if ($debugging) {
	print STDERR "word[$word] line[$line] dsn[$rdsn]\n";
    }
    $rdsn ||= $dsn;
    if (!$rdsn) {
	return ();
    }
    grep /^\Q$word/, TableList($dsn);
}

sub complete_table_or_field {
    my($word,$line) = @_;
    my(@result) = ();
    if ($debugging){
	print STDERR "word[$word] line[$line]\n";
    }
    if ($line =~ /(delete|select)\s.*from\s+\Q$word\E$/i  ||
	$line =~ /^update\s+\Q$word\E$/i ||
	$line =~ /^insert\s.*into\s+\Q$word\E$/i) {
	@result = grep /^\Q$word/, TableList($dsn);
    } elsif ($line =~ /^delete\s.*\sfrom\s+(\w+)/i  ||
	     $line =~ /^select\s.*\sfrom\s+(\w+)/i  ||
	     $line =~ /^update\s+(\w+)/i            ||
	     $line =~ /^insert\s.*into\s+(\w+)/i) {
	my $table = $1;
	if ($table) {
	    my $sth = FieldList($dsn, $table);
	    if ($sth) {
		my $names = $sth->{'NAME'};
		if (ref($names) eq 'ARRAY') {
		    @result = grep /^\Q$word/, @$names;
		}
	    }
	}
    }
    @result;
}

sub complete_for_relshow ($$) {
    my($word, $line) = @_;
    my @t = split(' ', $line);
    if (@t == 1  ||  @t == 2  &&  $word eq $t[1]) {
	complete_database($word);
    } else {
	complete_table($word, $line);
    }
}

sub complete_for_set ($$) {
    my($word, $line) = @_;
    my @t = split(' ', $line);
    if (@t == 1  ||  @t == 2  &&  $word eq $t[1]) {
	grep /^\Q$word/, @VALID_VARS;
    } else {
	();
    }
}

sub Complete () {
    my($word, $line, $pos) = @_;
    $word ||= '';
    $line ||= '';
    $pos ||= 0;
    if ($debugging) {
	print STDERR "complete line[$line] word[$word] pos[$pos]\n";
    }

    # Remove preceding white space
    $line =~ s/^\s*//;

    if ($pos == 0) {
	grep /^$word/i, ('!', '?', 'delete from', 'dsn', 'insert into',
			 'quit', 'relshow', 'select', 'set', 'update');
    } elsif ($line =~ /^dsn?/i) {
	complete_database($word);
    } elsif ($line =~ /^de(l(e(te?)?)?)?/i) {
	complete_table_or_field($word,$line);
    } elsif ($line =~ /^i(n(s(e(rt?)?)?)?)?/i) {
	complete_table_or_field($word,$line);
    } elsif ($line =~ /^r(e(l(s(h(ow?)?)?)?)?)?/i) {
	complete_for_relshow($word,$line);
    } elsif ($line =~ /^sel(e(ct?)?)?/i) {
	complete_table_or_field($word,$line);
    } elsif ($line =~ /^set/i) {
	complete_for_set($word, $line);
    } elsif ($line =~ /^u(p(d(a(te?)?)?)?)?/i) {
	complete_table_or_field($word,$line);
    } else {
	();
    }
}

sub CompleteGnu (@) {
    my(@poss) = Complete(@_);
    $term->Attribs->{'completion_word'} = \@poss;
}


############################################################################
#
#   Name:    Quit
#
#   Purpose: Programs destructor
#
#   Inputs:  None
#
#   Returns: Nothing.
#
############################################################################

sub Quit () {
    if (defined($dbh)) {
	$dbh->disconnect;
	$dbh = undef;
    }
}
END { Quit(); }


############################################################################
#
#   Name:    Help
#
#   Purpose: Print help message
#
#   Inputs:  None
#
#   Returns: Nothing.
#
############################################################################

sub Help () {
    print qq{
d[sn] <dsn>                  Disconnect from current dsn and connect to <dsn>
r[elshow] [<dsn> [<table>]]  Display list of dsn´s, tables, fields.
s[et] [<var> [<val>]]        Display or set values of internal variables.
! <anything>                 Eval <anything> in perl
?                            Print this message
q[uit]                       Leave dbimon

Any other line will be passed as a query to the DMBS.
};
}


############################################################################
#
#   Name:    Usage
#
#   Purpose: Print usage message
#
#   Inputs:  None
#
#   Returns: Nothing, exits with error status
#
############################################################################

sub Usage () {
    print STDERR qq{
Usage: $0 [options] dsn [user [password]]

Possible options are:
    -h | -help | --help     Print this message
    -b | -batch | --batch   Batch mode

dbimon $VERSION Copyright (C) 1997 Jochen Wiedmann
};
    exit 1;
}


############################################################################
#
#   This is main().
#
############################################################################

{
    my ($arg);
    my ($dsn, $user, $password);

    #   Initialize $less
    {
	my @path = split ":", $ENV{PATH};
	if (exists($ENV{DBIMON_PAGER})) {
	    $less = $ENV{DBIMON_PAGER};
	} elsif (exists($ENV{PAGER})) {
	    $less = $ENV{PAGER};
	} elsif (!defined($less = FindExe("less", [@path]))  &&
		 !defined($less = FindExe("more", [@path]))) {
	    $less = '';
	}
    }

    while (defined($arg = shift @ARGV)) {
	if ($arg eq "-h"  ||  $arg eq "-help"  ||  $arg eq "--help") {
	    Usage();
	} elsif ($arg eq "-b"  ||  $arg eq "-batch"  ||  $arg eq "--batch") {
	    $batchMode = 1;
	} elsif ($arg eq "-d"  ||  $arg eq "-debug"  ||  $arg eq "--debug") {
	    $debugging = 1;
	} else {
	    if (!defined($dsn)) {
		$dsn = $arg;
	    } elsif (!defined($user)) {
		$user = $arg;
	    } elsif (!defined($password)) {
		$password = $arg;
	    } else {
		Usage();
	    }
	}
    }
    if (!defined($dsn)) {
	Usage();
    }

    if (!($dbh = Connect($dsn, $user, $password))) {
	print STDERR "Cannot connect: $DBI::errstr\n";
	exit 1;
    }	

    if (!$batchMode) {
	$term = Term::ReadLine->new("dbimon $VERSION");
	my ($rl_package) = $term->ReadLine;
	my ($rl_avail);
	if ($rl_package eq "Term::ReadLine::Gnu") {
	    my $attribs = $term->Attribs;
	    $attribs->{'attempted_completion_function'} = \&CompleteGnu;
	    $attribs->{'completion_entry_function'} =
		$attribs->{'list_completion_function'};
	    $rl_avail = 'enabled';
	} else {
	    $readline::rl_completion_function = 'main::Complete';
	    if ($rl_package eq 'Term::ReadLine::Perl'  ||
		$rl_package eq 'Term::ReadLine::readline_pl') {
		$rl_avail = 'enabled';
	    } else {
		$rl_avail = "available (get Term::ReadKey and"
		  . " Term::ReadLine::[Perl|GNU])";
	}

	my $serverinfo = eval { $dbh->func('getserverinfo'); };
	if (!defined($serverinfo)  ||  !$@) {
	    $serverinfo = 'No server information available';
	}
	print("DBImon $VERSION - the interactive DBI monitor\n",
	      "Copyright (C) 1997, Jochen Wiedmann\n",
	      "$serverinfo\n",
	      "Readline support $rl_avail\n\n");
    }

    # Main loop
    my $line;
    while ($batchMode ? defined($line = <STDIN>) :
	                defined($line = $term->readline("dbimon> "))) {
	# Remove preceding and trailing blanks, ignore empty lines
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	if ($line =~ /^$/) {
	    next;
	}

	# Handle Perl evaluation
	if ($line =~ /^\!/) {
	    my $command = $';
	    $command =~ s/^\s+//;
	    if ($command !~ /^$/) {
		if (!$batchMode) {
		    $term->addhistory($command);
		}
		# Disable warnings
		$^W = 0; eval $command;
		if ($@) {
		    warn $@;
		}
		$^W = 1;
		print "\n";
	    }
	    next;
	}

	# Help mode
	if ($line =~ /^\?/) {
	    Help();
	    next;
	}

	# Perhaps this is a command?
	my ($command, @args) = split(' ', $line);
	if (!defined($command)) {
	    next;
	}

	if ($command =~ /^d(sn?)?$/i) {
	    if (@args) {
		my $ndbh;
		if (!($ndbh = Connect(@args))) {
		    print "Cannot connect: $DBI::errstr\n";
		} else {
		    $dbh->disconnect;
		    $dbh = $ndbh;
		}
	    }
	    print "Current DSN is: $dsn\n";
	} elsif ($command =~ /^q(u(it?)?)?$/i) {
	    if (!$batchMode) {
		print "Goodbye\n";
	    }
	    last;
	} elsif ($command =~ /^r(e(l(s(h(ow?)?)?)?)?)?$/i) {
	    if (@args > 2) {
		print "Usage: relshow [<dsn> [<table>]]\n";
	    } else {
		my ($dsn, $table) = @args;
		RelShow($dsn, $table);
	    }
	} elsif ($command =~ /^s(et?)?$/i) {
	    if (@args > 2) {
		print "Usage: set [<var> [<val>]]\n";
	    } else {
		my ($key, $val) = @args;
		Set(@args);
	    }
	} else {
	    # This is a query
	    $line =~ s/(\\[qgp]|\;)$//;

	    my $sth = $dbh->prepare($line);
	    if (!defined($sth)) {
		printf("Prepare error: %s\n", $dbh->errstr);
		next;
	    }
	    my $rows = $sth->execute;
	    if (!$rows) {
		printf("Execute error: %s\n", $dbh->errstr);
		next;
	    }
	    if ($sth->{'NUM_OF_FIELDS'} == 0) {
		if (!$batchMode) {
		    if ($rows != -1) {
			print "Query affected $rows rows.\n";
		    } else {
			print "Query affected unknown number of rows.\n";
		    }
		}
		next;  # Query with no result
	    }

	    # Now for the hard part: Create a table output
	    Output($sth);
	}
    }

    exit 0;
}


__END__

=pod

=head1 NAME

dbimon - interactive shell with readline for DBI

=head1 SYNOPSIS

C<dbimon E<lt>dsnE<gt> [E<lt>userE<gt> [E<lt>passwordE<gt>]]>

=head1 DESCRIPTION

dbimon lets you talk to a running SQL server via the database independent
Perl interface DBI. dbimon was inspired by Andreas Koenig's pmsql and
borrows both design ideas and code from it. Thus the look and feel is
almost identical to pmsql, in particular the following holds:

=over 4

=item *

The output is formatted much in the same way as by the msql or mysql
monitor (see below), the msqlexport command and the relshow (mysqlshow)
program, which are coming with msql or mysql.

=item *

The additional capability is a connection to a readline interface (if
available) and a pipe to your favorite pager.

=item *

Additionally you may switch between hosts and databases within one session
and you don't have to type the nasty C<\g> or C<;> (a trailing C<\g>, C<\q>,
and C<\p> will be ignored).

=back

If a command starts with one of the following reserved words, it's
treated specially, otherwise it is passed on verbatim to the DBMS.
Output from the daemon is piped to your pager specified by either the
DBIMON_PAGER or the PAGER environment variable. If both are undefined,
the PATH is searched for either "less" or "more" and the first program
found is taken. If no pager can be determined or your pager
variable is empty or set to C<stdout>, the program writes to unfiltered
STDOUT.

=over 2

=item C<?>

print usage summary

=item C<dsn E<lt>dsnE<gt>

Connects to the given E<lt>dsnE<gt>, the old connection is closed.

=item C<q[uit]>

Leave dbimon.

=item C<re[lshow] [E<lt>dsnE<gt> [E<lt>tableE<gt>]]>

Without arguments this lists possible data sources by calling DBI's
I<data_sources> method. Data sources are driver dependent, the driver
of the last connection will be used. Unfortunately DBI offers no
possibilities of specifying a hostname or similar dsn attributes,
so you can hardly list a remote hosts dsns, for example.

If a C<dsn> is given, dbimon will connect to the given dsn and list
its tables. If both C<dsn> and C<table> are present, dbimon will list
the tables fields.

The latter possibilities are not supported by the DBI - these work
with private methods. Currently they are implemented for DBD::mSQL
and DBD::mysql.

=item C<se[t] [E<lt>varE<gt> [E<lt>valE<gt>]]

This command displays and modifies dbimon's internal variables.
Without arguments, all variables and their current settings are
listed. With a variable name only you query the variables value.
The two argument form modifies a variable. Supported variables
are:

=over 4

=item fancyOutput

This variable controls the look of SQL results. By default dbimon
creates fancy, formatted output with table borders. The alternative
is an output format which is well suited for exporting data to
other database systems.

=item less

This is the pager variable. You can turn off paging by setting this
to 'stdout'.

=item maxColumnLength

=item maxRows

If the DBI driver does not offer information about the column sizes
of a query result, dbimon will try to find these out. The first
I<maxRows> columns will be fetched and the output will be formatted
according to the maximum column sizes that dbimon found so far.
Columns will be truncated if they exceed I<maxColumnLength> characters.

If you want dbimon to use the complete result for determining maximum
column sizes, you can set I<maxRows> to 0. (Default are 100 rows.)
Likewise you can disable truncation by setting I<maxColumnLength> to
0. (Default are 1024 characters.)


=item escapeChar

=item quoteChar

=item sepChar

For non-fancy output dbimon will use these variables. Columns are
surrounded by the I<quoteChar>, separated by the I<sepChar> and
the I<escapeChar> is used for inserting these special characters.
The defaults are well suited for Excel (I<escapeChar> = C<">,
I<quoteChar> = C<"> and I<sepChar> = C<;>), thus a row with the
values 1, 'walrus' and 'Nat "King" Cole' will be displayed as

  "1";"walrus";"Nat ""King"" Cole"

=back

=item C<! EXPR>

Eval the EXPR in perl

=back

=head2 Completion

dbimon comes with some basic completion definitions that are far from
being perfect. Completion means, you can use the TAB character to run
some lookup routines on the current dsn or table and use the results
to save a few keystrokes.

The completion mechanism is very basic, and I'm not intending to
refine it in the near future. Feel free to implement your own
refinements and let me know, if you have something better than what we
have here.

=head1 DRIVER REQUIREMENTS

dbimon should in theory work with any DBI driver. However, DBI is too
restricted for really comfortable work. Thus I decided to use some
very basic possibilities of the DBD::mSQL and DBD::mysql drivers. It
should be easy to add these to any driver.

Anyways, all uses of the private methods is surrounded by eval's,
thus most things should work. And the program is still usable.

I'll be happy to drop these additional requirements as soon as the
DBI gets extended in an appropriate way and adopt my sources, but
for now, here's what I suggest:

=over 2

=item format_default_size

A statement handle attribute; reference to an array of values, one
for each column. The values contain the actual maximum size of all
values to be distinguished from the theroretical maximum. For example,
if you have a column of type char(64), but the values actually have 30
characters or less, then the value 30 will be supplied by the driver.

The driver is free, not to implement this attribute or to implement
it only for certain columns, but he must supply C<undef> for other
values.

DBD::mysql implements this by reading the max_length attribute of
a result. DBD::mSQL does not offer such an attribute, but it holds
the complete result in memory, so I could easily add the attribute
by scanning all rows. (Perhaps faster than relying on dbimons builtin
possibility.)

=item format_max_size

Similar to I<format_default_size>, but this is the theoretical maximum
size. Again, the driver is free not to implement this attribute or
implement it for certain columns only, but he must supply C<undef>
for all other columns.

=item format_right_justify

Again, a statement handles attribute, reference to an array. It tells
dbimon what kind of justification to use for a column. DBD::mSQL and
DBD::mysql simply map this to IS_NUM. The driver should implement
this attribute.

=item format_type_name

Reference to an array of type names; for example DBD::mSQL will insert
the type name C<int> for a column of type I<INT_TYPE>. The driver
should implement this attribute.

=item C<@list = $dbh-E<gt>func("_ListTables")>

Lists the tables of the dsn corresponding to I<$dbh>.

=item C<$sth = $dbh-E<gt>func($table, "_ListFields")>

Returns a statement handle describing the fields of a table. This could,
for example, be implemented by a

  SELECT * FROM table WHERE column <> column

if you only know a column name. (Of course I can imagine better
solutions ... :-)

=back

=head1 SEE ALSO

You need a readline package installed to get the advantage of a
readline interface. If you don't have it, you won't be able to use the
arrow keys in a meaningful manner. Term::ReadKey and Term::ReadLine do
not come with the perl distribution but are available from CPAN (see
http://www.perl.com/CPAN).

See L<pmsql (1)>, L<DBI (3)>, L<Term::ReadKey (3)>, L<Term::ReadLine (3)>,

=cut

!NO!SUBS!

#
# End of dbimon
#

close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
