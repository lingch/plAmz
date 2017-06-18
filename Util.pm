#!/usr/bin/perl
package Util;
use LWP::UserAgent;

sub  normalizePath {
	my $path = shift;
	$path =~ s/[\s\/]+/-/g;
	return $path;
}

sub fileMTimeDelta{
	my $filename = shift;
	my $mtime = (stat $filename)[9];
	my $currentTime = time();

	return $currentTime - $mtime;
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

__END__
