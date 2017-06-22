package TBCsv;

use strict;

use Storable qw(dclone);

require "FieldList.pm";

sub new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = bless {}, $class;
	$self;
}

sub parse1 {
	my $line = shift;

	my @values = split(/\t/,$line);
	my $item = {};
	for (my $i=0; $i<scalar(@values);$i++){
		next unless defined $TBCsv::FIELD_LIST->[$i];
		$values[$i] =~ s/^"+//;
		$values[$i] =~ s/"+$//;
		$item->{$TBCsv::FIELD_LIST->[$i]} = $values[$i];
	}
	return $item;
}

#e.g.
#1627207:-1001:Rainfall;20518:-1001:29W x 32L;20518:-1002:29W x 30L
sub parse_input_custom_cpv{
	my $content = shift;

	my $pmap = {};
	my @ps = split(/;/,$content);
	for my $p (@ps){
		my @fs = split(/:/,$p);
		next if scalar(@fs) != 3;
		$pmap->{"$fs[0]:$fs[1]"} = $fs[2];
	}

	return $pmap;
}

#e.g.
#20000:3271216;42722636:3250994;122216515:29535;122276111:20525;1627207:-1001;20518:-1001;20518:-1002;
#split to 20000:3271216;
sub parse_cateProps{
	my $content = shift;
	my $pmap = shift;

	my @cps = split(/;/,$content);
	my $ret = [];
	for my $cp (@cps){
		#remove color and size
		next if defined $pmap->{$cp};
		push @{$ret},$cp;
	}

	return $ret;
}

#f57e2a559466c660a07a29335fd9c88c:1:0:|https://img.alicdn.com/bao/uploaded/i2/TB1Pu_2RFXXXXbxXVXXXXXXXXXX_!!0-item_pic.jpg;
sub parse_picture{
	my $content = shift;

	my @ps = split(/;/,$content);
	my $ret = [];
	for my $p (@ps){
		push @{$ret},$p;
	}

	return $ret;
}

sub splitSubItems {
	my $item = shift;

	my $pmap = parse_input_custom_cpv($item->{t_input_custom_cpv});
	delete $item->{t_input_custom_cpv};

	$item->{t_cateProps} = parse_cateProps($item->{t_cateProps},$pmap);

	$item->{t_picture} = parse_picture($item->{t_picture});

	#280:1:B01610UO76:1627207:-1001;20518:-1001
	my @sps = split(/[:;]/, $item->{t_skuProps});
	delete $item->{t_skuProps};

	my @titles = split(/ /,$item->{t_title});
	die "parse title failed" if scalar(@titles) < 1;
	$item->{t_title} = @titles[0];

	my $NG = 7;
	my $subItems = [];
	for (my $i=0;$i<scalar(@sps);$i=$i+$NG){
		my $subItem = dclone($item);
		
		$subItem->{t_price} = @sps[$i+0];
		$subItem->{t_num} = @sps[$i+1];
		$subItem->{asin} = @sps[$i+2];
		$subItem->{color} = $pmap->{"@sps[$i+3]:@sps[$i+4]"};
		$subItem->{size} = $pmap->{"@sps[$i+5]:@sps[$i+6]"};
		push @{$subItems},$subItem;
	}

	return $subItems;
}

sub parse {
	my $filename = shift;

	open F,"<:utf8",$filename;
	my $version = <F>;
	my $enTitle = <F>;
	my @titles = split(/\t/,$enTitle);
	my $cnTitle = <F>;

	my $items = [];
	while (my $content = <F>) {
		#for each line
		my $item = parse1($content);
		my $subItems = splitSubItems($item);
		push @{$items},@{$subItems};
	}
	close F;

	return $items;
}


1;

