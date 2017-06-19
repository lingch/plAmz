package Translate;

use strict;

sub new {
	my $class = shift;
	my $filename = shift;

	my $self = bless {
		dict=>undef,
		filename=>undef
	},$class;

	$self->readDict($filename) if defined $filename;

	return bless $self,$class;
}

sub readDict {
	my $self = shift;
	my $filename = $self->{filename} = shift;

	open FILE, "<$filename" or die "failed to open $filename";
	my $dict = {};
	while (my $line = <FILE>){
		chomp($line);
		my ($key,$value) = split(/,/,$line);
		$dict->{$key} = $value;
	}
	close FILE;
	$self->{dict} = $dict;
}

sub translate{
	my $self = shift;
	die "dict not read" unless defined $self->{dict};

	my $dict = $self->{dict};

	my $str = shift;

	for my $key (keys %{$dict}){
		$str =~ s/^$key$/$dict->{$key}/g;
	}

	return $str;
}

1;


__END__

