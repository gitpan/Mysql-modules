use ExtUtils::MakeMaker;

if ($ENV{'LOCAL_PERL'}) {
      WriteMakefile(
		    NAME => 'Mysql',
		    INC => '-I/usr/local/include/mysql -I../DBD-mysql',
		    LIBS => '-L/usr/local/lib/mysql -lmysqlclient',
		    VERSION_FROM => "../lib/Mysql.pm",
		    SKIP => [qw(test)],
		    OBJECT => '$(O_FILES)',
		    DEFINE => '-DDBD_MYSQL'
		  );
      exit 0;
}

my $mref = sub {
    $line = shift;
    if ($line =~ /^\s*MODULE\s+=/) {
	$line =~ s/Msql/Mysql/g;
    }
    $line;
};

Mysql::Config::Modify("Mysql.xs", "Mysql.xs", $mref);
    

sub config () {
    my $ref = &Mysql::Config::initialize();
    %hash = %$ref;
    $hash{'INC'} .= " -I../DBD-mysql";
    \%hash;
}

WriteMakefile(
	      NAME => 'Mysql',
	      VERSION_FROM => "../lib/Mysql.pm",
	      SKIP => [qw(test)],
	      CONFIGURE  => \&config,
	      OBJECT => '$(O_FILES)'
);
