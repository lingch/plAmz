#!/bin/perl

use MyDownloader;


download1();

sub download1{

	my $d = MyDownloader->new();
	$d->download(url=>"http://baidu.com",filename=>"a.html");

	$d->clearCache();
}

