package CHI::Driver::DBI::t::BackCompat;
use strict;
use warnings;

use base qw(CHI::Driver::DBI::t::Base);

sub SKIP_CLASS {
    my $class = shift;

    if ( not $class->dbh ) {
        return "Unable to get a database connection";
    }

    return 0;
}

sub dbh {
    my $self = shift;

    eval {
        return DBI->connect(
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
        dbh          => $self->dbh,
        create_table => 1
    );
}

sub required_modules { return { 'DBD::SQLite' => undef } }

sub dsn {
    return 'dbi:SQLite:dbname=t/dbfile-2.db';
}

sub cleanup : Tests( shutdown ) {
    unlink 't/dbfile-2.db';
}

1;
