#!/bin/perl


use DBStore;

my $store = DBStore->new("zbox-desktop",27017);

testUpdatePrice();

sub testAdd {
	my $obj = {asin=>"asin123",hello=>"world", myname=>["chen","yu","ling"]};
	# $store->add($obj);

	$obj->{hello}="world2";
	$store->update($obj);

}

sub testUpdatePrice {
	$store->updatePrice(\&printAsin);
}
sub printAsin{
	my $item = shift;

	print $item->{asin};
}