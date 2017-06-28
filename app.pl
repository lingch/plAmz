﻿#!/usr/bin/perl
package Levis;

use strict;
use LWP::Simple;
use JSON::Parse 'parse_json';

use Error qw(:try);

use Digest::MD5 qw(md5_hex);
use Text::Template;
use POSIX;
use utf8;

use File::Path qw(make_path remove_tree);

use Util;
use MyDownloader;
use DBStore;
use TBCsv;

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
		$self->handle_size($item,100000);
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

	my $itemsTree = $self->transform2Tree($items);

	for my $color (sort keys %{$itemsTree}){
		for my $price (sort keys %{$itemsTree->{$color}}){
			$itemsTree->{$color}->{$price} = merge_w($itemsTree->{$color}->{$price});
		}
		$self->genDataPack($itemsTree->{$color},$color);
	}
}

sub genDataPack{

	my $self = shift;
	our ( $jo, $color) = @_;
	my $prefix = $self->{code};
	my $color_p = Util::normalizePath($color);

	# $jo_color_w->{hello} = "world";
	my $csv = TBCsv->new();
	for our $price (keys %{$jo}){
		our $jo_price = $jo->{$price};

		make_path( "$prefix/$color_p/$price");

		for my $w (keys %{$jo_price}){
			my $w_p = Util::normalizePath($w);
			make_path( "$prefix/$color_p/$price/$w_p/");

			#transfer imgs_local to t_picture
			my $item_0 = $jo_price->{$w}->[0];
			my $t_picture = "";
			#skip those no picture?
			next unless defined $item_0->{imgs_local} and scalar(@{$item_0->{imgs_local}})>0;
			for (my $i = 0; $i < scalar(@{$item_0->{imgs_local}}); $i++) {
				my $hash = md5_hex($item_0->{imgs_remote}->[$i]);
				$t_picture .= "$hash:1:$i:|;";
			    link $item_0->{imgs_local}->[$i],"$prefix/$color_p/$price/$w_p/$hash.tbi";
			    $item_0->{imgs_local}->[$i] = "$hash";
			}
			$jo_price->{$w}->[0]->{t_picture} = $t_picture;

			my $lines = $csv->stringify($jo_price->{$w},$w);

			Util::writeFile($lines,"$prefix/$color_p/$price/$w_p.csv");
		}

		# open F,"<:utf8",$temp_filename or die "cannot open template file $temp_filename";
		# my $template = Text::Template->new(TYPE => 'FILEHANDLE', SOURCE=> \*F)
		# 	or die "Couldn't construct template: $Text::Template::ERROR";

		# my $result = $template->fill_in() or die $Text::Template::ERROR;

		# Util::writeFile($result,"$prefix/$color_p/$price.csv");
	}
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


sub arr_count{
	my $a1 = shift;
	my $a2 = shift;

	return scalar(@{$a1}) + scalar(@{$a2});
}

sub check_merge{
	my $jo = shift;
	my $marked = shift;
	my $toMerge = shift;

	return 0 if length($marked) > 10;

	if(arr_count($jo->{$marked},$jo->{$toMerge}) <= 24){
		return 1;
	} else{
		return 0;
	}
}

# sub splitByPrice{
# 	my $w = shift;
# 	my $from = 0;
# 	my $ret = [];
# 	for (my $i=0;$i<scalar(@{$w});$++){
# 		next if($w->[$i]->{t_price} == $w->[$from]->{t_price});
# 		push @{$ret}, $w->[$from..$i]; 
# 	}

# 	return $ret;
# }

# sub merge_l {
# 	my $jo = shift;
# 	my $ls = shift;

# 	my $marked = undef;
# 	for my $l (@{$ls}){
# 		unless(defined $marked){
# 			$marked = $current;
# 			next;
# 		}

# 		if(check_merge($jo,$marked,$current)){
# 			#merge
# 			my $newkey .= "/$current";
# 			$jo->{$newkey} = [ @{$jo->{$marked}},@{$jo->{$current}}];
# 			delete $jo->{$marked};
# 			delete $jo->{$current};
# 			$marked = $newkey;
# 			next;
# 		}else{
# 			#set new $marked
# 			$marked = $current;
# 		}	
# 	}
# }
sub merge_w{
	my $jo = shift;

	my $priceHash={};
	my $mergePoint = undef;
	for my $w (sort keys %{$jo}){
		unless (defined $mergePoint) {
			$mergePoint = $w;
			next;
		}

		my $n = scalar(@{$jo->{$w}});
		if($n > 24){
			#split
			my $piece = ceil($n / 24);
			my $step = ceil($n / $piece);
			my $i = 0;
			for ($i = 0; $i < $piece-1; $i++) {
				$jo->{"w_$i"} = $jo->{$w}->[$i*$step..($i+1)*$step-1];
			}
			$jo->{"w_$i"} = $jo->{$w}->[$i*$step..-1];
			delete $jo->{$w};
		}else{
			

			if(! check_merge($jo,$mergePoint,$w)){
				$mergePoint = $w;
				next;
			}

			my $newkey = "$mergePoint";
			$newkey .= " $w" if index($mergePoint,$w) < 0;
			my $tmp = [ @{$jo->{$mergePoint}},@{$jo->{$w}}];	#	in case $newkey eq $mergePoint
			delete $jo->{$mergePoint};
			delete $jo->{$w};
			$jo->{$newkey} = $tmp;
			$mergePoint = $newkey;
		}
	}

	return $jo;
}

sub split_w{
	my $jo = shift;

	for my $wr (sort keys %{$jo}){
		my $price_hash = {};
		for (my $i=0;$i<scalar(@{$jo->{$wr}});$i++){
			my $price = $jo->{$wr}->[$i]->{t_price};
			if(defined $price_hash->{$price}){
				push @{$price_hash->{$price}}, $jo->{$wr}->[$i];
			}else{
				$price_hash->{$price} = [ $jo->{$wr}->[$i] ];
			}
		}
		delete $jo->{$wr};

		my $i=1;
		for my $arr ( values %{$price_hash}){
			$jo->{"$wr-$i"} = $arr;
			$i++;
		}
	}
	return $jo;
}
sub transform2Flat{
	my $jo_asin = shift;

	my $jo = [];
	for my $asin ( keys %{$jo_asin}){
		my $color = $jo_asin->{$asin}->[1];
		my $size = $jo_asin->{$asin}->[0];

		my ($w,$l) = $size =~ m/(\d+W) x (\d+L)/;
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

# sub findPriceSection {
	
# 	for my $p (sort keys %{$jo->{$color}}){
# 		my ($low,$high) = split(/-/,$p);
# 		$high = $low if undef $high;
# 		return $p if $price >=$low and $price < $price*1.1
# 	}
# }

sub transform2Tree{
	my $self = shift;
	my $items = shift;

	my $jo = {};
	for my $item ( @{$items}){
		# my $title = $item->{title_cn} or next;
		my $color = $item->{color} or next;
		my $size = $item->{size} or next;
		my $price = $item->{t_price} = ceil($item->{price} * 7.0) or next;
		my ($w) = split(/ /, $size);
		# my $w = $item->{w} or next;
		# my $l = $item->{l} or next;

		$jo->{$color} = {} unless defined $jo->{$color};
		$jo->{$color}->{$price} = {} unless defined $jo->{$color}->{$price};
		$jo->{$color}->{$price}->{$w} = [] unless defined $jo->{$color}->{$price}->{$w};

		push @{$jo->{$color}->{$price}->{$w}}, $item;
	}

	return $jo;
}

1;

__END__

