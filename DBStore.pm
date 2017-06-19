package DBStore;

use strict;

use MongoDB ();
use Data::Dumper qw(Dumper);

sub new {
	my $class;
	my $host= shift;
	my $port = shift;

	my $self = bless {
		client=>undef,
		db=>undef,
		collectionName => 'Levis'
	}, $class;

	$self->open($host,$port) if defined $host and defined $port;

	return $self;
}

sub open {
	my $self = shift;
	my $host = shift;
	my $port = shift;

	$self->{client} = MongoDB::MongoClient->new(host => 'localhost', port => 27017);
	$self->{db}   = $self->{client}->get_database( 'example_' . $$ . '_' . time  );
}

sub update {
	my $self = shift;
	my $item = shift;

	my $collection = $db->get_collection($self->{collectionName}) 
	or die "collection $self->{collectionName} not found";

	my $data = $collection->find_one({ _id => $result->inserted_id });
	if(defined $data){
		#update
	
	}else{
		#insert
		$people_coll->insert( $item);
	}
}

