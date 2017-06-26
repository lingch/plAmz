package DBStore;

use strict;
use utf8;

use MongoDB ();
use Data::Dumper qw(Dumper);

my $BASIC_PROJ = {
	asin=>1,
	color=>1,
	size=>1,
	price=>1,
	datetime=>1
};

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

sub updateFieldMulti {
	my $self = shift;
	my $filter = shift;
	my $item = shift;

	my $coll = $self->{db}->get_collection($self->{collectionName}) 
	or die "coll $self->{collectionName} not found";

	$coll->update($filter, {'$set'=>$item},{multi=>1});
}

sub updateFieldAll {
	my $self = shift;
	my $item = shift;

	my $coll = $self->{db}->get_collection($self->{collectionName}) 
	or die "coll $self->{collectionName} not found";

	$coll->update({}, {'$set'=>$item},{multi=>1});
}

sub updateFieldItem {
	my $self = shift;
	my $item = shift;

	my $coll = $self->{db}->get_collection($self->{collectionName}) 
	or die "coll $self->{collectionName} not found";

	$coll->update({asin=>$item->{asin}}, {'$set'=>$item});
}

sub getItemsAllBasic {
	my $self = shift;

	return $self->getItemsFilter({},$BASIC_PROJ);
}

sub getItemsAll {
	my $self = shift;

	return $self->getItemsFilter({},{});
}

sub getItemsFilter {
	my $self = shift;
	my $filter = shift;
	my $projection = shift;

	my $coll = $self->{db}->get_collection($self->{collectionName}) 
	or die "coll $self->{collectionName} not found";

	my $ret = [];
	my $cursor = $coll->find($filter,{projection =>$projection})->sort({datetime=>1});
	while (my $obj = $cursor->next) {
	    push @{$ret}, $obj;
	}

	return $ret;
}

1;

__END__

