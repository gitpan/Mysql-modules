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
# Start of pmysql
#

print OUT <<"!GROK!THIS!";
$Config{'startperl'}
!GROK!THIS!

print OUT <<'!NO!SUBS!';

# $Id: pmysql.PL,v 1.2 1997/08/27 22:13:16 joe Exp $
my $version = substr q$Revision: 1.2 $, 10;

BEGIN {require 5.002;}
# use strict;      # only for testing. Unfriendly for the user-eval()s
# $^W = 1;         # too early for readline 0.8
use Mysql ();
use Term::ReadLine;
use Carp ();

# term

my $term = new Term::ReadLine 'MysqlPerl Monitor';

# prompt

my $prompt = "pmysql> ";
$readline::rl_completion_function = 'main::complete';

$^W = 1;
# $SIG{'__WARN__'} = sub { warn Carp::longmess(@_); };

# typelabels

my(@typelabel);
@typelabel[
	   Mysql::FIELD_TYPE_BLOB(),
	   Mysql::FIELD_TYPE_CHAR(),
	   Mysql::FIELD_TYPE_DECIMAL(),
	   Mysql::FIELD_TYPE_DATE(),
	   Mysql::FIELD_TYPE_DATETIME(),
	   Mysql::FIELD_TYPE_DOUBLE(),
	   Mysql::FIELD_TYPE_FLOAT(),
	   Mysql::FIELD_TYPE_INT24(),
	   Mysql::FIELD_TYPE_LONGLONG(),
	   Mysql::FIELD_TYPE_LONG_BLOB(),
	   Mysql::FIELD_TYPE_LONG(),
	   Mysql::FIELD_TYPE_NULL(),
	   Mysql::FIELD_TYPE_SHORT(),
	   Mysql::FIELD_TYPE_STRING(),
	   Mysql::FIELD_TYPE_TINY_BLOB(),
	   Mysql::FIELD_TYPE_TIMESTAMP(),
	   Mysql::FIELD_TYPE_TIME(),
	   Mysql::FIELD_TYPE_VAR_STRING()
	  ] = qw(
		 blob,
		 char,
		 decimal,
		 date,
		 datetime,
		 double,
		 float,
		 int24,
		 longlong,
		 longblob,
		 long,
		 null,
		 short,
		 string,
		 tinyblob,
		 timestamp,
		 time,
		 varstring
		);

# host

my $host = "";
if (@ARGV && $ARGV[0] eq "-h") {
    shift;
    $host = shift or die usage();
}

# Less

my $Less;
{
    my @path = split ":", $ENV{PATH};
    $Less = $ENV{PMYSQL_PAGER} || $ENV{PAGER} || find_exe("less",[@path]) ||
                find_exe("more",[@path]) || "";
}

# database

my $database = $ARGV[0];
$database ||= "";

#
# Greetings
#

{
    my $rl_avail = defined &Term::ReadLine::Perl::readline ? "enabled" : "available (get Term::ReadKey and Term::ReadLine::Perl)";

    print qq{
pmysql -- interactive mSQL monitor version $version
Readline support $rl_avail

};
}

#
# Debugging
#

my %Debug;
#table          1
#complete       2
#table_or_field 4
my $Debug = 0; # 1 | 2 | 4;


#
# Shell
#

while ( defined ($_ = $term->readline($prompt)) ) {

    #
    # Leading blanks? No
    #

    s/^\s+//;
    next if /^$/;

    #
    # Let them eval a piece of perl
    #

    if (/^\!/) {
	$term->addhistory($_) if /\S/;
	s/^\!//;
	eval($_);
	warn $@ if $@;
	print "\n";
	next;

    #
    # Give some advice
    #

    } elsif (/^\?/) {
	my($indexarg) = &Mysql::IDX_TYPE ? " [index]" : "";
	my($indexdes) = &Mysql::IDX_TYPE ? ", tables or indices" : " or tables";
	print qq{
ho[st] <host>                        Set default host (current is "$host")
da[tabase] <database>                Set default database (current is "$database")
re[lshow] [-h host] [database] [table]$indexarg
                                     describe databases$indexdes
                                           and set default host and database
! <anything>                         eval string in perl
?                                    print this message
q[uit]                               leave pmysql
<anything else>                      query default database on default host

};
	next;
    }

    #
    # Look closer what they said
    #

    my($command,$arg) = /^(\S+)(.*)/;
    my(@arg) = split " ", $arg;
    next unless defined $command;

    if ($command =~ /^ho(s(t)?)?$/i) {

	# HOST

	$host = $arg[0];
	print qq{Host set to "$host"\n};
    } elsif ($command =~ /^da(t(a(b(a(s(e)?)?)?)?)?)?$/i) {

	# DATABASE

	$database = $arg[0] if $arg[0] gt "";
	print qq{Database set to "$database"\n};
    } elsif ($command =~ /^re(l(s(h(o(w)?)?)?)?)?$/i) {

	# RELSHOW

	print relshow(@arg);
    } elsif ($command =~ /^q(u(i(t)?)?)?$/i) {

	# QUIT

	print "Goodbye\n";
	last;
    } else {

	# This is a query

	unless ($database) {
	    print "No default database defined\n";
	    next;
	}
	my $Db = Mysql->connect($host,$database) or next;
	s/\\[qgp]$//;
	$::Q = $Db->query($_) or next;
	print "Query ok\n";
	if (ref $::Q) {
	    $::Q->optimize(1);
	    if ($Less) {
		open OUT, "| $Less";
	    } else {
		open OUT, ">&STDOUT";
	    }
	    print OUT $::Q->as_string;
	    close OUT;
	}
    }
}

exit;

#
# Subroutines
#

sub complete {
    my($word,$line,$pos) = @_;
    $word ||= "";
    $line ||= "";
    $pos ||= 0;
    print STDERR "complete line[$line] pos[$pos]" if $Debug & 2;
    $line =~ s/^\s*//;
    return
	$pos == 0 ? grep /^$word/i, ('!','?','create','database','delete from','drop table','host','insert into','quit','relshow','select','update') :
	$line =~ /^[\!\?qch]/i ? () :                                  # quit, create, host
	$line =~ /^da/i ? complete_database($word) :		       # database
	$line =~ /^de/i ? complete_table_or_field($word,$line) :       # delete
	$line =~ /^dr/i ? complete_table($word,$line) :		       # drop
	$line =~ /^in/i ? complete_table_or_field($word,$line) :       # insert
	$line =~ /^re/i ? complete_for_relshow($word,$line) :          # relshow
	$line =~ /^se/i ? complete_table_or_field($word,$line) :       # select
	$line =~ /^up/i ? complete_table_or_field($word,$line) : ();   # update
}

sub complete_database {
    my($word) = shift;
    grep /^\Q$word/, Mysql->connect($host)->listdbs;
}

sub complete_for_relshow {
    my($word,$line) = @_;
    my @t = split " ", $line;
#    system '/usr/sbin/sfplay', '/usr/adm/alarmsnd/woodblock.aiff';
#    @::Gl = ([@t]);
    if (@t==4 && $word eq $t[3] || @t==3 && $word eq "") {
	my $sth = Mysql->connect($host, $t[1])->listfields($t[2]);
	my(@idx) = $sth->listindices;
	my(@fitidx) = grep /^\Q$word/, @idx;
#	push @::Gl, $sth, [@idx], [@fitidx]; # for debugging only
	return @fitidx;
    } else {
	complete_table_or_field($word,$line);
    }
}

sub complete_table {
    my($word,$line) = @_;
    my($db) = $line =~ /^r\w+\s+(\w+)/;
    print STDERR "word[$word] line[$line] db[$db]" if $Debug & 1;
    $db ||= $database;
    return () unless $db;
    grep /^\Q$word/, Mysql->connect($host, $db)->listtables;
}

sub complete_table_or_field {
    my($word,$line) = @_;
    print STDERR "word[$word] line[$line]" if $Debug & 4;
    return complete_database($word) if $line =~ /^r\w+\s+\Q$word\E$/;
    return complete_table($word,$line) if
	$line =~ /^[ds].*\sfrom\s+\Q$word\E$/ ||	# delete, select
	$line =~ /^u\w+\s+\Q$word\E$/ || # update
	$line =~ /^r\w+\s+\w+\s+\Q$word\E$/ || # relshow
	$line =~ /^i.*\sinto\s+\Q$word\E$/ # insert
	    ;
    return () unless $database;
    my ($table) = $1 if
	$line =~ /^[ds].*\sfrom\s+(\w+)/ ||	# delete, select
	$line =~ /^u\w+\s+(\w+)/ || # update
	$line =~ /^r\w+\s+\w+\s+(\w+)/ || # relshow
	$line =~ /^i.*\sinto\s+(\w+)/ # insert
	;
    my(@table) = $table ? $table : Mysql->connect($host, $database)->listtables;
    my($db,%fields,@fields) = Mysql->connect($host, $database);
    for $table (@table) {
	my $st = $db->listfields($table) or next;
	@fields = $st->name;
	@fields{@fields} = (1) x @fields;
    }
    return sort grep /^\Q$word/, keys %fields;
}

sub find_exe {
    my($exe,$path) = @_;
    my($dir);
    for $dir (@$path) {
        my $abs = "$dir/$exe";
        if (-x $abs) {
            return $abs;
        }
    }
}

sub longest {
    my $l = 0;
    for (@_) {
	$l=length if length > $l
    }
    $l;
}

sub relshow {
    if (@_ && $_[0] eq "-h") {
	shift @_;
	$host = shift @_ or die usage();
    }

    if (@_ > 2){
	if (&Mysql::IDX_TYPE) {
	    return "Usage: relshow [-h host] [database] [table] [index]\n" if @_ > 3;
	} else {
	    return "Usage: relshow [-h host] [database] [table]\n";
	}
    }

    my @m;

    push @m, "Host = $host\n" if $host;
    my $Dbh = Mysql->connect($host) or return;

    my($table,$bottok,$sorry,$i);

    if ($_[0]) {
	$database = shift @_;
	return "Couldn't connect to $database\n" unless $Dbh->selectdb($database);
	push @m, "\nDatabase   = $database\n";
	if ($table = shift @_) {
	    grep /^\Q$table\E$/, $Dbh->ListTables or return join "", @m, qq{Table "$table" not found\n};
	    my $sth = $Dbh->listfields($table) or return join "", @m, qq{Error reading listfields($table)\n};
	    push @m, qq{Table      = $table\n};

	    my $index;
	    if ($index = shift @_) {

		#
		# relshow database table index
		#

		return "Too many arguments to relshow\n"
			unless $Dbh->getserverinfo ge 2;
		#warn join ":", grep //, $sth->name;
		grep(/^\Q$index\E$/, $sth->name)
			or return join "", @m, qq{Index "$index" not found\n};
		push @m, qq{Index      = $index\n};
		my $idxhandle = $Dbh->listindex($table,$index)
			or return join "", @m,
				qq{Error reading listindex($table,$index)\n};
		my @row;
		@row = $idxhandle->fetchrow; # chop off avl or whatever
		push @m, qq{Index Type = $row[0]\n};
		my $border = " +" . ("-"x21) . "+\n";
		push @m, $border;
		push @m, sprintf " | %-19s |\n", "      Field";
		push @m, $border;
		while (@row = $idxhandle->fetchrow) {
		    push @m, sprintf " | %-19s |\n", $row[0];
		}
		push @m, $border;
		return join "", @m;
	    }

	    #
	    # relshow database table
	    #

	    my $fieldwidth = longest($sth->name,"Field") || 15;
	    my $keywidth = $Dbh->getserverinfo lt 2 ? 3 : 12;
	    my $keytitle = $Dbh->getserverinfo lt 2 ? "Key" : "Unique Index";
	    my $border = " +-".("-"x$fieldwidth)."-+-----------+--------+----------+-".("-"x$keywidth)."-+\n";
	    push @m, $border;
	    push @m, sprintf " | %-".$fieldwidth."s | Type      | Length | Not Null | %-".$keywidth."s |\n", "Field", $keytitle;
	    push @m, $border;
	    my $max = $sth->numfields;
	    for ($i=0;$i<$max;$i++){
		my $keyNO = $Dbh->getserverinfo lt 2 ? "N" :
		    $sth->type->[$i]==Mysql::IDX_TYPE() ? "N" : "N/A";
		push @m, sprintf " | %-".$fieldwidth."s | %-9s | %6s |    %-3s   | %-".$keywidth."s |\n",
			$sth->name->[$i],
			$typelabel[$sth->type->[$i]] || ("unknown-".$sth->type->[$i]),
			($sth->length->[$i] || "N/A"),
			$sth->is_not_null->[$i] ? " Y " : $sth->type->[$i]!=Mysql::IDX_TYPE() ? " N " : "N/A",
			$sth->is_pri_key->[$i] ? "Y" : $keyNO;
	    }
	    push @m, "$border\n";
	} else {
	    #
	    # relshow database
	    #

	    my @l = $Dbh->ListTables;
	    if (@l) {
		my $border = "  +---------------------+\n";
		push @m, qq{
$border  |       Table         |\n$border};
		my $elem;
		for $elem (@l) {
		    push @m, sprintf "  | %-19s |\n", $elem;
		}
		push @m, "$border\n";
	    } else {
		push @m, "No tables in database\n";
	    }
	}
    } else {
	#
	# relshow
	#

	my @l = $Dbh->ListDBs;
	if (@l) {
	    my $border = "  +------------------+\n";
	    push @m, qq{
$border  |    Databases     |\n$border} ;
	    my $elem;
	    for $elem (@l) {
		push @m, sprintf "  | %-16s |\n", $elem;
	    }
	    push @m, "$border\n";
	} else {
	    push @m, "No databases found\n";
	}
    }
    return join "", @m;
}

sub usage () {"Usage: $0 [-h host] database";}

__END__

=head1 NAME

pmysql - interactive shell with readline for msql

=head1 SYNOPSIS

C<pmysql [-h host] [database]>

=head1 DESCRIPTION

pmysql lets you talk to a running mysql daemon sending either SQL
queries or relshow commands. The output is formatted much in the same
way as by the msql monitor (see below) and the relshow program, which
are both coming with msql. The additional capability is a connection
to a readline interface (if available) and a pipe to your favorite
pager. Additionally you may switch between hosts and databases within
one session and you don't have to type the nasty C<\g> (a trailing
C<\g>, C<\q>, and C<\p> will be ignored).

If a command starts with one of the following reserved words, it's
treated specially, otherwise it is passed on verbatim to the mSQL
daemon. Output from the daemon is piped to your pager specified by
either the PMYSQL_PAGER or the PAGER environment variable. If both are
undefined, the PATH is searched for either "less" or "more" and the
first program found is taken. If no pager can be determined, the
program writes to unfiltered STDOUT.

=over 2

=item C<?>

print usage summary and current host and database

=item C<ho[st] host>

Set default host to "host"

=item C<da[tabase] database>

Set default database to "database"

=item C<re[lshow] [-h host] [database] [table] [index]>

Describe databases or tables in the same way as done by the relshow
program. If host or database are specified, the defaults are set to
these values. The prameter C<index> is only supported for mSQL-2.0.

=item C<! EXPR>

Eval the EXPR in perl

=item C<q[uit]>

Leave pymsql

=back

=head2 Global Variable

The global variable C<$Q> is used for the statement handle of the
current query. You can use this variable in eval statements.

There's no global variable for the database connection, because we
connect to the database for each command separately.

=head2 Completion

pmysql comes with some basic completion definitions that are far from
being perfect. Completion means, you can use the TAB character to run
some lookup routines on the current host or database and use the
results to save a few keystrokes.

The completion mechanism is very basic, and I'm not intending to
refine it in the near future. Feel free to implement your own
refinements and let me know, if you have something better than what we
have here.

=head1 BUGS

pmysql is not an mysql clone. If you use it as such for bulk uploads
into the database, you will notice an enourmous disadvantage in
performance. The reason is that pmysql intentionally disconnects from
the database after every query.

=head1 SEE ALSO

You need a readline package installed to get the advantage of a
readline interface. If you don't have it, you won't be able to use the
arrow keys in a meaningful manner. Term::ReadKey and Term::ReadLine do
not come with the perl distribution but are available from CPAN (see
http://www.perl.com/CPAN).

See Mysql, Term::ReadKey, Term::ReadLine.

=cut

!NO!SUBS!

#
# End of pmysql
#

close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
