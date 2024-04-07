package DBDMockDumper;

use strict;
use warnings;

use Carp 'croak';
use DBD::Mock;

use Data::Dumper;
use feature 'say';
use Sub::Override;
use English qw ( -no_match_vars );

use File::Path qw(make_path);
use Cpanel::JSON::XS;
use File::Slurper qw (read_text);
use File::Spec;
use Carp qw( croak );
use Readonly;
use Data::Walk;

our $override;
my $JSON_OBJ = Cpanel::JSON::XS->new()->utf8->pretty();

Readonly::Hash my %MOCKED_DBI_METHODS => (
	execute            => 'DBI::st::execute',
	bind_param         => 'DBI::st::bind_param',
	fetchrow_hashref   => 'DBI::st::fetchrow_hashref',
	fetchrow_arrayref  => 'DBI::st::fetchrow_arrayref',
	fetchrow_array     => 'DBI::st::fetchrow_array',
	selectall_arrayref => 'DBI::db::selectall_arrayref',
	selectall_hashref  => 'DBI::db::selectall_hashref',
);

sub new {
	my ($class, $args_for) = @_;
	my $self = bless {}, $class;

	if ($args_for) {
		$self->_validate_args($args_for);
	}

	$self->_initialize($args_for);

	return $self;
}

sub _initialize {
	my $self     = shift;
	my $args_for = shift;

	my %args_for = ();
	%args_for = %{$args_for};

	$self->_set_fixtures_file($args_for{file});

	if (my $dbh = $args_for{dbh}) {
		$self->{dbh}         = $dbh;
		$override            = Sub::Override->new();
		$self->{bind_params} = [];
		$self->{override}    = $override;
		$self->_override_dbi_methods();
		$self->{result} = [];
	} elsif (my $fixtures = $args_for{data}) {
		$self->_process_mock_data($fixtures);
		$self->_set_mock_dbh($fixtures);
	} elsif (-e $self->{fixture_file}) {
		my $data = $JSON_OBJ->decode(read_text($self->{fixture_file}));
		$self->_process_mock_data($data);
		$self->_set_mock_dbh($data);
	} else {
		croak 'No mocked data in ' . $self->{fixture_file} . ". Please provide dbh arg to new to generate this\n";
	}

	return $self;
}

sub _set_mock_dbh {
	my ($self, $data) = @_;

	my $dbh = DBI->connect(
		'dbi:Mock:',
		'', '',
		{
			RaiseError => 1,
			PrintError => 0
		}
	);

	my $dbh_session = DBD::Mock::Session->new($PROGRAM_NAME => @{$data});

	$dbh->{mock_session} = $dbh_session;
	$self->{dbh}         = $dbh;

	return $self;
}

sub _override_dbi_methods {
	my $self = shift;

	$self->_override_dbi_execute($MOCKED_DBI_METHODS{execute});
	$self->_override_bind_param($MOCKED_DBI_METHODS{bind_param});
	$self->_override_dbi_fetchrow_hashref($MOCKED_DBI_METHODS{fetchrow_hashref});
	$self->_override_dbi_fetchrow_arrayref($MOCKED_DBI_METHODS{fetchrow_arrayref});
	$self->_override_dbi_fetchrow_array($MOCKED_DBI_METHODS{fetchrow_array});
	$self->_override_dbi_selectall_arrayref($MOCKED_DBI_METHODS{selectall_arrayref});
	$self->_override_dbi_selectall_hashref($MOCKED_DBI_METHODS{selectall_hashref});

	return $self;
}

sub get_dbh {
	my $self = shift;

	return $self->{dbh};
}

sub get_override_object {
	my $self = shift;

	return $self->{override};
}

sub _override_dbi_execute {
	my $self        = shift;
	my $dbi_execute = shift;

	my $orig_execute = \&$dbi_execute;

	$self->get_override_object()->replace(
		$dbi_execute,
		sub {
			my ($sth, @args) = @_;

			my $sql = $sth->{Statement};

			my $col_names  = $sth->{NAME};
			my $retval     = $orig_execute->($sth, @args);
			my $query_data = {
				statement    => $sql,
				bound_params => \@args,
				col_names    => $col_names
			};

			$query_data->{bound_params} = $self->{bind_params}
				if scalar @{$self->{bind_params}} > 0;
			push @{$self->{result}}, $query_data;
			$self->{bind_params} = [];
			return $retval;
		}
	);

	return $self;
}

sub _override_bind_param {
	my $self       = shift;
	my $bind_param = shift;

	my $orig_execute = \&$bind_param;

	$self->get_override_object()->replace(
		$bind_param,
		sub {
			my ($sth, $bind, $val) = @_;

			push @{$self->{bind_params}}, $val;
			my $retval = $orig_execute->($sth, $bind, $val);
			return $retval;
		}
	);


	return $self;
}

sub _override_dbi_fetchrow_hashref {
	my $self             = shift;
	my $fetchrow_hashref = shift;

	my $result = $self->{result};

	my $orig_selectrow_hashref = \&$fetchrow_hashref;

	$self->get_override_object()->replace(
		$fetchrow_hashref,
		sub {
			my ($sth) = @_;

			my $retval = $orig_selectrow_hashref->($sth);

			my $last_index = $#$result;

			if (ref $retval) {
				my $query_results = [];

				foreach my $key (sort keys %{$retval}) {
					push @{$query_results}, $retval->{$key};
				}

				push @{$self->{result}->[$last_index]->{results}}, $query_results;
			}

			return $retval;
		}
	);
}

sub _override_dbi_fetchrow_arrayref {
	my $self              = shift;
	my $fetchrow_arrayref = shift;

	my $result = $self->{result};

	my $orig_selectrow_arrayref = \&$fetchrow_arrayref;

	$self->get_override_object()->replace(
		$fetchrow_arrayref,
		sub {
			my ($sth) = @_;

			my $retval = $orig_selectrow_arrayref->($sth);

			my $last_index = $#$result;
			my @retval     = ();
			if (ref $retval) {
				@retval = @{$retval};
				push @{$self->{result}->[$last_index]->{results}}, \@retval;
			}

			return $retval;
		}
	);
}

sub _override_dbi_fetchrow_array {
	my $self           = shift;
	my $fetchrow_array = shift;

	my $result = $self->{result};

	my $orig_selectrow_array = \&$fetchrow_array;

	$self->get_override_object()->replace(
		$fetchrow_array,
		sub {
			my ($sth) = @_;

			my @retval = $orig_selectrow_array->($sth);

			my $last_index = $#$result;

			if (scalar @retval) {
				push @{$self->{result}->[$last_index]->{results}}, \@retval;
			}

			return @retval;
		}
	);
}

sub _override_dbi_selectall_arrayref {
	my $self               = shift;
	my $selectall_arrayref = shift;

	my $result                  = $self->{result};
	my $orig_selectall_arrayref = \&$selectall_arrayref;

	$self->get_override_object()->replace(
		$selectall_arrayref,
		sub {
			my ($dbh, $sql, $slice, @parmas) = @_;

			my $retval     = $orig_selectall_arrayref->($dbh, $sql, $slice, @parmas);
			my $last_index = $#$result;
			my $data       = [];

			if (ref $retval) {
				my $current_record = $self->{result}->[$last_index];
				my $col_names      = $current_record->{col_names};

				foreach my $row_as_hash (@{$retval}) {
					my $row_as_array = [];
					foreach my $col_name (@{$col_names}) {
						push @{$row_as_array}, $row_as_hash->{$col_name};
					}

					push @{$data}, $row_as_array;
				}
				$self->{result}->[$last_index]->{results} = $data;
			}

			return $retval;
		}
	);

	return $self;
}

sub _override_dbi_selectall_hashref {
	my $self              = shift;
	my $selectall_hashref = shift;

	my $result                 = $self->{result};
	my $orig_selectall_hashref = \&$selectall_hashref;

	$self->get_override_object()->replace(
		$selectall_hashref,
		sub {
			my ($dbh, $statement, $key_field, $attr, @bind_values) = @_;

			my $retval = $orig_selectall_hashref->($dbh, $statement, $key_field, $attr, @bind_values);

			my $last_index     = $#$result;
			my $current_record = $self->{result}->[$last_index];
			my $col_names      = $current_record->{col_names};
			my $mock_data      = [];

			walk sub {
				my $rows = $_;
				if (ref $rows && scalar keys %{$rows} == scalar @{$col_names}) {
					my %data = %$rows;
					push @{$mock_data}, [@data{@{$col_names}}];
				}

				return;
			}, $retval;

			$self->{result}->[$last_index]->{results} = $mock_data;
			return $retval;
		}
	);

	return $self;
}

sub _process_mock_data {
	my ($self, $data) = @_;

	foreach my $row (@{$data}) {
		my $cols = delete $row->{col_names};
		unshift @{$row->{results}}, $cols;
	}


	return $self;
}

sub _set_fixtures_file {
	my $self = shift;
	my $file = shift;

	Readonly::Scalar my $FIXTURE_DIR => 'db_fixtures/';

	if (defined $file) {
		$self->{fixture_file} = $file;
	} else {
		my ($volume, $directory, $test_file) = File::Spec->splitpath($PROGRAM_NAME);
		make_path($directory . $FIXTURE_DIR);
		my $default_fixture_file = $directory . $FIXTURE_DIR . "$test_file.json";
		$self->{fixture_file} = $default_fixture_file;
	}

	return $self;
}

sub _validate_args {
	my $self     = shift;
	my $args_for = shift;

	croak 'arguments to new must be hashref'
		if ref $args_for ne 'HASH';

	Readonly::Hash my %ALLOWED_KEYS => (
		dbh  => 1,
		file => 1,
		data => 1,
	);

	croak 'to many args to new' if scalar keys %{$args_for} > 1;

	foreach my $key (keys %{$args_for}) {
		croak "Key not allowed: $key"
			unless $ALLOWED_KEYS{$key};
	}

	return $self;
}

sub DESTROY {
	my $self = shift;

	return unless defined $self->{result};

	if (scalar @{$self->{result}} > 0) {
		my $json_data    = $JSON_OBJ->encode($self->{result});
		my $fixture_file = $self->{fixture_file};
		my $fh           = IO::File->new($fixture_file, 'w') or croak "cannot open file:$fixture_file  $!\n";
		say $fh $json_data;
		undef $fh;
	}

	return $self;
}

1;