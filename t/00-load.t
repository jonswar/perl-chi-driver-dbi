#!perl -T

use Test::More tests => 1;
use DBI;

BEGIN {
    use_ok('CHI::Driver::DBI');
}

diag("Testing CHI::Driver::DBI $CHI::Driver::DBI::VERSION, Perl $], $^X");
