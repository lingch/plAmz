package Template;
use strict;
use Text::Template;

use Error qw(:try);

sub new {
	my $class = shift;
	my $filename = shift;

	$class = ref $class if ref $class;
	my $self = bless {
		filename=>$filename,
		engine=>undef
		}, $class;

	$self->loadTemp($filename);
	return $self;
}

sub loadTemp {
	my $self = shift;
	my $filename =shift;

	open F,"<:utf8","$filename" or die "cannot open template file $filename";
	try{
		$self->{engine} = Text::Template->new(DELIMITERS => [ '{=', '=}' ],TYPE => 'FILEHANDLE', SOURCE=> \*F)
		or die $Text::Template::ERROR;
		$self->{engine}->compile() or die $Text::Template::ERROR;
		}finally {
			close F;
		};
}

sub fillIn {
	my $self = shift;
	my $pkg = shift or 'main';

	return $self->{engine}->fill_in(PACKAGE=>$pkg) or die $Text::Template::ERROR;
}

1;

