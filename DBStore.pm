package DBStore;

use strict;

use MongoDB ();
use Data::Dumper qw(Dumper);

sub new {
	my $class = shift;
	my $host= shift;
	my $port = shift;

	my $self = bless {
		client=>undef,
		db=>undef,
		dbName => 'AMZ',
		collectionName => 'Levis'
	}, $class;

	$self->open($host,$port) if defined $host and defined $port;

	return $self;
}

sub open {
	my $self = shift;
	my $host = shift;
	my $port = shift;

	$self->{client} = MongoDB::MongoClient->new(host => $host, port => $port);
	$self->{db}   = $self->{client}->get_database( $self->{dbName}  );
}

sub add {
	my $self = shift;
	my $item = shift;

	my $collection = $self->{db}->get_collection($self->{collectionName}) 
		or die "collection $self->{collectionName} not found";

	my $res = $collection->insert_one( $item );
	throw Error::Simple("insert failed") if ! $res->acknowledged;

	return $res->inserted_id->{value};
}

sub update {
	my $self = shift;
	my $item = shift;

	my $coll = $self->{db}->get_collection($self->{collectionName}) 
	or die "coll $self->{collectionName} not found";

	my $res = $coll->replace_one ( {asin=>$item->{asin}}, 
		$item,
		{upsert=>1} 
		);

	return $res;
}

sub updatePrice {
	my $self = shift;
	my $item = shift;

	my $coll = $self->{db}->get_collection($self->{collectionName}) 
	or die "coll $self->{collectionName} not found";

	my $res = $coll->replace_one ( {asin=>$item->{asin}}, 
		{'$set' => {price_cny => $item->{price_cny}}},
		{upsert=>1} 
		);

	return $res;
}

# sub drop{
# 	my $self = shift;

# 	$self->{db}->drop();
# }

1;

__END__

