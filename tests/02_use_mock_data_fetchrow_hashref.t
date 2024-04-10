use strict;
use warnings;

use Test2::V0;

use lib "lib";

use MyDatabase 'db_handle';
use DBDMockDumper;
use Data::Dumper;
use feature 'say';

my $dbh = DBDMockDumper->new({file => './tests/db_fixtures/01_generate_file.t.json'})->get_dbh();


my $sql = <<"SQL";
SELECT * FROM media_types WHERE id IN(?,?)
SQL
chomp $sql;

my $expected = [
        {
          'id' => 1,
          'media_type' => 'video'
        },
        {
          'media_type' => 'audio',
          'id' => 2
        }
    ];

subtest 'preapare and execute' => sub {
    my $sth = $dbh->prepare($sql);
    $sth->execute(2, 1);
    my $got = [];
    
    while (my $row = $sth->fetchrow_hashref()) {
        push @{$got}, $row;
    }

    is($got, $expected, 'prepare and execute is ok');
};

subtest 'preapare and execute with data from test' => sub {
    my $fixtures = [
   {
      "results" => [
         [
            1,
            "video"
         ],
         [
            2,
            "audio"
         ]
      ],
      "col_names" => [ "id", "media_type" ],
      "bound_params" => [
         2,
         1
      ],
      "statement" => "SELECT * FROM media_types WHERE id IN(?,?)"
   },];
    
    my $dbh2 = DBDMockDumper->new({data => $fixtures})->get_dbh();
    my $sth = $dbh2->prepare($sql);
    $sth->execute(2, 1);
    my $got = [];
    
    while (my $row = $sth->fetchrow_hashref()) {
        push @{$got}, $row;
    }
   
    is($got, $expected, 'prepare and execute is ok');
};

subtest 'bind params with postional bind' => sub {

    my $sth = $dbh->prepare($sql);
    $sth->bind_param(1, 1, undef);
    $sth->bind_param(2, 2, undef);
    $sth->execute();
    my $got = [];
    while (my $row = $sth->fetchrow_hashref()) {
        push @{$got}, $row;
    }

    is($got, $expected, 'postional bind is ok');
};

subtest 'bind params with named bind' => sub {
    
    my $sth = $dbh->prepare('SELECT * FROM media_types WHERE id IN(:id, :id_2)');
    $sth->bind_param(':id' => 2, undef);
    $sth->bind_param(':id_2' => 1, undef);
    $sth->execute();
    my $got = []; 
    while (my $row = $sth->fetchrow_hashref()) {
        push @{$got}, $row;
    }

    is($got, $expected, 'binding named params is ok');
};

subtest 'no bind parmas' => sub {
    
    my $sth = $dbh->prepare('SELECT * FROM media_types');
    $sth->execute();
    my $got = [];
    my $expected = [
          {
            'media_type' => 'video',
            'id' => 1
          },
          {
            'id' => 2,
            'media_type' => 'audio'
          },
          {
            'media_type' => 'image',
            'id' => 3
          }
        ];
 
    while (my $row = $sth->fetchrow_hashref()) {
        push @{$got}, $row;
    }
    
    is($got, $expected, 'no biding parmas is ok');

};

subtest 'no rows returned' => sub {
    
    my $sth = $dbh->prepare('SELECT * FROM media_types WHERE id IN(?,?)');
 
    $sth->execute(11, 12);
   
    my $got = [];
    my $expected = [];
 
    while (my $row = $sth->fetchrow_hashref()) {
        push @{$got}, $row;
    }
    is($got, $expected, 'no biding parmas is ok');

};

$dbh->disconnect();

done_testing();