use strict;
use warnings;

use Test2::V0;
use File::Path qw(rmtree);

use lib qw(lib tests);

use MyDatabase qw(db_handle build_tests_db populate_test_db);

use DBD::Mock::Session::GenerateFixtures;
use Data::Dumper;
use feature 'say';


note 'running do';

subtest 'upsert generate mock data' => sub {
	my $dbh = db_handle('test.db');

	build_tests_db($dbh);
	populate_test_db($dbh);

	my $obj = DBD::Mock::Session::GenerateFixtures->new({dbh => $dbh});
	$dbh = $obj->get_dbh();

	my $sql_license = <<"SQL";
INSERT INTO licenses (name, allows_commercial) VALUES ( ?, ? )
SQL

	chomp $sql_license;
    my $r = $dbh->do($sql_license, undef, 'test_license', 'no');
	is( $r, 1, 'one row inserted is ok');
    
	my $update_sql = 'update licenses set allows_commercial = ? where id > ?';
	$r = $dbh->do($update_sql, undef, 'yes', '3');
	is($r, 2);
    $obj->restore_all();
    $dbh->disconnect();
};

subtest 'upsert use mock data' => sub {
	my $obj_2 = DBD::Mock::Session::GenerateFixtures->new({override => 0});
	my $dbh_2 = $obj_2->get_dbh();

	my $sql_license = <<"SQL";
INSERT INTO licenses (name, allows_commercial) VALUES ( ?, ? )
SQL

	chomp $sql_license;
	is($dbh_2->do($sql_license, undef, 'test_license', 'no'), 1, 'one row inserted is ok');
	my $update_sql = 'update licenses set allows_commercial = ? where id > ?';
	my $r = $dbh_2->do($update_sql, undef, 'yes', '3');
	is($r, 2);
     $dbh_2->disconnect();
};

rmtree './tests/db_fixtures';

done_testing();
