
use Util;

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

sub getPrice{
	my $content = shift;

	my $price = getNodeText($content,nodename=>"span",nodeid=>"priceblock_dealprice");
	$price = getNodeText($content,nodename=>"span",nodeid=>"priceblock_ourprice") if ! defined $price;
	$price = getNodeText($content,nodename=>"span",nodeid=>"priceblock_saleprice") if ! defined $price;
	throw Error::Simple("price not found") if ! defined $price;
	$price = Util::trim($price);
	$price =~ s/^\$//g;

	return $price;
}

sub getTitle{
	my $content = shift;

	my $title = getNodeText($content,nodename=>"span",nodeid=>"productTitle");
	throw Error::Simple("title not found") if ! defined $title;
	$title = Util::trim($title);

	return $title;
}

sub getListPrice{
	my $content = shift;

	my $list_price = getNodeText($content,nodename=>"span",leading_str=>"List Price:",nodeclass=>"a-text-strike");
	$list_price = getNodeText($content,nodename=>"span",leading_str=>"Was:",nodeclass=>"a-text-strike") if ! defined($list_price);

	$list_price = Util::trim($list_price);

	return $list_price;
}

1;

