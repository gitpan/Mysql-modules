#   Hej, Emacs, don't you see this is -*- perl -*- mode? :-)
#
BEGIN {require 5.003;}
use ExtUtils::MakeMaker;
use Config;
# use strict; # we're possibly still 5.002 compliant ?

$Verbose++ if $ENV{USER} eq "k";

WriteMakefile(
	      NAME       => "Mysql",
	      "DISTNAME" => "mysql-modules",
	      "dist"     => { SUFFIX   => ".gz", DIST_DEFAULT => 'all tardist',
			      COMPRESS => "gzip -9f" },
	      VERSION_FROM => "lib/Mysql.pm",
	      EXE_FILES => [qw(pmysql)],
	      PREREQ_PM => { 'DBI' => 0.88 },
	      CONFIGURE  => \&Mysql::Config::initialize,
);

package MY;	# so that "SUPER" works right
sub test {
    my $inherited = shift->SUPER::test(@_);
    # warn "pre inherited[$inherited]";
    my $matched = $inherited =~ s/(test\s*::[^\n]*\n)(\t[^\n]+\n)*\n/$1\n/s;
    # warn "inherited matched[$matched]";
    $inherited;
}

package Mysql::Config;
use ExtUtils::MakeMaker qw(prompt);
use Config;
use vars qw(%X);
%X = ();

sub Modify ($$) {
    my($source, $dest) = @_;

    if (!open(INFILE, "<$source")) {
	print STDERR "Cannot read $source: $!\n";
	exit 10;
    }
    if (!open(OUTFILE, ">$dest.new")) {
	print STDERR "Cannot create $dest.new: $!\n";
	exit 10;
    }
    while (defined($line = <INFILE>)) {
	$line =~ s/DBD\:\:mSQL/DBD\:\:mysql/g;
	if (!(print OUTFILE $line)) {
	    print STDERR "Cannot write $dest.new: $!\n";
	}
    }
    close(INFILE);
    close(OUTFILE);
    if (-f "$dest.bak"  &&  !unlink "$dest.bak") {
	print STDERR "Cannot remove $dest.bak: $!\n";
	exit 10;
    }
    if (!rename("$dest", "$dest.bak")) {
	print STDERR "Cannot rename $file to $dest.bak\n";
	exit 10;
    }
    if (!rename("$dest.new", "$dest")) {
	print STDERR "Cannot rename $dest.new to $dest: $!\n";
	exit 10;
    }
}


sub initialize {
    return \%X if %X;
    %X=();
    my @mysqldir =
	qw{
	   /usr/local
	   /usr/local/mysql
	   /usr
	   /usr/mysql
	   /opt/mysql
	  };
    unshift @mysqldir, $ENV{MYSQL_HOME} if exists $ENV{MYSQL_HOME};

    Modify("DBD-mysql/mysql.xs", "DBD-mysql/mysql.xs");
    Modify("lib/DBD/mysql.pm", "lib/DBD/mysql.pm");

    my($mysqldir,$gooddir);

    for $mysqldir (@mysqldir) {
	if ((-f "$mysqldir/include/mysql/mysql.h"  ||
	     -f "$mysqldir/include/mysql.h")  &&
	    (-f "$mysqldir/lib/mysql/libmysqlclient.a"  ||
	     -f "$mysqldir/lib/libmysqlclient.a")) {
	    $gooddir = $mysqldir;
  	    last;
  	}
    }
    $gooddir ||= $mysqldir[0];
    $gooddir = prompt("
Where is your mysql installed? Please tell me the directory that contains
the subdirs lib/ and include/.",$gooddir) || $gooddir # || for 5.002
    unless exists $ENV{MYSQL_HOME} && $gooddir eq $ENV{MYSQL_HOME};

    my $headerdir;
    if (-f "$gooddir/include/mysql/mysql.h") {
	$headerdir = "$gooddir/include/mysql";
    } elsif (-f "$gooddir/include/mysql.h") {
	$headerdir = "$gooddir/include";
    } else {
	die "No mysql.h file found in $gooddir/include\n";
    }

    my $libdir;
    if (-f "$gooddir/lib/mysql/libmysqlclient.a") {
	$libdir = "$gooddir/lib/mysql";
    } elsif (-f "$gooddir/lib/libmysqlclient.a") {
	$libdir = "$gooddir/lib";
    } else {
	die "No libmysqlclient.a file found in $gooddir/lib\n";
    }
    
    my $extralibs = "";
    my $linkwith = "";
    if ($Config{osname} eq 'sco_sv') {
	# Some extra libraries need added for SCO
	print("\nYuk! I see that you are a SCO Unix system. We\'ll add -lc",
	      " to the list of\n",
	      "libraries to link with...\n\n");
	$extralibs = "-lc";
    } elsif ($Config{osname} eq 'solaris') {
	# We need to link with -R if we're on Solaris.......Brain-damaged....
	print("\nOh dear. Solaris? Let\'s add some more flags into the",
	      " linker stage...\n\n");
	$linkwith = "-L$libdir -R$libdir";
    } elsif ($Config{osname} eq 'hpux') {
	# We need to add +z to the list of CFLAGS if we're on HP-SUX, or -fPIC 
	# if we're on HP-SUX and using 'gcc'
	if ($Config{cccdlflags} eq '+z') {
	    print("\nYou're building on HP-UX with the HP compiler.\n");
	} elsif ($Config{cccdlflags} eq '-fPIC') {
	    print("\nYou're building on HP-UX with the GNU C Compiler.\n");
	} else {
	    print("\nYou're building on HP-UX with an unknown compiler.\n");
	}
	print("You might get a warning at the link stage of:\n\n",
	      "ld: DP-Relative Code in file .../libmysqlclient.a",
	      "(libmysql.o)\n",
	      ">  - Shared Library must be Position-Independent\n\n",
	      "You'll have to recompile libmysqlclient.a from the mysql",
	      " distribution specifying\n",
	      "the '", $Config{cccdlflags}, "' flag",
	      " of your C compiler.\n");
    } elsif ($Config{osname} eq 'linux'  &&  $Config{gccversion} ne '') {
	# For reasons I don't understand the 'specs' file of some
	# gcc versions disable linking against libgcc.a in conjunction
	# with '-shared'. Unfortunately we need libgcc.a because of
	# some arithmetic functions.
	#
	# We check this by looking into gcc's "specs" file. If there
	# is a line saying
	#
	#    %{!shared:-lgcc}
	#
	# we assume a broken gcc.
	#
	my $specs = `$Config{cc} -v 2>&1`;
	if ($specs =~ /Reading specs from (\S+)/) {
	    $specs = $1;
	    print "Found specs file $specs.\n";
	    if (open(FILE, "<$specs")) {
		my $line;
		while (defined($line = <FILE>)) {
		    if ($line =~ /\%\{\!shared\:\-lgcc\}/) {
			my $libgccdir = $specs;
			$libgccdir =~ s/\/[^\/]+$//;
			print("\nYour building on Linux with gcc. According",
			      " to your specs file\n",
			      "    $specs\n",
			      "your gcc doesn't seem to link against libgcc.a",
			      " when building shared libraries.\n",
			      "I assume that your libmysqlclient.a will",
			      " need __moddi3 and __divdi3,\n",
			      "so lets be cautious and add a '-lgcc' to the",
			      " linker flags.\n\n");
			$extralibs = "-L$libgccdir -lgcc";
			last;
		    }
		}
		close(FILE);
	    }
	}
    }

    # List the libraries we're linking with (ADESC)
    my $sysliblist = ["-L$libdir -lmysqlclient -lm $extralibs"];

    my(@headerfiles) = ("$headerdir/mysql.h");
    $X{macro} = {MYSQL_HOME => $gooddir};
    $X{dynamic_lib} = { OTHERLDFLAGS => "-L$libdir/lib $linkwith" } if $linkwith;
    $X{DEFINE}   = "-DDBD_MYSQL";
    $X{LIBS}     = $sysliblist;
    $X{INC}      = "-I$headerdir -I\$(INSTALLSITEARCH)/auto/DBI -I\$(INSTALLARCHLIB)";
    $X{H}        = \@headerfiles;
    if ($ENV{HOSTNAME} eq 'laptop.ispsoft.de'  &&  $ENV{'LOGNAME'} eq 'joe') {
	$X{'DEFINE'} .= ' -Wall -pedantic -Wno-comment -Wpointer-arith'
            . ' -Wcast-align -Wconversion -Wtraditional -Wcast-qual';
    }
    \%X;
}

