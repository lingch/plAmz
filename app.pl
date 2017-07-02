#!/usr/bin/perl
package Levis;

use strict;
use LWP::Simple;
use JSON::Parse 'parse_json';

use Error qw(:try);

use Digest::MD5 qw(md5_hex);
use List::Util qw(reduce);

use POSIX;
use utf8;

use File::Path qw(make_path remove_tree);

use Util;
use MyDownloader;
use DBStore;

use Out::Single;
use Out::Group;


require "html_parser.pl";
my $ROOT={
	501=>'https://www.amazon.com/dp/B0018OR118',
	505=>'https://www.amazon.com/dp/B0018OKNWM'
};

my $jo_asin;
my $jo_img;
my $baseRoot = "/var/www/storage";
my $pageSize = 200000;

my $cate = $ARGV[0];
my $operate = $ARGV[1];

# Levis->new()->updateAsinPrice("B0151YZMDO"); 
my $code = 'Levis'->can($operate) or die "operate $operate not found";
Levis->new($cate)->$code(); 

my $temp_filename = "template/data.csv";
sub new{
	my $class = shift;
	my $code = shift;

	my $self = bless {
		store=>undef,
		code=>$code,
		baseLocal=>"$baseRoot/$code"
	}, $class;

	make_path("$self->{baseLocal}/");
	
	$self->{store} = DBStore->new("zbox-desktop",27017,"$code");

	return $self;
}

sub updateAllFromCsv{
	my $self = shift;
	my $items = TBCsv::parse("online.csv");
	my $item = $items->[0] or die "empty csv";

	#delete those I dont want to update from online data
	delete $item->{t_title};
	delete $item->{t_inputPids};
	delete $item->{t_inputValues};
	# delete $item->{t_modified};
	delete $item->{t_price};
	delete $item->{t_num};
	# delete $item->{t_description};

	# delete $item->{color};
	# delete $item->{size};
	# delete $item->{t_description};
	$self->{store}->updateFieldMulti({},$item,{multi=>1});
}



sub loadRoot {
	my $self = shift;

	my $root_url = $ROOT->{$self->{code}} or die "url for $self->{code} is not found";
	
	my $filename = "$self->{code}.html";
	my $document = undef;

	if(defined $root_url && defined $filename){
		print "downloading $self->{code}.html\n";
		$document = MyDownloader->new()->download(url=>$root_url,
			filename=>$filename,
			cache_dir=>".",
			cache_sec=>1000000,
			bytes=>1000000);
	}

	my $jsonstr = getJsonText($document,'var dataToReturn =','return dataToReturn;');
	my $jo_data = parse_json ($jsonstr);
	$jo_asin = $jo_data->{"dimensionValuesDisplayData"};

	$jsonstr = getJsonText($document,'data["colorImages"] = ','data["heroImage"]');
	$jo_img = parse_json ($jsonstr);
}

sub initBasic{
	my $self = shift;

	$self->loadRoot();

	our $jo_root = transform2Flat($jo_asin);

	my $defJson = Util::readFileJson("tbDefault.json") ;
	$self->{store}->updateFieldAll($defJson);

	my $n=0; 
	for my $item ( @{$jo_root}){
		print "init $item->{asin}, $item->{color}, $item->{size}\n";
		$self->{store}->updateFieldItem($item);
	}
}

sub updatePrice {
	my $self = shift;

	$self->loadRoot();

	my $items = $self->{store}->getItemsAll();

	for my $item (@{$items}){
		delete $item->{_id};
		$self->updateAsinPrice($item);
	}
}

sub updateAsinPrice {
	my $self = shift;

	my $item = shift;
	
	try{
		$self->handle_size($item,1000000);
	}catch Error with{
		my $ex = shift;
		print $ex->text . "\n";
		$item->{datetime} = Util::genTimestamp();
		$item->{count} = 0;
		$item->{err} = 1;
		$item->{err_msg} = $ex->text;
		$self->{store}->updateFieldItem($item);
	}
	
}

sub extraData{
	my $self = shift;

	my $items = $self->{store}->getItemsAll();

	my $out = Out::Group->new($self->{code});

	$out->extra($items);
}

sub downloadImgs{
	my $self = shift;
	my $color = shift;
	my $path = shift;

	my $imgs = $jo_img->{$color};
	my $img_local = [];
	my $img_remote = [];
	my $c = 1;
	for (@{$imgs}){
		my $imgObj = $_;
		my $imgL = $imgObj->{hiRes} || $imgObj->{large};
		next if ! defined $imgL;

		my $ext = substr($imgL,rindex($imgL,".")+1);
		my $filename_local = "$c.$ext";
		my $fullpath = "$path/$filename_local";
		#print "\tretrieving $filename_local\r\n";
		
		MyDownloader->new()->download(url=>$imgL,
			filename=>$fullpath,
			cache_dir=>"$self->{baseLocal}/cache_img",
			cache_sec=>10000000);

		push @{$img_local}, $fullpath;
		push @{$img_remote}, $imgL;
		
		$c++;
	}
	return ($img_local,$img_remote);
}

sub handle_size{
	my $self = shift;
	my $jo = shift;
	my $cacheSec = shift;

	my $asin = $jo->{asin};
	my $color = $jo->{color};

	my $size_p =  Util::normalizePath($jo->{size});
	my $color_p = Util::normalizePath($color);

	my $base_url = "http://14.155.17.64:81";
	my $path = "$color_p/$size_p";
	make_path( "$self->{baseLocal}/$path/");

	$jo->{color_p} = $color_p;
	$jo->{size_p} = $size_p;

	print "retrieving $jo->{datetime}, $asin, $color, $jo->{size}\r\n";

	my $filename = "$self->{baseLocal}/$path/page.html";

	my $suburl = "https://www.amazon.com/dp/$asin?psc=1";
	my $d = MyDownloader->new();
	try{
		my $content = $d->download(url=>$suburl,
			filename=>$filename,
			cache_dir=>"$self->{baseLocal}/cache_page",
			cache_sec=>$cacheSec,
			bytes=>$pageSize);
		
		$jo->{filename} = $filename;
		$jo->{filename_cache} = $d->{filename_cache};
		$jo->{title}=getTitle($content);
		
		$jo->{price}=getPrice($content);

		# my $rat = 7.0;
		# $jo->{t_price}=ceil($jo->{price} * $rat);

		$jo->{list_price}=getListPrice($content);
		$jo->{list_price} = $jo->{price} if ! defined $jo->{list_price};
		
		($jo->{imgs_local},$jo->{imgs_remote}) = $self->downloadImgs($color,"$self->{baseLocal}/$path");

		$jo->{datetime} = Util::genTimestamp();
		$jo->{err} = 0;
		$jo->{err_msg} = '';

		$self->{store}->updateFieldItem($jo);
	}catch Error with{
		my $ex = shift;
		#$d->clearCache();
		$ex->throw;
	};
	
	return $jo;
}

sub transform2Flat{
	my $jo_asin = shift;

	my $jo = [];
	for my $asin ( keys %{$jo_asin}){
		my $color = $jo_asin->{$asin}->[1];
		my $size = $jo_asin->{$asin}->[0];

		my ($w,$l) = $size =~ m/(\d+)W x (\d+)L/;
		next unless defined $w and defined $l;

		my $item = {};
		$item->{asin}=$asin;
		$item->{color}=$color;
		$item->{size}=$size;
		$item->{w}=$w;
		$item->{l}=$l;
		$item->{count}=1;

		push @{$jo}, $item;
	}

	return $jo;
}

1;

__END__

