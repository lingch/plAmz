#!/usr/bin/perl

use LWP::Simple;
use JSON::Parse 'parse_json';
use LWP::UserAgent;
use Error qw(:try);

use Data::GUID;
use Digest::MD5 qw(md5_hex);
use Text::Template;

use File::Path qw(make_path remove_tree);

require "util.pl";

my $url = 'https://www.amazon.com/dp/B0018OR118';
my $filename = 'root.html';
my $document = undef;

if(defined $url && defined $filename){
	$document = download(url=>$url,filename=>$filename,mtime_threshold=>100000,bytes=>1000000);
}

my $jsonstr = getJsonText($document,'var dataToReturn =','return dataToReturn;');
my $jo_data = parse_json ($jsonstr);
my $jo_asin = $jo_data->{"dimensionValuesDisplayData"};

$jsonstr = getJsonText($document,'data["colorImages"] = ','data["heroImage"]');
my $jo_img = parse_json ($jsonstr);

our $jo_root = restructure($jo_asin);

for my $color ( sort keys %{$jo_root}){
	
	$jo_root->{$color} = handle_color($jo_root->{$color},$color);

	last;
}

genDataPack("template.csv","Black");


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
	my ($temp_filename, $color) = @_;

	make_path( "$color");
	our $jo_color = $jo_root->{$color};
	# $jo_color->{hello} = "world";
	for my $jo_size (values %{$jo_color}){
		# $jo_size->{nihao} = "shijie";
		next unless defined $jo_size->{imgs_local};
		for (my $i = 0; $i < scalar(@{$jo_size->{imgs_local}}); $i++) {
			my $hash = md5_hex($jo_size->{imgs_remote}->[$i]);
		    link $jo_size->{imgs_local}->[$i],"$color/$hash.tbi";
		    $jo_size->{imgs_local}->[$i] = "$hash";
		}
	}
	our $jo_size = $jo_color->{"30W x 29L"};

	my $template = Text::Template->new(SOURCE => $temp_filename)
	or die "Couldn't construct template: $Text::Template::ERROR";

	my $result = $template->fill_in() or die $Text::Template::ERROR;

	writeFile($result,"$color.csv");
}

sub getPrice{
	my $content = shift;

	my $price = getNodeText($content,nodename=>"span",nodeid=>"priceblock_dealprice");
	$price = getNodeText($content,nodename=>"span",nodeid=>"priceblock_ourprice") if ! defined $price;
	$price = getNodeText($content,nodename=>"span",nodeid=>"priceblock_saleprice") if ! defined $price;
	throw Error::Simple("price not found") if ! defined $price;
	$price = trim($price);
	$price =~ s/^\$//g;

	return $price;
}

sub getTitle{
	my $content = shift;

	my $title = getNodeText($content,nodename=>"span",nodeid=>"productTitle");
	throw Error::Simple("title not found") if ! defined $title;
	$title = trim($title);

	return $title;
}

sub getListPrice{
	my $content = shift;

	my $list_price = getNodeText($content,nodename=>"span",leading_str=>"List Price:",nodeclass=>"a-text-strike");
	$list_price = getNodeText($content,nodename=>"span",leading_str=>"Was:",nodeclass=>"a-text-strike") if ! defined($list_price);

	$list_price = trim($list_price);

	return $list_price;
}

sub handle_size{
	my $jo = shift;

	my $color = shift;
	my $size =  shift;
	my $asin = $jo->{asin};

	my $size_p =  $size;
	my $color_p = $color;
	$color_p =~ s/\s+/-/g;
	$size_p =~ s/\s+/-/g;
	my $base_local = "/var/www/storage";
	my $base_url = "http://14.155.17.64:81";
	my $path = "$color_p/$size_p";
	make_path( "$base_local/$path/");

	$jo->{color_p} = $color_p;
	$jo->{size_p} = $size_p;

	print "retrieving $asin: $color, $size\r\n";
	#$asin = 'B0151Z1DIG';

	my $filename = "$base_local/$path/page.html";

	my $suburl = "https://www.amazon.com/dp/$asin?psc=1";
	my $content = download(url=>$suburl,
		filename=>$filename,
		mtime_threshold=>100000,
		bytes=>1000000);
	
	
	$jo->{title}=getTitle($content);
	
	$jo->{price}=getPrice($content);

	my $rat = 7.0;
	$jo->{price_cny}=$jo->{price} * $rat;

	$jo->{list_price}=getListPrice($content);
	$jo->{list_price} = $jo->{price} if ! defined $jo->{list_price};
	
	our $imgs = $jo_img->{$color};
	my $img_local = [];
	my $img_remote = [];
	my $c = 1;
	for (@{$imgs}){
		my $imgObj = $_;
		my $imgL = $imgObj->{hiRes} || $imgObj->{large};
		next if ! defined $imgL;

		my $imgNameHash = md5_hex($imgL);
		my $imgNameHashFilename = "$base_local/$imgNameHash";
		unless (-e $imgNameHashFilename) {
			my $ext = substr($imgL,rindex($imgL,".")+1);
			my $filename_local = "$c.$ext";
			my $fullpath = "$base_local/$path/$filename_local";
			print "\tretrieving $filename_local\r\n";
			
			download(url=>$imgL,filename=>$fullpath,mtime_threshold=>100000);

			link $fullpath,$imgNameHashFilename;
		}

		push $img_local, $imgNameHashFilename;
		push $img_remote, $imgL;
		
		$c++;
	}
	$jo->{imgs_local} = $img_local;
	$jo->{imgs_remote} = $img_remote;

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
	$jo->{datetime} = sprintf ("%d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec);

	return $jo;
}


sub restructure{
	my $jo_asin = shift;

	my $jo = {};
	for my $asin ( keys %{$jo_asin}){
		my $color = $jo_asin->{$asin}->[1];
		my $size = $jo_asin->{$asin}->[0];

		if(index($size,'W') < 0 or index($size,'L') < 0){
			next;	#skip unusual size
		}


		if (! defined $jo->{$color}) {
			$jo->{$color} = {};
		}

		if (! defined $jo->{$color}->{$size}) {
			$jo->{$color}->{$size} = {};
		}

		$jo->{$color}->{$size}->{asin}=$asin;
	}

	return $jo;
}


sub handle_color{
	my $jo_color = shift;
	my $color = shift;
	my $c = 0;
	for my $size (sort keys %{$jo_color}){
		try {
			$jo_color->{$size} = handle_size($jo_color->{$size},$color,$size);
			$c += 1;
		}
		catch Error with {
			my $ex = shift;
			print "failed: " . $ex->text . " \r\n";
		};

		last if $c == 5;
	}

	return $jo_color;
}

sub getNodeTextEx{
	my $content = shift;
	my %args = @_;
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



