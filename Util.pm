#!/usr/bin/perl
package Util;
use LWP::UserAgent;
use JSON::Parse 'parse_json';

sub genTimestamp{
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
	my $ret = sprintf ("%d-%02d-%02d %02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec);
	return $ret;
}
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

sub writeFile {
	my $content = shift;
	my $filename = shift;
	my $mode = shift;

	open (MYFILE, ">$mode", "$filename");
	print MYFILE $content;
	close (MYFILE); 
}
sub writeFileBin{
	my $content = shift;
	my $filename = shift;

	writeFile($content,$filename,":raw");
}
sub writeFileUtf8{
	my $content = shift;
	my $filename = shift;

	writeFile($content,$filename,":utf8");
}

sub  readFile {
	my $filename = shift;
	my $mode = shift;

	open(FILE,"<$mode", $filename) or die "Cant read file $filename";
	$document = do{local $/; <FILE>};
	close(FILE);
	return $document;
}
sub  readFileBin {
	my $filename = shift;
	return readFile($filename,":raw");
}
sub  readFileUtf8 {
	my $filename = shift;
	return readFile($filename,":utf8");
}
sub readFileJson {
	my $filename = shift;
	my $content = readFileUtf8($filename);
	return parse_json($content);
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
