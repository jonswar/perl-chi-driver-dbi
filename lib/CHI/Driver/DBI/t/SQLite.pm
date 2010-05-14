package CHI::Driver::DBI::t::SQLite;
use strict;
use warnings;

use base qw(CHI::Driver::DBI::t::Base);

sub required_modules { return { 'DBD::SQLite' => undef } }

sub dsn {
    return 'dbi:SQLite:dbname=t/dbfile.db';
}

sub cleanup : Tests( shutdown ) {
    unlink 't/dbfile.db';
}

1;
