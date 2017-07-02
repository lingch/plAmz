package Out::Group;

use File::Spec;
use List::Util qw(reduce);
use POSIX;

use Template;
use Util;

sub new {
	my $class = shift;
	my $code = shift;

	$class = ref $class if ref $class;
	my $self = bless {
		code=>$code
		}, $class;


	return $self;
}

sub getMinL {
	my $item = shift;

	my $minLItem = undef;
	for my $w (keys %{$item}){
		my $tmp = reduce {$a->{l} lt $b->{l} ? $a : $b } @{$item->{$w}};
		$minLItem = $tmp if !defined $minLItem or $tmp->{l} lt $minLItem->{l};
	}

	return $minLItem ? $minLItem->{l} : undef;
}

sub genPriceMatrix {
	my $item = shift;

	my $wc = scalar(keys %{$item});
	my $table = "<table class=\"priceTable\"><tbody>\n";
	my $minL = undef;
	#first line
	$table = $table . "<tr><td></td><td>" . join('W</td><td>',sort keys %{$item}) . "</td></tr>";
	while ($minL = getMinL($item)) {
		my $tds = "<tr><td>".$minL."L</td>"; #first column
		my $w = undef;
		for $w (sort keys %{$item}){
			my $l0 = $item->{$w}->[0]->{l};
			my $price0 =  '-';
			if($l0 == $minL){
				$price0 = "$item->{$w}->[0]->{t_price}";
				shift @{$item->{$w}};
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
	Util::writeFile($content, "$filenameHtml");
	system("captureScreen.sh $filenameHtml $filenameImg");
}


sub extra {
	my $self = shift;
	my $items = shift;

	$items = $self->transform($items);

	our $topImg = File::Spec->rel2abs("template/top1.jpg");
	our $mainPicItems = [];
	our $detailRows = "";
	my $colorStr = "";
	my $engineMainPic = Template->new("template/mainpic1.html");
	my $engineDetail = Template->new("template/detailpic1.html");
	my $engineDetailRow = Template->new("template/tr.html");
	for my $color (sort keys %{$items}){

		#sort L array
		for my $w (keys %{$items->{$color}}){
			my @tmp = sort {$a->{l} <=> $b->{l}} @{$items->{$color}->{$w}};
			$items->{$color}->{$w} = \@tmp;
		}

		my $item0 = (values %{$items->{$color}})[0]->[0];
		if(scalar(@{$mainPicItems}) < 6){
			our $colorImg = $item0->{imgs_local}->[0];
			our $table = genPriceMatrix($items->{$color});
			$detailRows .= $engineDetailRow->fillIn(ref $self) . "\n";

			push @{$mainPicItems}, $colorImg;
			$colorStr .= "-$color";
		}else{
			$self->engineOutput($engineMainPic,"mainPic",$colorStr);
			$self->engineOutput($engineDetail,"detail",$colorStr);

			$mainPicItems = [];
			$colorStr = "";
		}
	}
}

sub transform{
	my $self = shift;
	my $items = shift;

	my $jo = {};
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

		push @{$jo->{$color}->{$w}}, $item;
	}

	#remove those less then 4 size option
	for my $color (keys %{$colorItemCount}){
		delete $jo->{$color} if $colorItemCount->{$color} < 4;
	}

	return $jo;
}

1;