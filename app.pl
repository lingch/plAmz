#!/usr/bin/perl

use LWP::Simple;
use JSON::Parse 'parse_json';
use LWP::UserAgent;

require "util.pl";

my $url = 'https://www.amazon.com/dp/B0018OR118';
my $filename = 'data/root.html';
my $document = undef;

if(defined $url && defined $filename){
	$document = download(url=>$url,filename=>$filename,mtime_threshold=>100000);
}

my $markStart = 'var dataToReturn =';
my $index1 = index($document, $markStart);
if($index1 < 0){
	print "error1";
}

$index2 = index($document, 'return dataToReturn;');
if($index2 < 0){
	print "error2";
}

$jsonstr = substr($document,$index1 + length($markStart),$index2-$index1);

$index2 = rindex($jsonstr, ';');
if($index2 < 0){
	print "error2";
}
$jsonstr = substr($jsonstr,0,$index2);

$jsonstr =~ s/(,\s*])/]/g;
$jsonstr =~ s/(,\s*})/}/g;

my $json = parse_json ($jsonstr);
my $data = $json->{"dimensionValuesDisplayData"};

for (keys %{$data}){
	my $asin = $_;
	$asin = 'B0018ON6XA';
	my $dir = "data/$asin";
	my $filename = "$dir/page.html";

	mkdir $dir;

	my $suburl = "https://www.amazon.com/dp/$asin";
	my $content = download(url=>$suburl,
		filename=>$filename,
		mtime_threshold=>100000,
		bytes=>600000);
	
	my $title = getNodeText($content,nodename=>"span",nodeid=>"productTitle");
	my $list_price = getNodeText($content,nodename=>"span",leading_str=>"List Price:",nodeclass=>"a-text-strike");
	my $price = getNodeText($content,nodename=>"span",nodeid=>"priceblock_ourprice");
	my $size = ${$data}{size};
}

sub getNodeText{
	my $content = shift;
	my %args = @_;
	my $nodename = $args{nodename} || die "nodename is required";
	my $nodeid = $args{nodeid};
	my $nodeclass = $args{nodeclass};
	my $leading_str = $args{leading_str};

	my $idxStart = 0;
	if(defined $leading_str){
		$idxStart = index($content,"$leading_str");
		throw Exception("leading_str $leading_str not found") if $idxStart < 0;
	}

	if(defined $nodeid){
		$idxStart = index($content,"<$nodename id=\"$nodeid\"",$idxStart);
		throw Exception("node $nodename with id $nodeid not found") if $idxStart < 0;
	}else{
		if(defined $nodeclass){
			$idxStart = index($content,"<$nodename class=\"$nodeclass\"",$idxStart) || die "";
			throw Exception("node $nodename with class $nodeclass not found") if $idxStart < 0;
		}
	}

	$idxStart = index($content,">", $idxStart);
	throw Exception("closing of node $nodename with id $nodeid not found") if $idxStart < 0;
	$idxStart = $idxStart + 1;

	my $idxEnd = index($content,"</$nodename>", $idxStart);
	throw Exception("end mark of node $nodename with id $nodeid not found") if $idxEnd < 0;
	$idxEnd = $idxEnd - 1;

	my $res = substr($content, $idxStart, $idxEnd - $idxStart + 1);
	return $res;

}


