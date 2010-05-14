use inc::Module::Install;

name 'CHI-Driver-DBI';
abstract 'Use DBI for cache';
all_from 'lib/CHI/Driver/DBI.pm';
author 'Jonathan Swartz <swartz@pobox.com>';

perl_version '5.006';

build_requires 'Test::Class' => 0;
build_requires 'Test::Most'  => 0;

requires 'DBI' => '0';
requires 'CHI' => '0.241';

license 'perl';

auto_install;

WriteAll;
