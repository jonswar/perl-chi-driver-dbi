package CHI::Driver::DBI::t::CHIDriverTests::Pg;
use strict;
use warnings;

use Test::PostgreSQL;
use base qw(CHI::Driver::DBI::t::CHIDriverTests::Base);

sub require_modules { return { 'DBD::Pg' => undef,
                               'Test::PostgreSQL' => undef,
                             } }

# Building a test instance of PostgreSQL
{
    my $dsn;
    my $pgsql; # This needs to be there, cause the PostgreSQL test instance goes down on destroy.
    sub _get_dsn{
        $dsn ||= do{
            $pgsql = Test::PostgreSQL->new()
              or diag($Test::PostgreSQL::errstr);
            $pgsql ? $pgsql->dsn : 'Cannot build a postgresql DSN';
        };
        return $dsn;
    }
}

sub dsn {
    my $dsn = _get_dsn();
    return _get_dsn();
}

sub cleanup : Tests( shutdown ) {
}

1;
__END__
