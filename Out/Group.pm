package Out::Group;

use File::Spec;
use List::Util qw(reduce);
use JSON::Parse 'parse_json';
use POSIX;

use Error qw(:try);

use Template;
use Util;
use TBCsv;

our $topImg = File::Spec->rel2abs("template/top1.jpg");

sub new {
	my $class = shift;
	my $code = shift;

	$class = ref $class if ref $class;
	my $self = bless {
		code=>$code,
		engineMainPic => Template->new("template/mainpic1.html"),
		engineDetail => Template->new("template/detailpic1.html"),
		engineDetailRow => Template->new("template/tr.html"),
		csv => TBCsv->new()

		}, $class;

	return $self;
}

sub getMinL {
	my $colorItem = shift;

	my $minLItem = undef;
	for my $w (sort keys %{$colorItem}){
		my $tmp = reduce {$a->{l} lt $b->{l} ? $a : $b } @{$colorItem->{$w}};
		$minLItem = $tmp if !defined $minLItem or $tmp->{l} lt $minLItem->{l};
	}

	return $minLItem->{l};
}

#require color->w->l array to be sorted
sub genPriceMatrix {
	my $colorItem = shift;

	my $wc = scalar(keys %{$colorItem});
	my $table = "<table class=\"priceTable\"><tbody>\n";
	my $minL = undef;
	#first line
	$table = $table . "<tr><td></td><td>" . join('W</td><td>',sort keys %{$colorItem}) . "</td></tr>";
	while ($minL = getMinL($colorItem)) {
		my $tds = "<tr><td>".$minL."L</td>"; #first column
		my $w = undef;
		for $w (sort keys %{$colorItem}){
			my $l0 = $colorItem->{$w}->[0]->{l};
			my $price0 =  '-';
			if($l0 == $minL){
				$price0 = "$colorItem->{$w}->[0]->{t_price}";
				shift @{$colorItem->{$w}};
			}
			$tds .= "<td>$price0</td>";
		}
		$tds .= "</tr>\n";
		$table .= $tds;
	}
	$table .= "</tbody></table>";
	return $table;
}

sub engineOutput {
	my $self = shift;
	my $engine = shift;
	my $tag = shift;
	my $colors = shift;

	my $content = $engine->fillIn(ref $self);
	my $filenameHtml = "$self->{code}/" . Util::normalizePath("$tag-$colors.html");
	my $filenameImg = "$self->{code}/" . Util::normalizePath("$tag-$colors.png");
	mkdir "$self->{code}";
	Util::writeFileUtf8($content, "$filenameHtml");
	system("captureScreen.sh $filenameHtml $filenameImg");

	return ($filenameHtml, $filenameImg);
}

#sort L array
sub sortL {
	my $colorItem = shift;

	for my $w (keys %{$colorItem}){
		my @tmp = sort {$a->{l} <=> $b->{l}} @{$colorItem->{$w}};
		$colorItem->{$w} = \@tmp;
	}

	return $colorItem;
}
sub findLowestPrice {
	my $colorItem = shift;
	my $lowPriceItem = undef;
	for my $w (%{$colorItem}){
		my $ls = $colorItem->{$w};
		my $tmp = reduce {$a->{t_price} lt $b->{t_price} ? $a : $b } @{$ls};
		$lowPriceItem = $tmp if !defined $lowPriceItem or $tmp->{t_price} < $lowPriceItem->{t_price};
	}
	return $lowPriceItem->{t_price};
}
sub extraGroupMainPic {
	my $self = shift;
	my $groupItem = shift;

	our $mainPicImgs = [];
	our $mainPicColors = [];
	for my $color (sort keys %{$groupItem->{colors}}){
		try{
			my $item0 = (values %{$groupItem->{$color}})[0]->[0];
			push @{$mainPicImgs}, $item0->{imgs_local}->[0];
			push @{$mainPicColors},$color;
		} 
		catch Error with {
			my $ex = shift;
			print "err processing $color: ".$ex->text." . \n";
		}
	}

	my $colorStr = Util::normalizePath(join('-',@{$mainPicColors}));
	return $self->engineOutput($self->{engineMainPic},"mainPic",$colorStr);
}

sub extraGroupDetailPic {
	my $self = shift;
	my $groupItem = shift;

	our $detailRows = "";
	my $colors = [];
	for our $color (sort keys %{$groupItem->{colors}}){
		try{
			$groupItem->{$color} = sortL($groupItem->{$color});
			# findLowestPrice($groupItem->{$color})
			my $item0 = (values %{$groupItem->{$color}})[0]->[0];
			our $colorImg = $item0->{imgs_local}->[0];
			our $table = genPriceMatrix($groupItem->{$color});	#for detail picture
			my $row = $self->{engineDetailRow}->fillIn(ref $self) . "\n";	#for detail picture
			
			$detailRows .= $row;
			push @{$colors}, $color;
		} 
		catch Error with {
			my $ex = shift;
			print "err processing $color: ".$ex->text." . \n";
		}
	}

	my $colorStr = Util::normalizePath(join('-',@{$colors}));
	my ($htmlFilename,$imgFilename) = $self->engineOutput($self->{engineDetail},"detail",$colorStr);
}

sub extraGroup {
	my $self = shift;
	my $group = shift;
	# my $items = shift;
#t_picture
#t_skuProps
#t_inputPids
#t_inputValues
	# my $gCsv = TBCsv->new();
	# $gCsv->setNum(1);

	my ($htmlFilenameMainPic,$imgFilenameMainPic) = $self->extraGroupMainPic($group);
	my ($htmlFilenameDetail,$imgFilenameDetail) = $self->extraGroupDetailPic($group);
}

sub extra {
	my $self = shift;
	my $items = shift;

	$items = $self->transform($items);

	for my $group (sort keys %{$items}){
		$self->extraGroup($items->{$group});
	}
}

sub transform{
	my $self = shift;
	my $items = shift;

	my $itemsTree = {};
	my $colorItemCount = {};
	for my $item ( @{$items}){
		# my $title = $item->{title_cn} or next;
		my $color = $item->{color} or next;
		my $size = $item->{size} or next;
		my $price = $item->{t_price} = ceil(($item->{price} * 7.0)/10) * 10 or next;
		my ($w,$l) = $size =~ m/(\d+)W x (\d+)L/;
		$item->{w} = $w or next;
		$item->{l} = $l or next;

		$colorItemCount->{$color} += 1;

		push @{$itemsTree->{$color}->{$w}}, $item;
	}

	#remove those less then 4 size option
	for my $color (keys %{$colorItemCount}){
		delete $itemsTree->{$color} if $colorItemCount->{$color} < 4;
	}


	my $groups = Util::readFileJson("groups/$self->{code}.json");
	for my $group (sort keys %{$groups}){
		for my $color (sort keys %{$groups->{$group}->{colors}}){
			$groups->{$group}->{$color} = $itemsTree->{$color};
		}
	}

	return $groups;
}

1;
