
package MyDatabase;

use strict;
use warnings;

use DBI;
use Carp 'croak';
use Exporter::NoWork;
use autodie;
sub db_handle {
	my $db_file = shift
		or croak "db_handle() requires a database name";

	# no warnings 'once';

	return DBI->connect(
		"dbi:SQLite:dbname=$db_file",
		"",    # no username required,
		"",    # no pass required,
		{
			RaiseError => 1,
			PrintError => 0,
			# AutoCommit => 1
		},
	);
}


1;
