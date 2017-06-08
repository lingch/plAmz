#!/usr/bin/perl

use LWP::Simple;
use JSON::Parse 'parse_json';
use LWP::UserAgent;
use Error;

use File::Path qw(make_path remove_tree);

require "util.pl";

my $url = 'https://www.amazon.com/dp/B0018OR118';
my $filename = 'data/root.html';
my $document = undef;

if(defined $url && defined $filename){
	$document = download(url=>$url,filename=>$filename,mtime_threshold=>100000,bytes=>1000000);
}

sub getJsonText{
	my $document =shift;
	my $markStart = shift;
	my $markEnd = shift;

	my $idxStart = index($document, $markStart);
	throw Exception("start mark $markStart not found") if $idxStart < 0;
	$idxStart = $idxStart + length($markStart);

	my $idxEnd = index($document, $markEnd,$idxStart);
	throw Exception("end mark $markEnd not found") if $idxEnd < 0;

	$idxEnd = rindex($document, ';',$idxEnd);
	throw Exception("; before end mark $markStart not found") if $idxEnd < 0;

	$jsonstr = substr($document,$idxStart,$idxEnd-$idxStart);

	$jsonstr =~ s/(,\s*])/]/g;
	$jsonstr =~ s/(,\s*})/}/g;

	return $jsonstr;

}


my $jsonstr = getJsonText($document,'var dataToReturn =','return dataToReturn;');
my $jo_data = parse_json ($jsonstr);
my $jo_asin = $jo_data->{"dimensionValuesDisplayData"};

$jsonstr = getJsonText($document,'data["colorImages"] = ','data["heroImage"]');
my $jo_img = parse_json ($jsonstr);

my $dir = "data";
mkdir $dir;
for (keys %{$jo_asin}){
	my $asin = $_;
	print "retrieving $asin\r\n";
	#$asin = 'B0151Z1DIG';
	my $filename = "$dir/page.html";

	my $suburl = "https://www.amazon.com/dp/$asin?psc=1";
	my $content = download(url=>$suburl,
		filename=>$filename,
		#mtime_threshold=>100000,
		bytes=>1000000);
	
	my $title = getNodeText($content,nodename=>"span",nodeid=>"productTitle");
	my $list_price = getNodeText($content,nodename=>"span",leading_str=>"List Price:",nodeclass=>"a-text-strike");
	my $price = getNodeText($content,nodename=>"span",nodeid=>"priceblock_dealprice");
	my $size =  $jo_asin->{$asin}[0];
	my $color = $jo_asin->{$asin}[1];
	
	my $size_p =  $size;
	my $color_p = $color;

	$color_p =~ s/\s+/-/g;
	$size_p =~ s/\s+/-/g;

	my $asin_dir = "$dir/$color_p/$size_p";
	make_path( "$asin_dir/");

	my $imgs = $jo_img->{$color};

	my $c = 1;
	for (@{$imgs}){
		my $imgObj = $_;
		my $imgL = $imgObj->{hiRes} || $imgObj->{large};

		next if ! defined $imgL;

		my $ext = substr($imgL,rindex($imgL,".")+1);
		print "\tretrieving $c.$ext\r\n";
		download(url=>$imgL,filename=>"$asin_dir/$c.$ext",mtime_threshold=>100000);
		$c++;
	}

	#last;
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


