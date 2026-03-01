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

my $mysqld_check = system('which mysqld > /dev/null 2>&1');

if ( $mysqld_check != 0 ) {
    plan skip_all => "MariaDB is not installed or not in PATH. Please run 'sudo apt-get install -y mariadb-server mariadb-client libmariadb-dev'";
}

my $mysqld = Test::mysqld->new(
    my_cnf => {
        'skip-networking' => '',    # no TCP socket
    }
) or die "Failed to start Test::mysqld";

my $dbh = DBI->connect(
    $mysqld->dsn( dbname => 'test' ),
    {
        RaiseError => 1,            # ← THIS is where it goes
        PrintError => 0,
        AutoCommit => 1,
    }
);

build_mysql_db($dbh);
populate_test_db($dbh);
my $obj = DBD::Mock::Session::GenerateFixtures->new( { dbh => $dbh } );

my $sql_user_login_history = <<"SQL";
INSERT INTO user_login_history (user_id) VALUES (?)
SQL

my $failed_sql_user_login_history = <<"SQL";
INSERT INTO user_login_history (id) VALUES (?)
SQL

subtest 'upsert generate mock data' => sub {

    $obj->get_dbh()->begin_work();
    my $sth = $obj->get_dbh()->prepare($sql_user_login_history);
    my $r   = $sth->execute(1) or die $obj->get_dbh()->err();
    my $r_2 = $sth->execute(2) or die $obj->get_dbh()->err();
    $obj->get_dbh()->commit();
    is( $r, 1, 'one row inserted is ok' );
    is( $r, 1, 'one second inserted is ok' );

    $obj->get_dbh()->begin_work();
    my $r_3;
    try {
        my $sth_2 = $obj->get_dbh()->prepare('INSERT INTO user_login_history (id) VALUES (?)');
        $r_3 = $sth_2->execute('aa') or die $obj->get_dbh()->err();
    }
    catch {
        note 'in catch';
        $obj->get_dbh()->rollback();
    };

    is( $r_3, undef, 'rollback is ok' );
};

subtest 'upsert generate mock data for nested transactions both are ok' => sub {
    my $dbh = $obj->get_dbh();
    try {
        $dbh->begin_work();
        my $sth = $dbh->prepare($sql_user_login_history);
        my $r   = $sth->execute(3) or die $obj->get_dbh()->err();
        try {
            my $sth_2 = $dbh->prepare($sql_user_login_history);
            my $r_2   = $sth_2->execute(4) or die $dbh->err();
            is( $r_2, 1, 'one second inserted is ok' );
        }
        catch {
            $dbh->rollback();
        };
        $dbh->commit();
        is( $r, 1, 'one row inserted is ok' );
    }
    catch {
        $obj->get_dbh()->rollback();
    };

};

subtest 'upsert generate mock data for nested transactions - big trans is not ok' => sub {
    my $error_big   = undef;
    my $error_small = undef;

    my $dbh = $obj->get_dbh();
    my $ok  = 1;
    try {
        $dbh->begin_work();
        my $sth = $dbh->prepare($failed_sql_user_login_history);
        my $r   = $sth->execute(3) or die $dbh->get_dbh()->err();
        try {
            my $sth_2 = $dbh->prepare($sql_user_login_history);
            my $r_2   = $sth_2->execute(4) or die $dbh->err();
        }
        catch {
            $ok          = 0;
            $error_small = $dbh->err();
            $dbh->rollback();
        };
    }
    catch {
        $ok        = 0;
        $error_big = $dbh->err();
        $dbh->rollback();
    };

    $dbh->commit() if $ok;

    ok( $error_big, 'error in the big try/catch is ok' );
};

subtest 'upsert generate mock data for nested transactions - small trans is not ok' => sub {
    my $error_big   = undef;
    my $error_small = undef;

    my $dbh = $obj->get_dbh();
    my $ok  = 1;
    try {
        $dbh->begin_work();
        my $sth = $dbh->prepare($sql_user_login_history);
        my $r   = $sth->execute(3) or die $dbh->err();
        try {
            my $sth_2 = $dbh->prepare($failed_sql_user_login_history);
            my $r_2   = $sth_2->execute(4) or die $dbh->err();
        }
        catch {
            $error_small = $dbh->err();
            $ok          = 0;
            $dbh->rollback();
        };
    }
    catch {
        $error_big = $dbh->err();
        $dbh->rollback();
    };

    $dbh->commit() if $ok;
    ok( $error_small, 'error in the small try/catch is ok' );
};

done_testing();
