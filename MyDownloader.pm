#!/bin/perl
package MyDownloader;

use strict;
use LWP::UserAgent;
use Digest::MD5 qw(md5_hex);
use File::Path qw(make_path remove_tree);
use Util;

sub new { 
	my $class = shift; 
	my $self = {
		args => undef,
		filename => undef,
		filename_cache => undef
	}; 
	bless $self, $class; 

	return $self;
}

sub download{
	my $self = shift;
	$self->{args} = {@_};

	my $url = $self->{args}->{url};
	my $filename = $self->{filename} = $self->{args}->{filename};

	die "parameter url is required" unless defined $url;
	die "parameter filename is required" unless defined $filename;

	my $cache_dir = $self->{args}->{cache_dir};
	my $cache_sec = $self->{args}->{cache_sec} or 300; #default 300 second
	my $url_hash = md5_hex($url);
	my $filename_cache = $self->{filename_cache} = "$cache_dir/$url_hash";

	if(defined $cache_dir and Util::fileMTimeDelta($filename_cache) < $cache_sec){
		link $filename_cache,$filename;
		return Util::readFile($filename_cache);
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

	$ua->max_size($self->{args}->{bytes}) if defined $self->{args}->{bytes};

	my $resp = $ua->get($url);

	Util::writeFileBin($resp->content,$filename);

	if(defined $cache_dir){
		make_path( $cache_dir) unless -e $cache_dir;
		link $filename, $filename_cache;
	}

	return $resp->content;
}

sub clearCache{
	my $self = shift;
	unlink $self->{filename_cache} if -e $self->{filename_cache};
}

1;

__END__

