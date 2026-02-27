use strict;
use warnings;

use Test2::V0;
use Try::Tiny;
use File::Path qw(rmtree);

use DBD::Mock::Session::GenerateFixtures;

subtest 'upsert generate mock data' => sub {

    my $dbh = DBD::Mock::Session::GenerateFixtures->new(
        { file => 't/db_fixtures/18_test_transactions_with_mysql.t.json' } )
      ->get_dbh();

    my $sql_license = <<"SQL";
INSERT INTO user_login_history (user_id) VALUES (?)
SQL

    chomp $sql_license;
    $dbh->begin_work();
    my $sth = $dbh->prepare($sql_license);
    my $r   = $sth->execute(1);
    my $r_2 = $sth->execute(2);
    $dbh->commit();
    is( $r, 1, 'one row inserted is ok' );
    is( $r, 1, 'second row inserted is ok' );

    $dbh->begin_work();
    my $r_3;
    try {
        my $sth_2 =
          $dbh->prepare('INSERT INTO user_login_history (id) VALUES (?)');
        my $r_3 = $sth_2->execute('aa');
    }
    catch {
        $dbh->rollback();
    };

    is( $r_3, undef, 'rollback is ok' );
};

rmtree 't/db_fixtures';
done_testing();
