use ExtUtils::MakeMaker;

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
