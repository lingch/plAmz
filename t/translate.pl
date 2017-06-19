#!/usr/bin/perl

use Translate;

my $trans = Translate->new();
$trans->readDict("dict.txt");

print "Dark Blue -> ". $trans->translate("Dark Blue") . "\n";

my $trans2 = Translate->new("dict.txt");
print "Dark Blue -> ". $trans2->translate("Dark Blue") . "\n";

