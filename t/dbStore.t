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

# $item = { t_description=>"<p><img src=\"https://img.alicdn.com/imgextra/i1/59667328/TB24UXStY8kpuFjy0FcXXaUhpXa_!!59667328.jpg\"></p><p><img src=\"https://img.alicdn.com/imgextra/i1/59667328/TB20VZYtNXkpuFjy0FiXXbUfFXa_!!59667328.jpg\"></p>"};
# $store->updateFieldAll($item);

done_testing();

