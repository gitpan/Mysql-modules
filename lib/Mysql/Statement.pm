package Mysql::Statement;

use strict;
use vars qw($OPTIMIZE $VERSION $AUTOLOAD);

$VERSION = substr q$Revision: 1.1.1.1 $, 10;
# $Id: Statement.pm,v 1.1.1.1 1997/08/27 10:32:15 joe Exp $

$OPTIMIZE = 0; # controls, which optimization we default to

sub numrows    { my $x = shift; $x->{'NUMROWS'} or $x->fetchinternal( 'NUMROWS'
  ) }
sub numfields  { shift->fetchinternal( 'NUMFIELDS' ) }
sub affected_rows { my $x = shift; $x->fetchinternal( 'AFFECTEDROWS') }
sub insert_id  { my $x = shift; $x->fetchinternal( 'INSERTID') }
sub table      { return wantarray ? @{shift->fetchinternal('TABLE'    )}: shift->fetchinternal('TABLE'    )}
sub name       { return wantarray ? @{shift->fetchinternal('NAME'     )}: shift->fetchinternal('NAME'     )}
sub type       { return wantarray ? @{shift->fetchinternal('TYPE'     )}: shift->fetchinternal('TYPE'     )}
sub isnotnull  { return wantarray ? @{shift->fetchinternal('ISNOTNULL')}: shift->fetchinternal('ISNOTNULL')}
sub isprikey   { return wantarray ? @{shift->fetchinternal('ISPRIKEY' )}: shift->fetchinternal('ISPRIKEY' )}
sub isnum     { return wantarray ? @{shift->fetchinternal('ISNUM' )}: shift->fetchinternal('ISNUM' )}
sub isblob     { return wantarray ? @{shift->fetchinternal('ISBLOB' )}: shift->fetchinternal('ISBLOB' )}
sub length     { return wantarray ? @{shift->fetchinternal('LENGTH'   )}: shift->fetchinternal('LENGTH'   )}

sub listindices {
    my($sth) = shift;
    my(@result,$i);
    return () unless &Mysql::IDX_TYPE;
    foreach $i (0..$sth->numfields-1) {
    next unless $sth->type->[$i] == &Mysql::IDX_TYPE;
    push @result, $sth->name->[$i];
    }
    @result;
}

sub AUTOLOAD {
    my $meth = $AUTOLOAD;
    $meth =~ s/^.*:://;
    $meth =~ s/_//g;
    $meth = lc($meth);

    # Allow them to say fetch_row or FetchRow
    no strict;
    if (defined &$meth) {
    *$AUTOLOAD = \&{$meth};
    return &$AUTOLOAD(@_);
    }
    Carp::croak ("$AUTOLOAD not defined and not autoloadable");
}

sub unctrl {
    my($x) = @_;
    $x =~ s/\\/\\\\/g;
    $x =~ s/([\001-\037\177])/sprintf("\\%03o",unpack("C",$1))/eg;
    $x;
}

sub optimize {
    my($self,$arg) = @_;
    if (defined $arg) {
    return $self->{'OPTIMIZE'} = $arg;
    } else {
    return $self->{'OPTIMIZE'} ||= $OPTIMIZE;
    }

}

sub as_string {
    my($sth) = @_;
    my($plusline,$titline,$sprintf,$result,$s) = ('+','|','|');
    if ($sth->optimize) {
    my(@sprintf,$l);
    for (0..$sth->numfields-1) {
        $sprintf[$_] = length($sth->name->[$_]);
    }
    $sth->dataseek(0);
    my(@row);
    while (@row = $sth->fetchrow) { #map {defined $_ ? unctrl($_) : "NULL"}!
        foreach (0..$#row) {
        my($s) = defined $row[$_] ? unctrl($row[$_]) : "NULL";
        # New in 2.0: a string is longer than it should be
        if ($sth->type->[$_] == &Mysql::TEXT_TYPE && length($s) > $sth->length->[$_] + 5) {
            my $l = length($row[$_]);
            $sprintf[$_] = $sth->length->[$_] + 5 + length($l); # for "...()"
        } else {
            $sprintf[$_] = length($s) if length($s) > $sprintf[$_];
        }
        }
    }
    for (0..$sth->numfields-1) {
        $l = $sprintf[$_];
        $l *= -1 if
        $sth->type->[$_] & &Mysql::CHAR_TYPE | &Mysql::TEXT_TYPE;
        $plusline .= sprintf "%$ {l}s+", "-" x $sprintf[$_];
        $titline .= sprintf "%$ {l}s|", $sth->name->[$_];
        $sprintf .= "%$ {l}s|";
    }
    } else {
    for (0..$sth->numfields-1) {
        my $l;
        if ($sth->type->[$_] == Mysql::INT_TYPE()){
        $l = 10;
        } elsif ($sth->type->[$_] == Mysql::REAL_TYPE()){
        $l = 16;
        } else {
        $l = $sth->length->[$_];
        }
        $l < length($sth->name->[$_]) and $l = length($sth->name->[$_]);
        $plusline .= "-" x $l . "+";
        $titline .= $sth->name->[$_] . " " x ($l - length($sth->name->[$_])) . "|";
        $sprintf .= (($sth->type->[$_] & &Mysql::CHAR_TYPE | &Mysql::TEXT_TYPE)
        ? "%-$ {l}s|" : "%$ {l}s|");
    }
    }
    $sprintf .= "\n";
    #WHY?: print $@ if $@;
    $result = "$plusline\n$titline\n$plusline\n";
    $sth->dataseek(0);
    my(@row);
    while (@row = $sth->fetchrow) { #was: map {defined $_ ? unctrl($_) : "NULL"}

    my(@prow);
    foreach (0..$#row) {
        $prow[$_] = defined $row[$_] ? unctrl($row[$_]) : "NULL";
        # New in 2.0: a string is longer than it should be
        if (
        $sth->optimize &&
        $sth->type->[$_] == &Mysql::TEXT_TYPE &&
        length($prow[$_]) > $sth->length->[$_] + 5
          ) {
        my $l = length($row[$_]);
        substr($prow[$_],$sth->length->[$_])="...($l)";
        }
    }
    $result .= sprintf $sprintf, @prow;
    }
    $result .= "$plusline\n";
    $s = $sth->numrows == 1 ? "" : "s";
    $result .= $sth->numrows . " row$s processed\n\n";
    return $result;
}

1;
__END__
