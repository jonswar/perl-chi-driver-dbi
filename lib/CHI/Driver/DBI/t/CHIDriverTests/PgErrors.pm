package CHI::Driver::DBI::t::CHIDriverTests::PgErrors;
use strict;
use warnings;

use Test::PostgreSQL;
use base qw(CHI::Driver::DBI::t::CHIDriverTests::Pg);
use Test::More;

## Override CHI::Driver::DBI::t::CHIDriverTests::Base
## to test that things work with RaiseError => 1
sub dbh {
    my $self = shift;

    eval {
        return DBI->connect(
            $self->dsn(),
            '', '',
            {
                RaiseError => 1,
                PrintError => 0,
                PrintWarn => 0,
            }
        );
    };
}


sub test_raiseerror_persists : Tests{
    my ($self) = @_;
    my $dbh = $self->dbh();
    ok( $dbh->{RaiseError} , "Ok DBH has got RaiseError");
    my $sth = $dbh->prepare_cached('SELECT 1');
    ok( $sth->{RaiseError} , "New statement has got RaiseError");
}

sub cleanup : Tests( shutdown ) {
}

1;
__END__
