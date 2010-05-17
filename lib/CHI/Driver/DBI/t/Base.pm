package CHI::Driver::DBI::t::Base;
use strict;
use warnings;

use DBIx::Connector;
use base qw(CHI::t::Driver);

sub testing_driver_class    { 'CHI::Driver::DBI' }
sub supports_get_namespaces { 0 }

sub SKIP_CLASS {
    my $class = shift;

    if ( not $class->db_conn ) {
        return "Unable to get a database connection";
    }

    return 0;
}

sub db_conn {
    my $self = shift;

    eval {
        return DBIx::Connector->new(
            $self->dsn,
            '', '',
            {
                RaiseError => 0,
                PrintError => 0,
            }
        );
    };
}

sub new_cache_options {
    my $self = shift;

    return (
        $self->SUPER::new_cache_options,
        db_conn      => $self->db_conn,
        create_table => 1
    );
}

1;
