package TBCsv::PropGenerator;

our %TYPE_MAP = (
		color=>1627207,
		size=>20518
	);

sub new {
	my $class = shift;
	my $type = shift;
	my $seed = shift;

	my $type_num = %TBCsv::PropGenerator::TYPE_MAP{$type};
	$type_num = 0 unless defined $type_num;
	$seed = -1000 unless defined $seed;

	$class = ref $class if ref $class;
	my $self = bless {
		type=>$type,
		type_num =>$type_num,
		seed=>$seed
		}, $class;
	$self;
}

sub generate {
	my $self = shift;

	my $ret = "$self->{type_num}:$self->{seed}";

	$self->{seed} -= 1;

	return $ret;
}


1;


