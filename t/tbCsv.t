#!/bin/perl
use Test::More;
use TBCsv;

use DBStore;

my $csv = TBCsv->new();
ok($csv);

ok($items = TBCsv::parse("data.csv"));
ok($items);

my $db = DBStore->new('localhost',27017);
ok($db);

my $items = $db->getItemsFilter({t_price=>350});
ok($items);

my $lines = $csv->stringify($items);
ok($lines);


done_testing();

