#!/bin/perl
use Test::More;
use TBCsv::PropGenerator;

use DBStore;

my $store = DBStore->new("zbox-desktop",27017);
ok($store);



my $obj = {asin=>"asin123",hello=>"world", myname=>["chen","yu","ling"]};
ok($store->update($obj));

my $items = $store->getItemsFilter({asin=>'asin123'});
ok($items);

$items = $store->getItemsAll();
ok($items);

done_testing();

