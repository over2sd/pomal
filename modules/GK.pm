package GK; # Graphic Kit

print __PACKAGE__;

use Prima qw(Application Buttons MsgBox FrameSet);

package ColorRow; #Replaces Gtk2::ColorSelectionDialog
# EXAMPLE:
#my $colRow = ColorRow->new(
#	owner => $mw,
#);
#$colRow->build("Header Color: ",{ color => "#BBEEFF" },{ text => "Paint", });

package FontRow; #Replaces Gtk2::FontButton
# EXAMPLE:
#my $fontR = FontRow->new(
#	owner => $mw,
#	);
#my $bodyinputobject = $fontR->build("Body Font: ",{ font => "Arial 14" },{ text => "Select", });
use parent -norequire, 'HBox';

sub build {
	my ($self,$ltxt,$exargs,$butargs) = @_;
	$self->pack( fill => 'x', expand => 0, side => "top", );
	if (defined $ltxt) {
		$self->insert( Label =>
			text => $ltxt,
			pack => { fill => "none", expand => 0, },
			);
	}
	my $font = stringToFont($$exargs{font} or "");
	my $lab = Prima::InputLine->new(
		owner => $self,
		readOnly => 1,
		selectable => 0,
		text => getFontString($font),
		font => $font,
		pack => { fill => 'x', expand => 1, padx => 3, },
	);
	$self->insert(Button =>
		text => "Choose",
		onClick => sub {
			$font = FontButton::clicked($lab->font());
			if (defined $font) {
				$lab->font($font); # TODO: Make this set only the face, not the size (unless an accessibility option is enabled?)
				$lab->text(getFontString($font));
			}
		},
		%$butargs,
		pack => { fill => 'none', expand => 0, },
	);
	$self->arrange();
	return $lab;
}

sub clicked {
	my $font = shift;
	use Prima::FontDialog;
	my $f = Prima::FontDialog->create();
	$f->logFont($font);
	$f->apply($font);
	return unless $f->execute() == mb::OK;
	$f = $f-> logFont;
#	print "$_:$f->{$_}\n" for sort keys %$f;
	return $f;
}

sub getFontString { # takes a reference to a Prima::Font
	my $f = shift;
	return (defined $f ? sprintf("%s %d",$f->{name},$f->{size}) : "");
}

sub stringToFont {
	my ($string) = @_;
	if ($string =~ m/(.+) (\d+)/) { # use regex to grab name and size
		my $newfont = {
			name => $1,
			size => $2,
		};
		return $newfont;
	} else {
		warn "No matching string!\n";
		return {};
	}
}

package HBox; #Replaces Gtk2::HBox
use vars qw(@ISA);
@ISA = qw(Prima::Widget);

sub insert {
	my ($self,$class,@args) = @_;
	my $child = $self->SUPER::insert($class,@args);
	$child->pack(side => "left");
}

sub arrange { # TODO: "reverse" option
	my $self = shift;
	foreach ($self->get_widgets()) {
		$_->pack(side => "left");
	}
}
print ".";

package VBox; #Replaces Gtk2::VBox
use vars qw(@ISA);
@ISA = qw(Prima::Widget);

sub insert {
	my ($self,$class,@args) = @_;
	my $child = $self->SUPER::insert($class,@args);
	$child->pack(side => "top");
}

sub arrange {
	my $self = shift;
	foreach ($self->get_widgets()) {
		$_->pack(side => "top");
	}
}
print ".";

package GK;

print ".";

print " OK; ";
1;
