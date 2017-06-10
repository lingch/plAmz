#!/usr/bin/perl

use LWP::Simple;
use JSON::Parse 'parse_json';
use LWP::UserAgent;
use Error qw(:try);

use Text::Template;

use File::Path qw(make_path remove_tree);

require "util.pl";

my $url = 'https://www.amazon.com/dp/B0018OR118';
my $filename = 'root.html';
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

sub genDataPack{
	my ($temp_filename, $out_filename) = @_;

	my $template = Text::Template->new(SOURCE => $temp_filename)
	or die "Couldn't construct template: $Text::Template::ERROR";

	my $result = $template->fill_in() or die $Text::Template::ERROR;

	writeFile($result,$out_filename);
}

sub handle_asin{
	my $jo_asin = shift;
	my $jo_img = shift;
	our $asin = shift;

	our $size =  $jo_asin->{$asin}[0];
	our $color = $jo_asin->{$asin}[1];
	our $size_p =  $size;
	our $color_p = $color;
	$color_p =~ s/\s+/-/g;
	$size_p =~ s/\s+/-/g;
	my $base_local = "/var/www/storage";
	my $base_url = "http://14.155.17.64:81";
	my $path = "$color_p/$size_p";

	make_path( "$base_local/$path/");

	print "retrieving $asin: $color, $size\r\n";
	#$asin = 'B0151Z1DIG';

	my $filename = "$base_local/$path/page.html";

	my $suburl = "https://www.amazon.com/dp/$asin?psc=1";
	my $content = download(url=>$suburl,
		filename=>$filename,
		mtime_threshold=>100000,
		bytes=>1000000);
	
	our $title = getNodeText($content,nodename=>"span",nodeid=>"productTitle");
	throw Error::Simple("title not found") if ! defined $title;
	$title = trim($title);
	
	our $price = getNodeText($content,nodename=>"span",nodeid=>"priceblock_dealprice");
	$price = getNodeText($content,nodename=>"span",nodeid=>"priceblock_ourprice") if ! defined $price;
	$price = getNodeText($content,nodename=>"span",nodeid=>"priceblock_saleprice") if ! defined $price;
	throw Error::Simple("price not found") if ! defined $price;
	$price = trim($price);
	$price =~ s/^\$//g;
	our $rat = 7.0;
	our $price_cny = $price * $rat;

	our $list_price = getNodeText($content,nodename=>"span",leading_str=>"List Price:",nodeclass=>"a-text-strike");
	$list_price = getNodeText($content,nodename=>"span",leading_str=>"Was:",nodeclass=>"a-text-strike") if ! defined($list_price);
	$list_price = $price if ! defined $list_price;
	
	our $imgs = $jo_img->{$color};
	our @img_local = ();
	my $c = 1;
	for (@{$imgs}){
		my $imgObj = $_;
		my $imgL = $imgObj->{hiRes} || $imgObj->{large};

		next if ! defined $imgL;

		my $ext = substr($imgL,rindex($imgL,".")+1);
		my $filename_local = "$c.$ext";
		print "\tretrieving $c.$ext\r\n";
		download(url=>$imgL,filename=>"$base_local/$path/$filename_local",mtime_threshold=>100000);
		push @img_local, "$base_url/$path/$filename_local";
		$c++;
	}

	genDataPack("template.csv","out.csv");
}


my $jsonstr = getJsonText($document,'var dataToReturn =','return dataToReturn;');
my $jo_data = parse_json ($jsonstr);
my $jo_asin = $jo_data->{"dimensionValuesDisplayData"};

$jsonstr = getJsonText($document,'data["colorImages"] = ','data["heroImage"]');
my $jo_img = parse_json ($jsonstr);



for (keys %{$jo_asin}){
	my $asin = $_;
	
	try {
		handle_asin($jo_asin,$jo_img, $asin);
	}
	catch Error with {
		my $ex = shift;
		print "failed: " . $ex->text . " \r\n";
	};

	last;
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
		return undef if $idxStart < 0;
	}

	if(defined $nodeid){
		$idxStart = index($content,"<$nodename id=\"$nodeid\"",$idxStart);
		return undef if $idxStart < 0;
	}else{
		if(defined $nodeclass){
			$idxStart = index($content,"<$nodename class=\"$nodeclass\"",$idxStart) || die "";
			return undef if $idxStart < 0;
		}
	}

	$idxStart = index($content,">", $idxStart);
	return undef if $idxStart < 0;
	$idxStart = $idxStart + 1;

	my $idxEnd = index($content,"</$nodename>", $idxStart);
	return undef if $idxEnd < 0;
	$idxEnd = $idxEnd - 1;

	my $res = substr($content, $idxStart, $idxEnd - $idxStart + 1);
	return $res;
}


