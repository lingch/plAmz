#!/bin/perl
use Test::More;
use TBCsv::PropGenerator;

my $pg = TBCsv::PropGenerator->new("color");

ok($pg);
is($pg->generate(),"1627207:-1000");
is($pg->generate(),"1627207:-1001");
is($pg->generate(),"1627207:-1002");

$pg = TBCsv::PropGenerator->new("size");

ok($pg);
is($pg->generate(),"20518:-1000");
is($pg->generate(),"20518:-1001");
is($pg->generate(),"20518:-1002");

done_testing();
