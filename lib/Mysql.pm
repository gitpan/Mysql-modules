package Mysql;
BEGIN { require 5.002 }
# use vars qw($db_errstr); # 5.003
$db_errstr = $db_errstr = '';

require Mysql::Statement;
# use vars qw($VERSION $QUIET @ISA @EXPORT); # 5.003
$QUIET  = $QUIET  = '';
@ISA    = @ISA    = '';
@EXPORT = @EXPORT = '';
$VERSION = $VERSION = "1.1801";

# $Revision: 1.1.1.1 $$Date: 1997/08/27 10:32:15 $$RCSfile: Mysql.pm,v $

$QUIET = 0;

use Carp ();
use DynaLoader ();
use Exporter ();
@ISA = ('Exporter', 'DynaLoader');

# @EXPORT is a relict from old times...
@EXPORT = qw(
	     CHAR_TYPE
	     INT_TYPE
	     REAL_TYPE
	    );
@EXPORT_OK = qw(
		IDENT_TYPE
		NULL_TYPE
		TEXT_TYPE
		DATE_TYPE
		UINT_TYPE
		MONEY_TYPE
		TIME_TYPE
		IDX_TYPE
		SYSVAR_TYPE
	       );

sub host     { return shift->{'HOST'} }
sub sock     { return shift->{'SOCK'} }
sub sockfd   { return shift->{'SOCKFD'} }
sub database { return shift->{'DATABASE'} }

sub IDX_TYPE() { 0; }

sub quote	{
    my $self = shift;
    my $str = shift;
    return 'NULL' unless defined $str;
    my $trunc = shift;
    substr($str,$trunc) = '' if defined $trunc and $trunc > 0 and length($str) > $trunc;
    $str =~ s/([\\\'])/\\$1/g;
    $str =~ s/\0/\\0/g;
    "'$str'";
}

sub AUTOLOAD {
    my $meth = $AUTOLOAD;
    my $converted = 0;

    if ($meth =~ /(.*)::/) {
	$meth = $';
	$class = $1;
    } else {
	$class = "main";
    }


    TRY: {
	my $val = constant($meth, @_ ? $_[0] : 0);
	if ($! == 0) {
	    eval "sub $AUTOLOAD { $val }";
	    return $val;
	}

	if (!$converted) {
	    $meth =~ s/_//g;
	    $meth = lc($meth);
	    $converted = 1;
	}

	if (defined &$meth) {
	    *$meth = \&{$meth};
	    return &$meth(@_);
	} elsif ($meth =~ s/(.*)type$/uc($1)."_TYPE"/e) {
	    # Try to determine the type that was requested by
	    # translating inttype to INT_TYPE Not that I consider it
	    # good style to write inttype, but we once allowed it,
	    # so...
	    redo TRY;
	}
    }

  Carp::croak "$AUTOLOAD: Not defined in $class and not"
      . " autoloadable (last try $meth)";
}

bootstrap Mysql;

1;
__END__

=head1 NAME

Msql - Perl interface to the mSQL database

=head1 SYNOPSIS

  use Msql;
	
  $dbh = Msql->connect;
  $dbh = Msql->connect($host);
  $dbh = Msql->connect($host, $database);
	
  $dbh->selectdb($database);
	
  @arr = $dbh->listdbs;
  @arr = $dbh->listtables;
	
  $quoted_string = $dbh->quote($unquoted_string);
  $error_message = $dbh->errmsg;

  $sth = $dbh->listfields($table);
  $sth = $dbh->query($sql_statement);
	
  @arr = $sth->fetchrow;
  %hash = $sth->fetchhash;
	
  $sth->dataseek($row_number);

  $sth->as_string;

  @indices = $sth->listindices                   # only in mSQL 2.0
  @arr = $dbh->listindex($table,$index)          # only in mSQL 2.0
  ($step,$value) = $dbh->getsequenceinfo($table) # only in mSQL 2.0

=head1 DESCRIPTION

This package is designed as close as possible to its C API
counterpart. The manual that comes with mSQL describes most things you
need. Due to popular demand it was decided though, that this interface
does not use StudlyCaps (see below).

Internally you are dealing with the two classes C<Msql> and
C<Msql::Statement>. You will never see the latter, because you reach
it through a statement handle returned by a query or a listfields
statement. The only class you name explicitly is Msql. It offers you
the connect command:

  $dbh = Msql->connect;
  $dbh = Msql->connect($host);
  $dbh = Msql->connect($host, $database);

This connects you with the desired host/database. With no argument or
with an empty string as the first argument it connects to the UNIX
socket (usually /dev/msql), which has a much better performance than
the TCP counterpart. A database name as the second argument selects
the chosen database within the connection. The return value is a
database handle if the connect succeeds, otherwise the return value is
undef.

You will need this handle to gain further access to the database.

   $dbh->selectdb($database);

If you have not chosen a database with the C<connect> command, or if
you want to change the connection to a different database using a
database handle you have got from a previous C<connect>, then use
selectdb.

  $sth = $dbh->listfields($table);
  $sth = $dbh->query($sql_statement);

These two work rather similar as descibed in the mSQL manual. They
return a statement handle which lets you further explore what the
server has to tell you. On error the return value is undef. The object
returned by listfields will not know about the size of the table, so a
numrows() on it will return the string "N/A";

  @arr = $dbh->listdbs();
  @arr = $dbh->listtables;

An array is returned that contains the requested names without any
further information.

  @arr = $sth->fetchrow;

returns an array of the values of the next row fetched from the
server. Similar does

  %hash = $sth->fetchhash;

return a complete hash. The keys in this hash are the column names of
the table, the values are the table values. Be aware, that when you
have a table with two identical column names, you will not be able to
use this method without trashing one column. In such a case, you
should use the fetchrow method.

  $sth->dataseek($row_number);

lets you specify a certain offset of the data associated with the
statement handle. The next fetchrow will then return the appropriate
row (first row being 0).

=head2 No close statement

Whenever the scalar that holds a database or statement handle loses
its value, Msql chooses the appropriate action (frees the result or
closes the database connection). So if you want to free the result or
close the connection, choose to do one of the following:

=over 4

=item undef the handle

=item use the handle for another purpose

=item let the handle run out of scope

=item exit the program.

=back

=head2 Error messages

A static method in the Msql class is -E<gt>errmsg(), which returns the
current value of the msqlErrMsg variable that is provided by the C
API. There's also a global variable $Msql::db_errstr, which always
holds the last error message. The former is reset with the next
executed command, the latter not.

=head2 The C<-w> switch

With Msql the C<-w> switch is your friend! If you call your perl
program with the C<-w> switch you get the warnings from -E<gt>errmsg on
STDERR. This is a handy method to get the error messages from the msql
server without coding it into your program.

If you want to know in greater detail what's going on, set the
environment variables that are described in David's manual. David's
debugging aid is excellent, there's nothing to be added.

If you want to use the C<-w> switch but do not want to see the error
messages from the msql daemon, you can set the variable $Msql::QUIET
to some true value, and they will be supressed.

=head2 -E<gt>quote($str [, $length])

returns the argument enclosed in single ticks ('') with any special
character escaped according to the needs of the API. Currently this
means, any single tick within the string is escaped with a backslash
and backslashes are doubled. Currently (as of msql-1.0.16) the API
does not allow to insert binary nulls into tables. The quote method
does not fix this deficiency.

If you pass undefined values to the quote method, it returns the
string C<NULL>.

If a second parameter is passed to C<quote>, the result is truncated
to that many characters.

=head2 NULL fields

NULL fields in tables are returned to perl as undefined values.

=head2 Metadata

Now lets reconsider the above methods with regard to metadata.

=head2 Database Handle

As said above you get a database handle with

  $dbh = Msql->connect($host, $database);

The database handle knows about the socket, the host, and the database
it is connected to.

You get at the three values with the methods

  $scalar = $dbh->sock;
  $scalar = $dbh->host;
  $scalar = $dbh->database;

database returns undef, if you have connected without or with only one
argument.

=head2 Statement Handle

Two constructor methods return a statement handle:

  $sth = $dbh->listfields($table);
  $sth = $dbh->query($sql_statement);

$sth knows about all metadata that are provided by the API:

  $scalar = $sth->numrows;    
  $scalar = $sth->numfields;  

  @arr  = $sth->table;       the names of the tables of each column
  @arr  = $sth->name;        the names of the columns
  @arr  = $sth->type;        the type of each column, defined in msql.h
	                     and accessible via Msql::CHAR_TYPE,
	                     &Msql::INT_TYPE, &Msql::REAL_TYPE,
  @arr  = $sth->isnotnull;   array of boolean
  @arr  = $sth->isprikey;    array of boolean
  @arr  = $sth->length;      array of the length of each field in bytes

The six last methods return an array in array context and an array
reference (see L<perlref> and L<perlldsc> for details) when called in
a scalar context. The scalar context is useful, if you need only the
name of one column, e.g.

    $name_of_third_column = $sth->name->[2]

which is equivalent to

    @all_column_names = $sth->name;
    $name_of_third_column = $all_column_names[2];

=head2 New in mSQL 2.0

The query() function in the API returns the number of rows affected by
a query. To cite the mSQL API manual, this means...

  If the return code is greater than 0, not only does it imply
  success, it also indicates the number of rows "touched" by the query
  (i.e. the number of rows returned by a SELECT, the number of rows
  modified by an update, or the number of rows removed by a delete).

As we are returning a statement handle on selects, we can easily check
the number of rows returned. For non-selects we behave just the same
as mSQL-2.

To find all indices associated with a table you can call the
C<listindices()> method on a statement handle. To find out the columns
included in an index, you can call the C<listindex($table,$index)>
method on a database handle.

There are a few new column types in mSQL 2. You can access their
numeric value with these functions defined in the Msql package:
IDENT_TYPE, NULL_TYPE, TEXT_TYPE, DATE_TYPE, UINT_TYPE, MONEY_TYPE,
TIME_TYPE, IDX_TYPE, SYSVAR_TYPE.

You cannot talk to a 1.0 server with a 2.0 client.

You cannot link to a 1.0 library I<and> to a 2.0 library I<at the same
time>. So you may want to build two different Msql modules at a time,
one for 1.0, another for 2.0, and load whichever you need. Check out
what the C<-I> switch in perl is for.

Everything else seems to remain backwards compatible.

=head2 @EXPORT

For historical reasons the constants CHAR_TYPE, INT_TYPE, and
REAL_TYPE are in @EXPORT instead of @EXPORT_OK. This means, that you
always have them imported into your namespace. I consider it a bug,
but not such a serious one, that I intend to break old programs by
moving them into EXPORT_OK.

=head2 Connecting to different port(s) [only for mSQL-1.*.*]

The mSQL API allows you to interface to a different port than the
default that is compiled into your copy. To use this feature you have
to set the environment variable MSQL_TCP_PORT. You can do so at any
time in your program with the command

    $ENV{'MSQL_TCP_PORT'} = 1234; # or 1112 or 1113 or 4333 or 4334

Any subsequent connect() will establish a connection to the specified
port.

For connect()s to the UNIX socket of the local machine use
MSQL_UNIX_PORT instead.

=head2 Displaying whole tables in one go

A handy method to show the complete contents of a statement handle is
the as_string method. This works similar to the msql monitor with a
few exceptions:

=over 2

=item the width of a column

is calculated by examining the width of all entries in that column

=item control characters

are mapped into their backslashed octal representation

=item backslashes

are doubled (C<\\ instead of \>)

=item numeric values

are adjusted right (both integer and floating point values)

=back

The differences are illustrated by the following table:

Input to msql (a real carriage return here replaced with ^M):

    CREATE TABLE demo (
      first_field CHAR(10),
      second_field INT
    ) \g

    INSERT INTO demo VALUES ('new
    line',2)\g
    INSERT INTO demo VALUES ('back\\slash',1)\g
    INSERT INTO demo VALUES ('cr^Mcrnl
    nl',3)\g

Output of msql:

     +-------------+--------------+
     | first_field | second_field |
     +-------------+--------------+
     | new
    line    | 2            |
     | back\slash  | 1            |
    crnlr
    nl  | 3            |
     +-------------+--------------+

Output of pmsql:

    +----------------+------------+
    |first_field     |second_field|
    +----------------+------------+
    |new\012line     |           2|
    |back\\slash     |           1|
    |cr\015crnl\012nl|           3|
    +----------------+------------+


=head2 Version information

The version of MsqlPerl is always stored in $Msql::VERSION as it is
perl standard.

The mSQL API implements methods to access some internal configuration
parameters: gethostinfo, getserverinfo, and getprotoinfo.  All three
are available both as class methods or via a database handle. But
under no circumstances they are associated with a database handle. All
three return global variables that reflect the B<last> connect()
command within the current program. This means, that all three return
empty strings or zero I<before> the first call to connect().

=head2 Administration

shutdown, createdb, dropdb, reloadacls are all accessible via a
database handle and implement the corresponding methods to what
msqladmin does.

The mSQL engine does not permit that these commands are invoked by
other users than the administrator of the database. So please make sure
to check the return and error code when you issue one of them.

=head2 StudlyCaps

Real Perl Programmers (C) usually don't like to type I<ListTables> but
prefer I<list_tables> or I<listtables>. The mSQL API uses StudlyCaps
everywhere and so did early versions of MsqlPerl. Beginning with
$VERSION 1.06 all methods are internally in lowercase, but may be
written however you please. Case is ignored and you may use the
underline to improve readability.

The price for using different method names is neglectible. Any method
name you use that can be transformed into a known one, will only be
defined once within a program and will remain an alias until the
program terminates. So feel free to run fetch_row or connecT or
ListDBs as in your old programs. These, of course, will continue to
work.

=head1 PREREQUISITES

mSQL is a database server and an API library written by David
Hughes. To use the adaptor you definitely have to install these first.

=head1 AUTHOR

andreas koenig C<koenig@franz.ww.TU-Berlin.DE>

=head1 SEE ALSO

Alligator Descartes wrote a database driver for Tim Bunce's DBI. I
recommend anybody to carefully watch the development of this module
(C<DBD::mSQL>). Msql is a simple, stable, and fast module, and it will
be supported for a long time. But it's a dead end. I expect in the
medium term, that the DBI efforts result in a richer module family
with better support and more functionality. Alligator maintains an
interesting page on the DBI development: http://www.hermetica.com/

=cut

