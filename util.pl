#!/usr/bin/perl

use LWP::UserAgent;
use Digest::MD5 qw(md5_hex);

sub  normalizePath {
	my $path = shift;
	$path =~ s/\s+/-/g;
	return $path;
}

sub fileMTimeDelta{
	my $filename = shift;
	my $mtime = (stat $filename)[9];
	my $currentTime = time();

	return $currentTime - $mtime;
}


sub download{
	my %args = @_;

	my $url = $args{url} || die "parameter url is required";
	my $filename = $args{filename} || die "parameter filename is required";
	my $bytes = $args{bytes};

	my $cache_dir = $args{cache_dir};
	my $cache_sec = $args{cache_sec};
	my $url_hash = md5_hex($url);
	my $cache_filename = "$cache_dir/$url_hash";

	if(defined $cache_dir and defined $cache_sec and fileMTimeDelta($cache_filename) < $cache_sec){
		return readFile($cache_filename);
	}

	my $ua = LWP::UserAgent->new(ssl_opts=>{verify_hostname=>0});
	$ua->env_proxy;

	my $headers = HTTP::Headers->new(
		"Accept"=>'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
"Accept-Language"=>'zh-CN,zh;q=0.8,en;q=0.6',
"Cache-Control"=>'max-age=0',
"Connection"=>'keep-alive',
#"Cookie"=>'x-wl-uid=12RgsujmHNR9noaphwPkn/USFBXMipoLxhj7XVXth302LqHHX5GozIpYQt6ta7IoTjMUGI2kNrD8=; session-token=uvI7cwOtLrHU/MxyhLyjc4yG9ePB7sPbOvgy7QV4STfcRIpDkKMZoWATlsrLBBL4Ynk6lD+uYScHZ/PLDIU77TFH9xioawnthTrAXx/ymOveTVxNRPd9KAApm7DJBDRm/XrQHK+88rBTjZo8CJr4qlsITYYwrusTZ7HygR8WrMsI9qIUilfcRticXZyWM20VofDqdFMw56a17eoL7kJLTwDCWQtUuuhhXQW+vo7LXmMDCbAtPLu7d9Zj4l6NvFVW; csm-hit=11R8TT1M57SWM11BNESW+b-11R8TT1M57SWM11BNESW|1496925451585; ubid-main=133-4859202-5235766; session-id-time=2082787201l; session-id=144-6212466-9368749'
#"Host"=>'www.amazon.com',
"User-Agent"=>'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36'
		);
	$ua->default_headers($headers);

	if(defined $bytes){
		$ua->max_size($bytes);
	}

	my $resp = $ua->get($url);

	writeFile($resp->content,$filename);

	if(defined $cache_dir){
		link $filename, $cache_filename;
	}

	return $resp->content;
}

sub writeFile{
	my $content = shift;
	my $filename = shift;

	open (MYFILE, ">$filename");
	print MYFILE $content;
	close (MYFILE); 
}

sub  readFile {
	my $filename = shift;
	open(FILE, $filename) or die "Cant read file $filename";
	$document = do{local $/; <FILE>};
	close(FILE);
	return $document;
}

# Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
# Left trim function to remove leading whitespace
sub ltrim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	return $string;
}
# Right trim function to remove trailing whitespace
sub rtrim($)
{
	my $string = shift;
	$string =~ s/\s+$//;
	return $string;
}

1;

