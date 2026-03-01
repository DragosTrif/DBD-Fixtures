use strict;
use warnings;

use Test2::V0;
use Try::Tiny;
use File::Path qw(rmtree);

use lib qw(lib t);

use DBD::Mock::Session::GenerateFixtures;
use Data::Dumper;

my $sql_user_login_history = <<"SQL";
INSERT INTO user_login_history (user_id) VALUES (?)
SQL

my $failed_sql_user_login_history = <<"SQL";
INSERT INTO user_login_history (id) VALUES (?)
SQL


my $mysqld_check = system('which mysqld > /dev/null 2>&1');
if ( $mysqld_check != 0 ) {
    plan skip_all => "MariaDB is not installed or not in PATH. Please run 'sudo apt-get install -y mariadb-server mariadb-client libmariadb-dev'";
}

my $obj = DBD::Mock::Session::GenerateFixtures->new( { file => 't/db_fixtures/18_test_transactions_with_mysql.t.json' } );

subtest 'upsert use mock data' => sub {
    my $dbh = $obj->get_dbh();
    $dbh->begin_work();
    my $sth = $dbh->prepare($sql_user_login_history);
    my $r   = $sth->execute(1);
    my $r_2 = $sth->execute(2);
    $dbh->commit();
    is( $r, 1, 'one row inserted is ok' );
    is( $r, 1, 'second row inserted is ok' );

    $dbh->begin_work();
    my $err;
    try {
        my $sth_2 = $dbh->prepare($failed_sql_user_login_history);

        my $r_3 = $sth_2->execute('aa') or die $dbh->err();
    }
    catch {
        $err = $dbh->err();
        $dbh->rollback();
    };

    ok( $err, 'rollback trapped an error' );
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

    ok( $error_big, 'error is the big try/catch is ok' );
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
    ok( $error_small, 'error is the small try/catch is ok' );
};
rmtree 't/db_fixtures';
done_testing();
