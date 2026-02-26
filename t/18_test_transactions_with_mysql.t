use Test2::V0;
use Try::Tiny;

use lib        qw(lib t);
use MyDatabase qw(build_mysql_db populate_test_db);

use DBI;
use Data::Dumper;
use DBD::Mock::Session::GenerateFixtures;
use Sub::Override;
use File::Path qw(rmtree);

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

subtest 'upsert generate mock data' => sub {

    my $dbh = DBI->connect( $mysqld->dsn( dbname => 'test' ), );

    build_mysql_db($dbh);
    populate_test_db($dbh);
    my $obj = DBD::Mock::Session::GenerateFixtures->new( { dbh => $dbh } );

    my $sql_license = <<"SQL";
INSERT INTO user_login_history (user_id) VALUES (?)
SQL

    chomp $sql_license;
    $dbh->begin_work();
    my $r = $dbh->do( $sql_license, undef, 1 );
    is( $r, 1, 'one row inserted is ok' );
    $dbh->commit();

};

subtest 'upsert generate mock data' => sub {

    my $dbh = DBD::Mock::Session::GenerateFixtures->new()->get_dbh();

    my $sql_license = <<"SQL";
INSERT INTO user_login_history (user_id) VALUES (?)
SQL

    chomp $sql_license;
    $dbh->begin_work();
    my $r = $dbh->do( $sql_license, undef, 1 );
    is( $r, 1, 'one row inserted is ok' );
    $dbh->commit();

};

done_testing();
