#!/usr/local/bin/perl -sw

use ExtUtils::MakeMaker;
use Config;

eval {require DBI}; # The DBI must be installed before we can build a DBD

if ($@) {
    warn q{Warning:
    DBI.pm not found in @INC
You will not be able to build DBD::mysql without prior installation
of the DBI module.
};
    open MAKE, ">Makefile" or die "Couldn't open >Makefile: $!";
    print MAKE q{
all:

test:

};
    close MAKE;
    die "Skipping make for DBD::mysql";
} elsif ($DBI::VERSION < 0.84) {
    warn q{WARNING from evaluation of DBD-mysql/Makefile.PL:
    DBI.pm version $DBI::VERSION too old
You will not be able to build DBD::mysql without prior installation
of the DBI module version 0.84 or higher.
};
    open MAKE, ">Makefile" or die "Couldn't open >Makefile: $!";
    print MAKE q{
all:

test:

};
    close MAKE;
    die "Skipping make for DBD::mysql";
}

sub config () {
    my $ref = Mysql::Config::initialize();
    my %hash = %$ref;

    $hash{'DEFINE'} .= " -DMyConnect=dbd_db_connect";
    \%hash;
}

WriteMakefile(
	      NAME         => 'DBD::mysql',
	      VERSION_FROM => '../lib/DBD/mysql.pm',
	      OBJECT       => qq[\$(O_FILES)],
	      SKIP         => ['test'],
	      CONFIGURE    => \&config,
	     );
