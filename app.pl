#!/usr/bin/perl
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
use Translate;
use DBStore;

require "html_parser.pl";

my $temp_filename = "template/data.csv";
sub new{
	my $class = shift;

	my $self = bless {
		trans=>undef,
		store=>undef
	}, $class;

	$self->{trans} = Translate->new("dict.txt");
	$self->{store} = DBStore->new("zbox-desktop",27017);

	return $self;
}

my $jo_img;
my $base_local = "/var/www/storage";
my $pageSize = 200000;

# Levis->new()->updateAsinPrice2("B0151YZMDO"); 
Levis->new()->updatePrice(); 
sub newDownload{
	my $self = shift;

	my $root_url = 'https://www.amazon.com/dp/B0018OR118';
	
	my $filename = 'root.html';
	my $document = undef;

	if(defined $root_url && defined $filename){
		print "downloading root.html\n";
		$document = MyDownloader->new()->download(url=>$root_url,
			filename=>$filename,
			cache_dir=>".",
			cache_sec=>1000000,
			bytes=>1000000);
	}

	my $jsonstr = getJsonText($document,'var dataToReturn =','return dataToReturn;');
	my $jo_data = parse_json ($jsonstr);
	my $jo_asin = $jo_data->{"dimensionValuesDisplayData"};

	$jsonstr = getJsonText($document,'data["colorImages"] = ','data["heroImage"]');
	$jo_img = parse_json ($jsonstr);

	our $jo_root = restructure($jo_asin);

	my $n=0;
	for my $color ( sort keys %{$jo_root}){
		
		$jo_root->{$color} = $self->handle_color($jo_root->{$color},$color);

		$jo_root->{$color} = split_w($jo_root->{$color});

		$self->genDataPack($jo_root->{$color}, $color);

		$n++;
	}
}
sub initBasic{
	my $self = shift;

	my $root_url = 'https://www.amazon.com/dp/B0018OR118';
	
	my $filename = 'root.html';
	my $document = undef;

	if(defined $root_url && defined $filename){
		print "downloading root.html\n";
		$document = MyDownloader->new()->download(url=>$root_url,
			filename=>$filename,
			cache_dir=>".",
			cache_sec=>1000000,
			bytes=>1000000);
	}

	my $jsonstr = getJsonText($document,'var dataToReturn =','return dataToReturn;');
	my $jo_data = parse_json ($jsonstr);
	my $jo_asin = $jo_data->{"dimensionValuesDisplayData"};

	$jsonstr = getJsonText($document,'data["colorImages"] = ','data["heroImage"]');
	$jo_img = parse_json ($jsonstr);

	our $jo_root = transform2Flat($jo_asin);

	my $n=0; 
	for my $item ( @{$jo_root}){
		print "init $item->{asin}, $item->{color}, $item->{size}\n";
		$self->{store}->updateField($item);
	}
}

sub updatePrice {
	my $self = shift;
	$self->{store}->updatePrice(\&updateAsinPrice, $self);
}
sub updateAsinPrice2 {
	my $self = shift;
	my $asin = shift;

	my $item = $self->{store}->getItem({asin=>$asin});
	$self->handle_size($item);
}
sub updateAsinPrice {
	my $item = shift;
	my $self = shift;
	try{
		$self->handle_size($item,0);
	}catch Error with{
		my $ex = shift;
		print $ex->text . "\n";
		$item->{datetime} = Util::genTimestamp();
		$self->{store}->updateField($item);
	}
	
}

sub extraData{
	my $self = shift;

	my $items = $self->{store}->getAllItems();

	my $itemsTree = $self->transform2Tree($items);

	for my $color (keys %{$itemsTree}){
		$itemsTree->{$color} = split_w($itemsTree->{$color});
		$self->genDataPack($itemsTree->{$color},$color);
	}
}

sub genDataPack{
	my $self = shift;
	our ( $jo, $color) = @_;
	my $prefix = "taobao-data";
	my $color_p = Util::normalizePath($color);

	# $jo_color_w->{hello} = "world";
	for our $size_range (keys %{$jo}){
		our $jo_size_range = $jo->{$size_range};
		our $jo_size_1 = $jo_size_range->[0];

		make_path( "$prefix/$color_p/$size_range");

		for my $jo_size (@{$jo_size_range}){
			# $jo_size->{nihao} = "shijie";
			next unless defined $jo_size->{imgs_local};
			for (my $i = 0; $i < scalar(@{$jo_size->{imgs_local}}); $i++) {
				my $hash = md5_hex($jo_size->{imgs_remote}->[$i]);
			    link $jo_size->{imgs_local}->[$i],"$prefix/$color_p/$size_range/$hash.tbi";
			    $jo_size->{imgs_local}->[$i] = "$hash";
			}
		}

		open F,"<:utf8",$temp_filename or die "cannot open template file $temp_filename";
		my $template = Text::Template->new(TYPE => 'FILEHANDLE', SOURCE=> \*F)
			or die "Couldn't construct template: $Text::Template::ERROR";

		my $result = $template->fill_in() or die $Text::Template::ERROR;

		Util::writeFile($result,"$prefix/$color_p/$size_range.csv");
	}
	

}


sub downloadImgs{
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
			cache_dir=>"$base_local/cache_img",
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
	$jo->{color_cn} = $self->{trans}->translate($jo->{color});

	my $size_p =  Util::normalizePath($jo->{size});
	my $color_p = Util::normalizePath($color);

	
	my $base_url = "http://14.155.17.64:81";
	my $path = "$color_p/$size_p";
	make_path( "$base_local/$path/");

	$jo->{color_p} = $color_p;
	$jo->{size_p} = $size_p;

	print "retrieving $jo->{datetime}, $asin, $color, $jo->{size}\r\n";

	my $filename = "$base_local/$path/page.html";

	my $suburl = "https://www.amazon.com/dp/$asin?psc=1";
	my $d = MyDownloader->new();
	try{
		my $content = $d->download(url=>$suburl,
			filename=>$filename,
			cache_dir=>"$base_local/cache_page",
			cache_sec=>$cacheSec,
			bytes=>$pageSize);
		
		$jo->{filename} = $filename;
		$jo->{filename_cache} = $d->{filename_cache};
		$jo->{title}=getTitle($content);
		$jo->{title_cn} = $self->{trans}->translate($jo->{title});
		
		$jo->{price}=getPrice($content);

		my $rat = 7.0;
		$jo->{price_cny}=ceil($jo->{price} * $rat);

		$jo->{list_price}=getListPrice($content);
		$jo->{list_price} = $jo->{price} if ! defined $jo->{list_price};
		
		($jo->{imgs_local},$jo->{imgs_remote}) = downloadImgs($color,"$base_local/$path");

		$jo->{datetime} = Util::genTimestamp();

		# $jo->{title_cn} = utf8::encode($jo->{title_cn});
		$self->{store}->updateField($jo);
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

sub merge_w{
	my $jo = shift;

	my $p = undef;
	my $key1 = "";
	my $key2 = "";
	for my $w (sort keys %{$jo}){
		if (! defined $p){
			$p = $w;
			$key1 = $key2 = $w;
			next;
		}

		if(arr_count($jo->{$p},$jo->{$w}) <= 24){
			#merge
			$jo->{$p} = [ @{$jo->{$p}},@{$jo->{$w}}];
			delete $jo->{$w};
			#remember last key
			$key2 = "$w";
			next;
		}else{
			#change the key
			$jo->{"$key1-$key2"} = $jo->{$p};
			delete $jo->{$p};
			#set new $p
			$p = $w;
			$key1 = $key2 = $w;
		}	
	}

	#change the key
	$jo->{"$key1-$key2"} = $jo->{$p};
	delete $jo->{$p};

	return $jo;
}

sub split_w{
	my $jo = shift;

	
	for my $wr (sort keys %{$jo}){
		my $price_hash = {};
		for (my $i=0;$i<scalar(@{$jo->{$wr}});$i++){
			my $price = $jo->{$wr}->[$i]->{price_cny};
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

sub transform2Tree{
	my $self = shift;
	my $items = shift;

	my $jo = {};
	for my $item ( @{$items}){
		my $title_cn = $item->{title} or next;
		my $color = $item->{color} or next;
		my $size = $item->{size} or next;
		my $w = $item->{w} or next;
		my $l = $item->{l} or next;

		$jo->{$color} = {} if ! defined $jo->{$color};
		$jo->{$color}->{$w} = [] if ! defined $jo->{$color}->{$w};

		push @{$jo->{$color}->{$w}}, $item;
	}

	for my $color (keys %{$jo}){
		$jo->{$color} = merge_w($jo->{$color});
	}

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

		my ($w,$l) = $size =~ m/(\d+W) x (\d+L)/;
		next unless defined $w and defined $l;

		$jo->{$color} = {} if ! defined $jo->{$color};
		$jo->{$color}->{$w} = [] if ! defined $jo->{$color}->{$w};

		my $item = {};
		$item->{asin}=$asin;
		$item->{color}=$color;
		$item->{size}=$size;
		$item->{count}=1;

		push @{$jo->{$color}->{$w}}, $item;
	}

	for my $color (keys %{$jo}){
		$jo->{$color} = merge_w($jo->{$color});
	}

	return $jo;
}

sub handle_size_range {
	my $self = shift;

	my $jo = shift;
	my $size_range = shift;

	my $new_jo = [];
	for my $jo_i (@{$jo}){
		try {
			push @{$new_jo}, $self->handle_size($jo_i,1000000);
		}
		catch Error with {
			my $ex = shift;
			print "failed: $jo_i->{asin} $jo_i->{color} $jo_i->{size} " . $ex->text . " \r\n";
		};
	}

	return $new_jo;
}
sub handle_color{
	my $self = shift;

	my $jo = shift;
	my $color = shift;

	for my $size_range (sort keys %{$jo}){
		$jo->{$size_range} = $self->handle_size_range($jo->{$size_range}, $size_range);
	}

	return $jo;
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

1;

__END__

