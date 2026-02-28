package DB;

use strict;
use warnings;

use Rose::DB;
use base qw(Rose::DB);
use Data::Dumper;
use Test::mysqld;

# Use a private registry for this class
__PACKAGE__->use_private_registry;

__PACKAGE__->register_db(
    domain          => 'development',
    type            => 'main',
    driver          => 'sqlite',
    database        => 't/rose_test_db',
    connect_options => {
        RaiseError   => 1,
        AutoCommit   => 1,
        PrintError   => 0,
        sqlite_trace => 1,
    }
);

my $mysqld_check = system('which mysqld > /dev/null 2>&1');

if ( $mysqld_check == 0 ) {

    our $mysqld = Test::mysqld->new(
        mysqld => '/usr/sbin/mysqld',    # MariaDB binary
        my_cnf => {
            'skip-networking' => '',
        }
    ) or die "Failed to start Test::mysqld";

    DB->register_db(
        domain          => 'mysql_test',
        type            => 'mysql_test',
        driver          => 'mysql',       # keep this unless using DBD::MariaDBq
        dsn             => $mysqld->dsn( dbname => 'test' ),
        connect_options => {
            RaiseError => 1,
            AutoCommit => 1,
            PrintError => 0,
        }
    );
}

1;
