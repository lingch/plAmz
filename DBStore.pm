package DBStore;

use strict;
use utf8;

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
# $MongoDB::BSON::utf8_flag_on = 1;
	$self->{client} = MongoDB::MongoClient->new(host => $host, port => $port);
	$self->{db}   = $self->{client}->get_database( $self->{dbName}  );
}

# sub add {
# 	my $self = shift;
# 	my $item = shift;

# 	my $collection = $self->{db}->get_collection($self->{collectionName}) 
# 		or die "collection $self->{collectionName} not found";

# 	my $res = $collection->insert_one( $item );
# 	throw Error::Simple("insert failed") if ! $res->acknowledged;

# 	return $res->inserted_id->{value};
# }

sub update {
	my $self = shift;
	my $item = shift;

	my $coll = $self->{db}->get_collection($self->{collectionName}) 
	or die "coll $self->{collectionName} not found";

	my $res = $coll->replace_one ( {asin=>$item->{asin}}, 
		$item,
		{upsert=>1} 
		);

	# my $t = $coll->find_one({asin=>$item->{asin}});

	return $res;
}

sub updateField {
	my $self = shift;
	my $item = shift;

	my $coll = $self->{db}->get_collection($self->{collectionName}) 
	or die "coll $self->{collectionName} not found";

	$coll->update({asin=>$item->{asin}}, {'$set'=>$item});
}

sub getAllItems {
	my $self = shift;

	my $coll = $self->{db}->get_collection($self->{collectionName}) 
	or die "coll $self->{collectionName} not found";

	my $ret = [];
	my $cursor = $coll->find({})->sort({datetime=>1});
	while (my $obj = $cursor->next) {
	    push @{$ret}, $obj;
	}

	return $ret;
}

sub getItem {
	my $self = shift;
	my $filter = shift;

	my $coll = $self->{db}->get_collection($self->{collectionName}) 
	or die "coll $self->{collectionName} not found";

	my $ret = [];
	my $item = $coll->find_one($filter);
	return $item;
}

1;

__END__

