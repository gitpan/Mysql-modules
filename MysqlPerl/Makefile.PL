use ExtUtils::MakeMaker;

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
