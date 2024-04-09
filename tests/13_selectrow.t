use strict;
use warnings;

use Test2::V0;

use lib "lib";

use MyDatabase 'db_handle';
use DBDMockDumper;
use Data::Dumper;
use feature 'say';

my $dbh = DBDMockDumper->new({dbh => db_handle('test.db')})->get_dbh();

my $sql = <<"SQL";
SELECT * FROM media_types WHERE id IN(?,?) ORDER BY id DESC
SQL

chomp $sql;
my $expected = [ 2, 'audio' ];
    

subtest 'selectrow_array with prepare done' => sub {
    my $sth = $dbh->prepare($sql);
    my @got = $dbh->selectrow_array($sth, undef, (2, 1));
    is(\@got, $expected, 'selectrow_array with prepare is ok');
};

subtest 'selectrow_array without prepare done' => sub {
    my @got = $dbh->selectrow_array($sql, undef, (2, 1));
    is(\@got, $expected, 'selectrow_array without prepare is ok');
};


$dbh->disconnect();
done_testing();