#   Our beloved Emacs will give us -*- perl -*- mode :-)
#
#   $Id: mysql.pm 1.1 Tue, 30 Sep 1997 01:28:08 +0200 joe $
#
#   Copyright (c) 1994,1995,1996,1997 Alligator Descartes, Tim Bunce
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

package DBD::mysql;
use strict;
use vars qw(@ISA $VERSION $err $errstr $drh);

use DBI ();
use DynaLoader();
use Carp ();
@ISA = qw(DynaLoader);

$VERSION = "2.004";

bootstrap DBD::mysql $VERSION;


$err = 0;	# holds error code   for DBI::err
$errstr = "";	# holds error string for DBI::errstr
$drh = undef;	# holds driver handle once initialised

sub driver{
    return $drh if $drh;
    my($class, $attr) = @_;

    $class .= "::dr";

    # not a 'my' since we use it above to prevent multiple drivers
    $drh = DBI::_new_drh($class, { 'Name' => 'mysql',
				   'Version' => $VERSION,
				   'Err'    => \$DBD::mysql::err,
				   'Errstr' => \$DBD::mysql::errstr,
				   'Attribution' => 'DBD::mysql by Jochen Wiedmann'
				 });

    $drh;
}

1;



package DBD::mysql::dr; # ====== DRIVER ======
use strict;

sub connect {
    my($drh, $dsn, $username, $password, $attrhash) = @_;
    my($port);
    my($cWarn);

    # Avoid warnings for undefined values
    $username ||= '';
    $password ||= '';

    $cWarn = 0;

    #
    # Backwards compatibility until October 1997 or so; note that
    # this is valid for mSQL only: mysql needs a user name
    #
    if ($username ne "" && $drh->{'Name'} =~ /msql/i) {
	# somebody tried to run connect("host:port", "db")
	$dsn = "$username:$dsn";
	$cWarn = 1;
    }

    #
    # Check if dsn contains a host definition
    #
    if (defined($attrhash)) {
	my $hostname;
	if (ref($attrhash)  &&  ref($attrhash) eq 'HASH') {
	    if (defined($hostname = $attrhash->{'hostname'})) {
		$dsn = "$dsn:hostname=$hostname";
		$cWarn = 1;
	    }
	}
    }

    if ($cWarn  &&  (!defined$DBD::mysql::QUIET  ||  !$DBD::mysql::QUIET)) {
        Carp::carp("Please switch to the new connect method documenteded"
		   . " in DBI 0.84:\n"
		   . "  \$dbh = DBI->connect(\$dsn). \n"
		   . "We now emulate the call\n"
		   . "  \$drh->connect('$dsn'),\n"
		   . "but this exception will go away soon.\n");
    }


      
    # create a 'blank' dbh
    my $this;

    if (!defined($this = DBI::_new_dbh($drh, { 'dsn' => $dsn,
					       'user' => $username
                                             }))) {
	return undef;
    }

    # Call msqlConnect func in mSQL.xs file
    # and populate internal handle data.
    DBD::mysql::db::_login($this, $dsn, $username, $password)
	  or $this = undef;
    $this;
}

sub data_sources {
    my($self) = shift;
    my(@dsn) = $self->func('', '_ListDBs');
    my($i);
    for ($i = 0;  $i < @dsn;  $i++) {
	$dsn[$i] = "DBI:mysql:$dsn[$i]";
    }
    @dsn;
}


package DBD::mysql::db; # ====== DATABASE ======
use strict;

%DBD::mysql::db::db2ANSI = ("INT"   =>  "INTEGER",
			   "CHAR"  =>  "CHAR",
			   "REAL"  =>  "REAL",
			   "IDENT" =>  "DECIMAL"
                          );

### ANSI datatype mapping to mSQL datatypes
%DBD::mysql::db::ANSI2db = ("CHAR"          => "CHAR",
			   "VARCHAR"       => "CHAR",
			   "LONGVARCHAR"   => "CHAR",
			   "NUMERIC"       => "INTEGER",
			   "DECIMAL"       => "INTEGER",
			   "BIT"           => "INTEGER",
			   "TINYINT"       => "INTEGER",
			   "SMALLINT"      => "INTEGER",
			   "INTEGER"       => "INTEGER",
			   "BIGINT"        => "INTEGER",
			   "REAL"          => "REAL",
			   "FLOAT"         => "REAL",
			   "DOUBLE"        => "REAL",
			   "BINARY"        => "CHAR",
			   "VARBINARY"     => "CHAR",
			   "LONGVARBINARY" => "CHAR",
			   "DATE"          => "CHAR",
			   "TIME"          => "CHAR",
			   "TIMESTAMP"     => "CHAR"
			  );

sub prepare {
    my($dbh, $statement)= @_;

    # create a 'blank' dbh
    my $sth = DBI::_new_sth($dbh, {
	'Statement' => $statement,
    });

    # Populate internal handle data.
    if (!DBD::mysql::st::_prepare($sth, $statement)) {
	$sth = undef;
    }

    $sth;
}

sub db2ANSI {
    my $self = shift;
    my $type = shift;
    return $DBD::mysql::db::db2ANSI{"$type"};
}

sub ANSI2db {
    my $self = shift;
    my $type = shift;
    return $DBD::mysql::db::ANSI2db{"$type"};
}

sub quote {
    my ($self, $str) = @_;
    if (!defined($str)) { return 'NULL'; }
    $str =~ s/([\0\\\'])/\\$1/g;
    "'$str'";
}

# Just a stub for backward compatibility; use is deprecated
sub _ListFields($$) {
    my ($self, $table) = @_;
    my ($sth);
    if (!($sth = $self->prepare("LISTFIELDS $table"))) {
	return undef;
    }
    if (!$sth->execute) {
	return undef;
    }
    $sth;
}

package DBD::mysql::st; # ====== STATEMENT ======
use strict;

# Just a stub for backward compatibility; use is deprecated
sub _ListSelectedFields ($) {
    shift;
}

1;


__END__

=head1 NAME

DBD::mSQL / DBD::mysql - mSQL and mysql drivers for the Perl5 Database
Interface (DBI)

=head1 SYNOPSIS

    use DBI;

    $dbh = DBI->connect("DBI:mSQL:$database:$hostname:$port",
			undef, undef);

        or

    $dbh = DBI->connect("DBI:mysql:$database:$hostname:$port",
			$user, $password);

    @databases = DBD::mysql::dr->func( $hostname, '_ListDBs' );
    @tables = $dbh->func( '_ListTables' );

    $sth = $dbh->prepare("LISTFIELDS $table");
    $sth->execute;
    $sth->finish;

    $sth = $dbh->prepare("SELECT * FROM foo WHERE bla");
    $sth->execute;
    $numRows = $sth->rows;
    $numFields = $sth->{'NUM_OF_FIELDS'};
    $sth->finish;

    $rc = $drh->func( $database, '_CreateDB' );
    $rc = $drh->func( $database, '_DropDB' );


=head1 DESCRIPTION

<DBD::mysql> and <DBD::mSQL> are the Perl5 Database Interface drivers for
the mysql, mSQL 1.I<x> and mSQL 2.I<x> databases. The drivers are part
of the I<mysql-modules> and I<Msql-modules> packages, respectively.


=head2 Class Methods

=over 4

=item B<connect>

    use DBI;

    $dbh = DBI->connect("DBI:mSQL:$database", undef, undef);
    $dbh = DBI->connect("DBI:mSQL:$database:$hostname", undef, undef);
    $dbh = DBI->connect("DBI:mSQL:$database:$hostname:$port",
			undef, undef);

        or

    use DBI;

    $dbh = DBI->connect("DBI:mysql:$database", $user, $password);
    $dbh = DBI->connect("DBI:mysql:$database:$hostname",
			$user, $password);
    $dbh = DBI->connect("DBI:mysql:$database:$hostname:$port",
			$user, $password);

A C<database> must always be specified.

The hostname, if not specified or specified as '', will default to an
mysql or mSQL daemon running on the local machine on the default port
for the UNIX socket.

Should the mysql or mSQL daemon be running on a non-standard port number,
you may explicitly state the port number to connect to in the C<hostname>
argument, by concatenating the I<hostname> and I<port number> together
separated by a colon ( C<:> ) character.

=back

=head2 Private MetaData Methods

=over 4

=item B<ListDBs>

    @dbs = $dbh->func("$hostname:$port", '_ListDBs');

Returns a list of all databases managed by the mysql daemon or
mSQL daemon running on C<$hostname>, port C<$port>. This method
is rarely needed for databases running on C<localhost>: You should
use the portable method

    @dbs = DBI->data_sources("mysql");

        or

    @dbs = DBI->data_sources("mSQL");

whenever possible. It is a design problem of this method, that there's
no way of supplying a host name or port number to C<data_sources>, that's
the only reason why we still support C<ListDBs>. :-(


=item B<ListTables>

    @tables = $dbh->func('_ListTables');

Once connected to the desired database on the desired mysql or mSQL
mSQL daemon with the C<DBI->connect()> method, we may extract a list
of the tables that have been created within that database.

C<ListTables> returns an array containing the names of all the tables
present within the selected database. If no tables have been created,
an empty list is returned.

    @tables = $dbh->func( '_ListTables' );
    foreach $table ( @tables ) {
        print "Table: $table\n";
      }


=item B<ListFields>

Deprecated, see L</COMPATIBILITY ALERT> below.

=item B<ListSelectedFields>

Deprecated, see L</COMPATIBILITY ALERT> below.

=back


=head2 Database Manipulation

=over 4

=item B<CreateDB>

=item B<DropDB>

    $rc = $drh->func( $database, '_CreateDB' );
    $rc = $drh->func( $database, '_DropDB' );

These two methods allow programmers to create and drop databases from
DBI scripts. Since mSQL disallows the creation and deletion of
databases over the network, these methods explicitly connect to the
mSQL daemon running on the machine C<localhost> and execute these
operations there.

It should be noted that database deletion is I<not prompted for> in
any way.  Nor is it undo-able from DBI.

    Once you issue the dropDB() method, the database will be gone!

These methods should be used at your own risk.

=back


=head1 STATEMENT HANDLES

The statement handles of DBD::mysql and DBD::mSQL support a number
of attributes. You access these by using, for example,

  my $numFields = $sth->{'NUM_OF_FIELDS'};

Note, that most attributes are valid only after a successfull I<execute>.
An C<undef> value will returned in that case.

Column dependant attributes, for example I<NAME>, the column names,
are returned as a reference to an array. The array indices are
corresponding to the indices of the arrays returned by I<fetchrow>
and similar methods. For example the following code will print a
header of table names together with all rows:

  my $sth = $dbh->prepare("SELECT * FROM $table");
  if (!$sth) {
      die "Error:" . $dbh->errstr . "\n";
  }
  if (!$sth->execute) {
      die "Error:" . $sth->errstr . "\n";
  }
  my $names = $sth->{'NAME'};
  my $numFields = $sth->{'NUM_OF_FIELDS'};
  for (my $i = 0;  $i < $numFields;  $i++) {
      printf("%s%s", $$names[$i], $i ? "," : "");
  }
  print "\n";
  while (my $ref = $sth->fetchrow_arrayref) {
      for (my $i = 0;  $i < $numFields;  $i++) {
	  printf("%s%s", $$ref[$i], $i ? "," : "");
      }
      print "\n";
  }
x
For portable applications you should restrict yourself to attributes with
capitalized or mixed case names. Lower case attribute names are private
to DBD::mSQL and DBD::mysql. The attribute list includes:

=over 4

=item ChopBlanks

this attribute determines whether a I<fetchrow> will chop preceding
and trailing blanks off the column values. Chopping blanks does not
have impact on the I<max_length> attribute.

=item insertid

MySQL has the ability to choose unique key values automatically. If this
happened, the new ID will be stored in this attribute. This attribute
is not valid for DBD::mSQL.

=item is_blob

Reference to an array of boolean values; TRUE indicates, that the
respective column is a blob. This attribute is valid for MySQL only.

=item is_key

Reference to an array of boolean values; TRUE indicates, that the
respective column is a key. This is valid for MySQL only.

=item is_num

Reference to an array of boolean values; TRUE indicates, that the
respective column contains numeric values.

=item is_pri_key

Reference to an array of boolean values; TRUE indicates, that the
respective column is a primary key. This is only valid for MySQL
and mSQL 1.0.x: mSQL 2.x uses indices.

=item is_not_null

A reference to an array of boolean values; FALSE indicates that this
column may contain NULL's. You should better use the I<NULLABLE>
attribute above which is a DBI standard.

=item length

=item max_length

A reference to an array of maximum column sizes. The I<max_length> is
the maximum physically present in the result table, I<length> gives
the theoretically possible maximum. I<max_length> is valid for MySQL
only.

=item NAME

A reference to an array of column names.

=item NULLABLE

A reference to an array of boolean values; TRUE indicates that this column
may contain NULL's.

=item NUM_OF_FIELDS

Number of fields returned by a I<SELECT> or I<LISTFIELDS> statement.
You may use this for checking whether a statement returned a result:
A zero value indicates a non-SELECT statement like I<INSERT>,
I<DELETE> or I<UPDATE>.

=item table

A reference to an array of table names, useful in a I<JOIN> result.

=item type

A reference to an array of column types. It depends on the DBMS,
which values are returned, even for identical types. mSQL will
return types like &mSQL::INT_TYPE, &msql::TEXT_TYPE etc., MySQL
uses &mysql::FIELD_TYPE_SHORT, &mysql::FIELD_TYPE_STRING etc.

=back


=head1 COMPATIBILITY ALERT

As of version 0.70 DBD::mSQL has a new maintainer. Even more, the sources
have been completely rewritten in August 1997, so it seemed apropriate
to bump the version number: Incompatibilities are more than likely.

=head2 Recent changes:

=over 2

=item New connect method

DBD::mSQL and DBD::mysql now use the new I<connect> method as introduced
with DBI 0.83 or so. For compatibility reasons the old method still
works, but the driver issues a warning when he detects use of the
old version. There's no workaround, you must update your sources.
(Sorry, but the change was in DBI, not in DBD::mysql and DBD::mSQL.)

=item _ListFields returning statement handle

As of Msql-modules 1.1805, the private functions

    $dbh->func($table, "_ListFields");

and

    $sth->func("_ListSelectedFields");

no longer return a simple hash, but a statement handle.
(I<_ListSelectedFields> is a stub now which just returns $self.)
This should usually not be visible, when your statement handle gets
out of scope. However, if your database handle (C<$dbh> in the
above example) disconnects, either because you explicitly disconnect
or because he gets out of scope, and the statement handle is still
active, DBI will issue a warning for active cursors being destroyed.

The simple workaround is to execute C<$sth-E<gt>finish> or to ensure
that C<$sth> gets out of scope before C<$dbh>. Sorry, but it was
obvious nonsense to support two different things for accessing the
basically same thing: A M(y)SQL result.

=back

The drivers do not conform to the current DBI specification in some minor
points. For example, the private attributes I<is_num> or I<is_blob> have
been written I<IS_NUM> and I<IS_BLOB>. For historical reasons we continue
supporting the capitalized names, although the DBI specification now
reserves capitalized names for standard names, mixed case for DBI and lower
case for private attributes and methods.

We currently consider anything not conforming to the DBI as deprecated.
It is quite possible that we remove support of these deprecated names
and methods in the future. In particular these includes:

=over 4

=item C<$sth-E<gt>func($table, '_ListSelectedFields')>

highly deprecated, all attributes are directly accessible via the
statement handle. For example instead of

  $ref = $sth->func($table, '_ListSelectedFields')
  my @names = $ref->{'NAME'}

you just do a

  my @names = @{$sth->{'NAME'}};

=item Capitalized attribute names

Deprecated, should be replaced by the respective lower case names.

=back

=head1 BUGS

The I<port> part of the first argument to the connect call is
implemented in an unsafe way. In fact it never did more than set
the environment variable MSQL_TCP_PORT during the connect call. If
another connect call uses another port and the handles are used
simultaneously, they will interfere. In a future version this
behaviour will hoefully change, depending on David and Monty. :-)

The func method call on a driver handle seems to be undocumented in
the DBI manpage. DBD::mSQL has func methods on driverhandles, database
handles, and statement handles. What gives?

Please speak up now (June 1997) if you encounter additional bugs. I'm
still learning about the DBI API and can neither judge the quality of
the code presented here nor the DBI compliancy. But I'm intending to
resolve things quickly as I'd really like to get rid of the multitude
of implementations ASAP.

When running "make test", you will notice that some test scripts fail.
This is due to bugs in the respective databases, not in the DBI drivers:

=over 4

=item Nulls

mSQL seems to have problems with NULL's: The following fails with
mSQL 2.0.1 running on a Linux 2.0.30 machine:

    [joe@laptop Msql-modules-1.18]$ msql test
    Welcome to the miniSQL monitor.  Type \h for help.
    mSQL > CREATE TABLE foo (id INTEGER, name CHAR(6))\g
    Query OK.  1 row(s) modified or retrieved.
    mSQL > INSERT INTO foo VALUES (NULL, 'joe')\g
    Query OK.  1 row(s) modified or retrieved.
    mSQL > SELECT * FROM foo WHERE id = NULL\g
    Query OK.  0 row(s) modified or retrieved.
    +----------+------+
    | id       | name |
    +----------+------+
    +----------+------+
    mSQL > 

=item Blanks

mysql has problems with Blanks on the right side of string fields: They
get chopped of. (Tested with mysql 3.20.25 on a Linux 2.0.30 machine.)

    [joe@laptop Msql-modules-1.18]$ mysql test
    Welcome to the mysql monitor.  Commands ends with ; or \g.
    Type 'help' for help.
    mysql> CREATE TABLE foo (id INTEGER, bar CHAR(8));
    Query OK, 0 rows affected (0.10 sec)
    mysql> INSERT INTO foo VALUES (1, ' a b c ');
    Query OK, 1 rows affected (0.00 sec)
    mysql> SELECT * FROM foo;
    1 rows in set (0.19 sec)
    +------+--------+
    | id   | bar    |
    +------+--------+
    |    1 |  a b c |
    +------+--------+
    mysql> quit;
    [joe@laptop Msql-modules-1.18]$ mysqldump test foo

    [deleted]

    INSERT INTO foo VALUES (1,' a b c');

=back

=head1 AUTHOR

B<DBD::mSQL> has been primarily written by Alligator Descartes
(I<descarte@hermetica.com>), who has been aided and abetted by Gary
Shea, Andreas Koenig and Tim Bunce amongst others. Apologies if your
name isn't listed, it probably is in the file called
'Acknowledgments'. As of version 0.80 the maintainer is Andreas K�nig.
Version 2.00 is an almost complete rewrite by Jochen Wiedmann.


=head1 COPYRIGHT

This module is Copyright (c)1997 Jochen Wiedmann, with code portions
Copyright (c)1994-1997 their original authors. This module is
released under the 'Artistic' license which you can find in the perl
distribution.

This document is Copyright (c)1997 Alligator Descartes. All rights
reserved.  Permission to distribute this document, in full or in part,
via email, Usenet, ftp archives or http is granted providing that no
charges are involved, reasonable attempt is made to use the most
current version and all credits and copyright notices are retained (
the I<AUTHOR> and I<COPYRIGHT> sections ).  Requests for other
distribution rights, including incorporation into commercial products,
such as books, magazine articles or CD-ROMs should be made to
Alligator Descartes <I<descarte@hermetica.com>>.


=head1 ADDITIONAL DBI INFORMATION

Additional information on the DBI project can be found on the World
Wide Web at the following URL:

    http://www.hermetica.com/technologia/perl/DBI

where documentation, pointers to the mailing lists and mailing list
archives and pointers to the most current versions of the modules can
be used.

Information on the DBI interface itself can be gained by typing:

    perldoc DBI

right now!

=cut
