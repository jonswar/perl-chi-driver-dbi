package CHI::Driver::DBI::t::CHIDriverTests::Pg;
use strict; 
use warnings;

use base qw(CHI::Driver::DBI::t::CHIDriverTests::Base);

sub require_modules { return { 'DBD::Pg' => undef } }

sub dsn {
    return 'dbi:Pg:dbname=pesystem';
}

sub cleanup : Tests( shutdown ) {
}

1;
__END__
