#!/usr/bin/perl

use LWP::UserAgent;

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
	my $mtime_threshold = $args{mtime_threshold};

	if(defined $mtime_threshold && fileMTimeDelta($filename) < $mtime_threshold){
		return readFile($filename);
	}

	my $ua = LWP::UserAgent->new(ssl_opts=>{verify_hostname=>0});
	$ua->env_proxy;

	if(defined $bytes){
		$ua->max_size($bytes);
	}

	my $resp = $ua->get($url,
	    Range => "bytes=0-$bytes"
	);

	writeFile($resp->content,$filename);

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

1;

