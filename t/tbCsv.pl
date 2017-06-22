#!/bin/perl
use Test::More;
use TBCsv;

my $csv = TBCsv->new();

ok($csv);
ok(TBCsv::parse("data.csv"));

done_testing();
