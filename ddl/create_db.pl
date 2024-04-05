use strict;
use warnings;


use lib "lib";
use MyDatabase 'db_handle';

my $dbh = db_handle('test.db');

my $sql_media_type = <<"SQL";
CREATE TABLE IF NOT EXISTS media_types (
	id INTEGER PRIMARY KEY,
	media_type VARCHAR(10) NOT NULL
);
SQL

$dbh->do($sql_media_type);


my $sql_media = <<"SQL";
CREATE TABLE IF NOT EXISTS media (
id INTEGER PRIMARY KEY,
name VARCHAR(255) NOT NULL,
location VARCHAR(255) NOT NULL,
source VARCHAR(511) NOT NULL,
attribution VARCHAR(255) NOT NULL,
media_type_id INTEGER NOT NULL,
license_id INTEGER NOT NULL,
FOREIGN KEY (media_type_id) REFERENCES media_types(id),
FOREIGN KEY (license_id)
REFERENCES licenses(id)
);
SQL

$dbh->do($sql_media);

my $sql_license = <<"SQL";
CREATE TABLE IF NOT EXISTS licenses (
	id INTEGER PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	allows_commercial BOOLEAN NOT NULL
);
SQL

$dbh->do($sql_license);
$dbh->disconnect();
