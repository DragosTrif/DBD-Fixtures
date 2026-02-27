use strict;
use warnings;

use Test2::V0;
use Try::Tiny;

use lib        qw(lib t);
use MyDatabase qw(build_mysql_db populate_test_db);

use DBI;
use Data::Dumper;
use DBD::Mock::Session::GenerateFixtures;
use Sub::Override;
use File::Path qw(rmtree);
use Test::mysqld;

my $mysqld_check       = system("which mysqld > /dev/null 2>&1");
my $mysql_config_check = system("which mysql_config > /dev/null 2>&1");

if ( $mysqld_check != 0 || $mysql_config_check != 0 ) {
    plan skip_all =>
"mysqld is not installed or not in PATH. Please run 'sudo apt-get install -y mysql-server, mysql-client, and libmysqlclient-dev'";
}

my $mysqld = Test::mysqld->new(
    my_cnf => {
        'skip-networking' => '',    # no TCP socket
    }
) or die "Failed to start Test::mysqld";

my $dbh = DBI->connect( $mysqld->dsn( dbname => 'test' ),
     {
        RaiseError => 1,   # ← THIS is where it goes
        PrintError => 0,
        AutoCommit => 1,
    }
);

build_mysql_db($dbh);
populate_test_db($dbh);
my $obj = DBD::Mock::Session::GenerateFixtures->new( { dbh => $dbh } );

subtest 'upsert generate mock data' => sub {

    my $sql_license = <<"SQL";
INSERT INTO user_login_history (user_id) VALUES (?)
SQL

    chomp $sql_license;
    $obj->get_dbh()->begin_work();
    my $sth = $obj->get_dbh()->prepare($sql_license);
    my $r   = $sth->execute(1);
    my $r_2 = $sth->execute(2);
    $obj->get_dbh()->commit();
    is( $r, 1, 'one row inserted is ok' );
    is( $r, 1, 'one second inserted is ok' );

    $obj->get_dbh()->begin_work();
     my $r_3;
    try {
    my $sth_2 = $obj->get_dbh()->prepare('INSERT INTO user_login_history (id) VALUES (?)');
    $r_3   = $sth_2->execute('aa') or die $obj->get_dbh()->err();
    } catch {
        $obj->get_dbh()->rollback();
    };

    is($r_3, undef, 'rollback is ok');
};


done_testing();
