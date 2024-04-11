use strict;
use warnings;

use Test2::V0;

use lib "lib";

use MyDatabase 'db_handle';
use DBDMockDumper;
use Data::Dumper;
use feature 'say';


my $sql = <<"SQL";
SELECT * FROM media_types WHERE id IN(?,?) ORDER BY id DESC
SQL

my $expected = [2, 'audio'];
chomp $sql;

subtest 'selectrow generate mock data' => sub {
	note 'running selectrow_array';

	my $obj = DBDMockDumper->new({dbh => db_handle('test.db')});
	my $dbh = $obj->get_dbh();

	my $sth = $dbh->prepare($sql);
	my @got = $dbh->selectrow_array($sth, undef, (2, 1));
	is(\@got, $expected, 'selectrow_array with prepare is ok');

	@got = $dbh->selectrow_array($sql, undef, (2, 1));
	is(\@got, $expected, 'selectrow_array without prepare is ok');

	@got = $dbh->selectrow_array($sql, undef, (12, 13));
	is(\@got, [], 'selectrow_array without prepare an no rows found is ok');

	note 'running selectrow_arrayref';
	my $got = $dbh->selectrow_arrayref($sth, undef, (2, 1));

	is($got, $expected, 'selectrow_arrayref with prepare is ok');

	$got = $dbh->selectrow_arrayref($sql, undef, (2, 1));
	is($got, $expected, 'selectrow_arrayref without prepare is ok');

	$got = $dbh->selectrow_arrayref($sql, undef, (12, 13));
	is($got, undef, 'selectrow_arrayref without prepare an no rows found is ok');

	$dbh->disconnect();
};

subtest 'selectrow generate use mock data' => sub {
	my $obj = DBDMockDumper->new();
	my $dbh = $obj->get_dbh();

	my $sth = $dbh->prepare($sql);
	my @got = $dbh->selectrow_array($sth, undef, (2, 1));

	is(\@got, $expected, 'selectrow_array with prepare is ok');

	@got = $dbh->selectrow_array($sql, undef, (2, 1));
	is(\@got, $expected, 'selectrow_array without prepare is ok');

	@got = $dbh->selectrow_array($sql, undef, (12, 13));
	is(\@got, [], 'selectrow_array without prepare and no rows found is ok');

	note 'running selectrow_arrayref';

	my $got = $dbh->selectrow_arrayref($sth, undef, (2, 1));
	is($got, $expected, 'selectrow_arrayref with prepare is ok');

	$got = $dbh->selectrow_arrayref($sql, undef, (2, 1));
	is($got, $expected, 'selectrow_arrayref without prepare is ok');

	$got = $dbh->selectrow_arrayref($sql, undef, (12, 13));
	is($got, undef, 'selectrow_arrayref without prepare an no rows found is ok');
};


done_testing();
