use strict;
use warnings;

use lib "lib";

use MyDatabase 'db_handle';

my $dbh            = db_handle('test.db');
my $sql_media_type = "INSERT INTO media_types (media_type) VALUES (?)";
my $sth            = $dbh->prepare($sql_media_type);
my %media_type_id_for;

foreach my $type (qw/video audio image/) {
	$sth->execute($type);
	$media_type_id_for{$type} = $dbh->last_insert_id("", "", "", "");
}


my $sql_license = <<"SQL";
INSERT INTO licenses (name, allows_commercial)
VALUES ( ?, ? )
SQL

$sth = $dbh->prepare($sql_license);


my @licenses =
	(['Public Domain', 1], ['Attribution CC BY', 1], ['Attribution CC BY-SA', 1], ['Attribution-NonCommercial CC BY-NC', 0],);

my %license_id_for;
foreach my $license (@licenses) {
	my ($name, $allows_commercial) = @$license;
	$sth->execute($name, $allows_commercial);
	$license_id_for{$name} = $dbh->last_insert_id("", "", "", "");
}

my @media = ([
		'Anne Frank Stamp',                                            '/data/images/anne_fronk_stamp.jpg',
		'http://commons.wikimedia.org/wiki/File:Anne_Frank_stamp.jpg', 'Deutsche Post',
		$media_type_id_for{'image'},                                   $license_id_for{'Public Domain'},
	],
	[
		'Clair de Lune',                                                   '/data/audio/claire_de_lune.ogg',
		'http://commons.wikimedia.org/wiki/File:Sonate_Clair_de_lune.ogg', 'Schwarzer Stern',
		$media_type_id_for{'audio'},                                       $license_id_for{'Public Domain'},
	],
);


my $sql_media = <<'SQL';
INSERT INTO media (
name, location, source, attribution,
media_type_id, license_id
)
VALUES ( ?, ?, ?, ?, ?, ? )
SQL

$sth = $dbh->prepare($sql_media);
foreach my $media (@media) {
	$sth->execute(@$media);
}

$dbh->disconnect();