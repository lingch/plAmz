#!/usr/bin/perl

use LWP::Simple;
use JSON::Parse 'parse_json';
use LWP::UserAgent;

sub download{
	my $url = shift;
	my $bytes = shift;

	my $ua = LWP::UserAgent->new;

	if(defined $bytes){
		$ua->max_size($bytes);
	}

	my $resp = $ua->get($url,
	    Range => "bytes=0-$bytes"
	);

	return $resp->content;
}

sub writeFile{
	my $content = shift;
	my $filename = shift;

	open (MYFILE, ">$filename");
	print MYFILE $content;
	close (MYFILE); 
}



#my $url = 'https://www.amazon.com/dp/B0018OR118';
my $file = 'data/root.html';
if(defined $url && defined $file){
	getstore($url, $file);
}


my $document = do {
    local $/ = undef;
    open my $fh, "<", $file
        or die "could not open $file: $!";
    <$fh>;
};

my $markStart = 'var dataToReturn =';
my $index1 = index($document, $markStart);
if($index1 < 0){
	print "error1";
}

$index2 = index($document, 'return dataToReturn;');
if($index2 < 0){
	print "error2";
}

$jsonstr = substr($document,$index1 + length($markStart),$index2-$index1);

$index2 = rindex($jsonstr, ';');
if($index2 < 0){
	print "error2";
}
$jsonstr = substr($jsonstr,0,$index2);

$jsonstr =~ s/(,\s*])/]/g;
$jsonstr =~ s/(,\s*})/}/g;

my $json = parse_json ($jsonstr);
my $data = $json->{"dimensionValuesDisplayData"};

for (keys %{$data}){
	my $asin = $_;
	my $dir = "data/$asin";
	mkdir $dir;

	my $suburl = "https://www.amazon.com/dp/$asin";
	my $content = download($suburl,10000);
	writeFile($content, "$dir/page.html");
}

print "ok $data";