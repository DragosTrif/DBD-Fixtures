use strict;
use warnings;

use Test2::V0;

use lib "lib";

use MyDatabase 'db_handle';
use DBD::Mock::Session::GenerateFixtures;
use Data::Dumper;
use feature 'say';


note 'running do';


subtest 'upsert generate mock data' => sub {
	my $obj = DBD::Mock::Session::GenerateFixtures->new({dbh => db_handle('test.db')});
	my $dbh = $obj->get_dbh();

	my $sql_license = <<"SQL";
INSERT INTO licenses (name, allows_commercial) VALUES ( ?, ? )
SQL

	chomp $sql_license;
    my $r = $dbh->do($sql_license, undef, 'test_license', 'no');
	is( $r, 1, 'one row inserted is ok');
    
	my $update_sql = 'update licenses set allows_commercial = ? where id > ?';
	$r = $dbh->do($update_sql, undef, 'yes', '3');
	is($r, 158);
    $obj->restore_all();
    $dbh->disconnect();
};
{
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
	is($r, 158);
     $dbh_2->disconnect();
};
}

done_testing();
