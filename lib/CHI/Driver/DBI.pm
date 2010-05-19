package CHI::Driver::DBI;

use strict;
use warnings;

use DBI::Const::GetInfoType;
use Moose;
use Moose::Util::TypeConstraints;
use Carp qw(croak);

our $VERSION = '1.23';

# TODO:  For pg see "upsert" - http://www.postgresql.org/docs/current/static/plpgsql-control-structures.html#PLPGSQL-UPSERT-EXAMPLE

extends 'CHI::Driver';

my $type = "CHI::Driver::DBI";

subtype "$type.DBIHandleGenerator" => as 'CodeRef';
subtype "$type.DBIXConnector"      => as 'DBIx::Connector';
subtype "$type.DBIHandle"          => as 'DBI::db';

coerce "$type.DBIHandleGenerator" => from "$type.DBIXConnector" => via {
    my $dbixconn = $_;
    sub { $dbixconn->dbh }
};
coerce "$type.DBIHandleGenerator" => from "$type.DBIHandle" => via {
    my $dbh = $_;
    sub { $dbh }
};

=head1 NAME

CHI::Driver::DBI - Use DBI for cache storage

=head1 SYNOPSIS

 use CHI;

 # Supply a DBI handle
 #
 my $cache = CHI->new( driver => 'DBI', dbh => DBI->connect(...) );

 # or a DBIx::Connector
 #
 my $cache = CHI->new( driver => 'DBI', dbh => DBIx::Connector->new(...) );

 # or code that generates a DBI handle
 #
 my $cache = CHI->new( driver => 'DBI', dbh => sub { ...; return $dbh } );

=head1 DESCRIPTION

This driver uses a database table to store the cache.  The newest versions of
MySQL and SQLite work are known to work.  Other RDBMSes should work.

Why cache things in a database?  Isn't the database what people are trying to
avoid with caches?  This is often true, but a simple primary key lookup is
extremely fast in many databases and this provides a shared cache that can be
used when less reliable storage like memcached is not appropriate.  Also, the
speed of simple lookups on MySQL when accessed over a local socket is very hard
to beat.  DBI is fast.

=head1 ATTRIBUTES

=over

=item namespace

The namespace you pass in will be appended to the C<table_prefix> and used as a
table name.  That means that if you don't specify a namespace or table_prefix
the cache will be stored in a table called C<chi_Default>.

=item table_prefix

This is the prefix that is used when building a table name.  If you want to
just use the namespace as a literal table name, set this to undef.  Defaults to
C<chi_>.

=cut

has 'table_prefix' => ( is => 'rw', isa => 'Str', default => 'chi_', );

=item dbh

The main, or rw, DBI handle used to communicate with the db. If a dbh_ro handle
is defined then this handle will only be used for writing.

You may pass this handle, and dbh_ro below, in one of three forms:

=over

=item *

a regular DBI handle

=item *

a L<DBIx::Connector|DBIx::Connector> object

=item *

a code reference that will be called each time and is expected to return a DBI
handle, e.g.

    sub { My::Rose::DB->new->dbh }

=back

The last two options are valuable if your CHI object is going to live for
enough time that a single DBI handle might time out, etc.

=cut

has 'dbh' => ( is => 'ro', isa => "$type.DBIHandleGenerator", coerce => 1 );

=item dbh_ro

The optional DBI handle used for read-only operations.  This is to support
master/slave RDBMS setups.

=cut

has 'dbh_ro' => (
    is        => 'ro',
    isa       => "$type.DBIHandleGenerator",
    predicate => 'has_dbh_ro',
    coerce    => 1,
);

=item sql_strings

Hashref of SQL strings to use in the different cache operations. The strings
are built depending on the RDBMS that dbh is attached to.

=back

=cut

has 'sql_strings' => ( is => 'rw', isa => 'HashRef', lazy_build => 1, );

__PACKAGE__->meta->make_immutable;

=head1 METHODS

=over

=item BUILD

Standard issue Moose BUILD method.  Used to build the sql_strings.  If the
parameter C<create_table> to C<new()> was set to true, it will attempt to
create the db table.  For Mysql and SQLite the statement is "create if not
exists..." so it's generally harmless.

=cut

sub BUILD {
    my ( $self, $args ) = @_;

    my $dbh = $self->dbh->();

    $self->sql_strings;

    if ( $args->{create_table} ) {
        $dbh->do( $self->sql_strings->{create} )
          or croak $dbh->errstr;
    }

    return;
}

sub _table {
    my ( $self, ) = @_;

    return $self->table_prefix() . $self->namespace();
}

sub _build_sql_strings {
    my ( $self, ) = @_;

    my $dbh     = $self->dbh->();
    my $table   = $dbh->quote_identifier( $self->_table );
    my $value   = $dbh->quote_identifier('value');
    my $key     = $dbh->quote_identifier('key');
    my $db_name = $dbh->get_info( $GetInfoType{SQL_DBMS_NAME} );

    my $strings = {
        fetch    => "SELECT $value FROM $table WHERE $key = ?",
        store    => "INSERT INTO $table ( $key, $value ) VALUES ( ?, ? )",
        store2   => "UPDATE $table SET $value = ? WHERE $key = ?",
        remove   => "DELETE FROM $table WHERE $key = ?",
        clear    => "DELETE FROM $table",
        get_keys => "SELECT DISTINCT $key FROM $table",
        create   => "CREATE TABLE IF NOT EXISTS $table ("
          . " $key VARCHAR( 600 ), $value TEXT,"
          . " PRIMARY KEY ( $key ) )",
    };

    if ( $db_name eq 'MySQL' ) {
        $strings->{store} =
            "INSERT INTO $table"
          . " ( $key, $value )"
          . " VALUES ( ?, ? )"
          . " ON DUPLICATE KEY UPDATE $value=VALUES($value)";
        delete $strings->{store2};
    }
    elsif ( $db_name eq 'SQLite' ) {
        $strings->{store} =
            "INSERT OR REPLACE INTO $table"
          . " ( $key, $value )"
          . " values ( ?, ? )";
        delete $strings->{store2};
    }

    return $strings;
}

=item fetch

=cut

sub fetch {
    my ( $self, $key, ) = @_;

    my $dbh = $self->has_dbh_ro ? $self->dbh_ro->() : $self->dbh->();
    my $sth = $dbh->prepare_cached( $self->sql_strings->{fetch} )
      or croak $dbh->errstr;
    $sth->execute($key) or croak $sth->errstr;
    my $results = $sth->fetchall_arrayref;

    return $results->[0]->[0];
}

=item store

=cut

sub store {
    my ( $self, $key, $data, ) = @_;

    my $dbh = $self->dbh->();
    my $sth = $dbh->prepare_cached( $self->sql_strings->{store} );
    if ( not $sth->execute( $key, $data ) ) {
        if ( $self->sql_strings->{store2} ) {
            my $sth = $dbh->prepare_cached( $self->sql_strings->{store2} )
              or croak $dbh->errstr;
            $sth->execute( $data, $key )
              or croak $sth->errstr;
        }
        else {
            croak $sth->errstr;
        }
    }
    $sth->finish;

    return;
}

=item remove

=cut

sub remove {
    my ( $self, $key, ) = @_;

    my $dbh = $self->dbh->();
    my $sth = $dbh->prepare_cached( $self->sql_strings->{remove} )
      or croak $dbh->errstr;
    $sth->execute($key) or croak $sth->errstr;
    $sth->finish;

    return;
}

=item clear

=cut

sub clear {
    my ( $self, $key, ) = @_;

    my $dbh = $self->dbh->();
    my $sth = $dbh->prepare_cached( $self->sql_strings->{clear} )
      or croak $dbh->errstr;
    $sth->execute() or croak $sth->errstr;
    $sth->finish();

    return;
}

=item get_keys

=cut

sub get_keys {
    my ( $self, ) = @_;

    my $dbh = $self->has_dbh_ro ? $self->dbh_ro->() : $self->dbh->();
    my $sth = $dbh->prepare_cached( $self->sql_strings->{get_keys} )
      or croak $dbh->errstr;
    $sth->execute() or croak $sth->errstr;
    my $results = $sth->fetchall_arrayref( [0] );
    $_ = $_->[0] for @{$results};

    return @{$results};
}

=item get_namespaces

Not supported at this time.

=back

=cut

sub get_namespaces { croak 'not supported' }

=head1 Authors

Original version by Justin DeVuyst and Perrin Harkins. Currently maintained by
Jonathan Swartz.

=head1 COPYRIGHT & LICENSE

Copyright (C) Justin DeVuyst

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
