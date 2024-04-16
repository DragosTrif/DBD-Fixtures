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

	$dbh->do($sql_license, undef, 'test_license', 'no');
	is($dbh->do($sql_license, undef, 'test_license', 'no'), 1, 'one row inserted is ok');
};

subtest 'upsert use mock data' => sub {
	my $obj = DBD::Mock::Session::GenerateFixtures->new();
	my $dbh = $obj->get_dbh();

	my $sql_license = <<"SQL";
INSERT INTO licenses (name, allows_commercial) VALUES ( ?, ? )
SQL

	chomp $sql_license;

	$dbh->do($sql_license, undef, 'test_license', 'no');

	is($dbh->do($sql_license, undef, 'test_license', 'no'), 1, 'one row inserted is ok');
};


done_testing();
