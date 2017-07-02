package Out::Single;

use Util;
use TBCsv;
use File::Path qw(make_path remove_tree);
use Digest::MD5 qw(md5_hex);
use POSIX;


sub new {
	my $class = shift;
	my $code = shift;

	$class = ref $class if ref $class;
	my $self = bless {

		code=>$code
		}, $class;
	
	return $self;
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

sub extra{
	my $self = shift;
	my $items = shift;

	my $itemsTree = $self->transform($items);

	for my $color (sort keys %{$itemsTree}){
		for my $price (sort keys %{$itemsTree->{$color}}){
			$itemsTree->{$color}->{$price} = merge_w($itemsTree->{$color}->{$price});
		}
		$self->genDataPack($itemsTree->{$color},$color);
	}
}

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

			Util::writeFileUtf8($lines,"$prefix/$color_p/$price/$w_p.csv");
		}
	}
}

sub transform{
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

		push @{$jo->{$color}->{$price}->{$w}}, $item;
	}

	return $jo;
}


1;


