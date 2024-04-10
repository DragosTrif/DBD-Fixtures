use strict;
use warnings;

use Test2::V0;

use lib "lib";

use MyDatabase 'db_handle';
use DBDMockDumper;
use Data::Dumper;
use feature 'say';

# my $dbh = DBDMockDumper->new({dbh => db_handle('test.db')})->get_dbh();

my $sql = <<"SQL";
SELECT * FROM media_types WHERE id IN(?,?) ORDER BY id DESC
SQL

chomp $sql;
my $expected = [ 2, 'audio' ];
    

subtest 'selectrow generate mock data' => sub {
    my $obj = DBDMockDumper->new({dbh => db_handle('test.db')});
    my $dbh_1 = $obj->get_dbh();

    my $sth = $dbh_1->prepare($sql);
    my @got = $dbh_1->selectrow_array($sth, undef, (2, 1));
    is(\@got, $expected, 'selectrow_array with prepare is ok');

    @got = $dbh_1->selectrow_array($sql, undef, (2, 1));
    is(\@got, $expected, 'selectrow_array without prepare is ok');

    @got = $dbh_1->selectrow_array($sql, undef, (12, 13));
    is(\@got, [], 'selectrow_array without prepare an no rows found is ok');


    $dbh_1->disconnect();
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

    ok(1);
};



done_testing();