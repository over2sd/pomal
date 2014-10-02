package GK; # Graphic Kit

print __PACKAGE__;

use Prima qw(Application Buttons MsgBox FrameSet);

package ColorRow; #Replaces Gtk2::ColorSelectionDialog
# EXAMPLE:
#my $colRow = ColorRow->new(
#	owner => $mw,
#);
#$colRow->build("Header Color: ",{ color => "#BBEEFF" },{ text => "Paint", });

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
	my $lab = Prima::InputLine->new(
		owner => $self,
		text => $exargs->{color},
		pack => { fill => 'x', expand => 1, padx => 3, side => "left", },
	);
	my $swatch = Prima::Button->new(
		owner => $self,
		text => "",
		readOnly => 1,
		selectable => 0,
		backColor => stringToColor($exargs->{color}),
		%$butargs,
		pack => { fill => 'none', expand => 0, padx => 3, side => "left", },
	);
	$swatch->set(onClick => sub {
			my $p = Prima::ColorDialog-> create( quality => 1, );
			$p->value(stringToColor($lab->text()));
			my $ok = $p->execute();
			if ($ok == 1) {
				$lab->text(sprintf "#%06x", $p-> value());
				matchColor($lab,$swatch);
			}
		});
	$lab->set(onChange => sub { matchColor($lab,$swatch); });
	$self->arrange();
	return $lab; # for signal connection, value pulling, etc.
}

sub matchColor {
	my ($model,$target) = @_;
	$target->backColor(stringToColor($model->text()));
}

sub stringToColor {
	my $string = shift;
	$string =~ s/^#//;
	return 0 unless (length($string) >= 3);
	if ($string =~ m/[\dA-Fa-f]{6}/) {
		return hex $string;
	} elsif ($string =~ m/[\dA-Fa-f]{3}/) {
		my @s = split('',$string);
		$string = $s[0] . $s[0] . $s[1] . $s[1] . $s[2] . $s[2];
		return hex $string;
	}
	return 0;
}

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
	# TODO: Add an option that allows getting just the face, not the size (for options dialog)
	#  ...or just the size, not the face. (for accessibility spinner)
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
	return $child;
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
	return $child;
}

sub arrange {
	my $self = shift;
	foreach ($self->get_widgets()) {
		$_->pack(side => "top");
	}
}
print ".";

package StatusBar; #Replaces Gtk2::Statusbar
# To prevent an awkward-looking status bar, this item MUST be placed in
#  the window BEFORE any item that packs to the window's left or right!
# EXAMPLE:
#my $sb = StatusBar->new(owner => $mw)->prepare();

use vars qw(@ISA);
@ISA = qw(Prima::InputLine);

sub prepare {
	my $self = shift;
	$self->set(
		readOnly => 1,
		text => ($self->text() or ""),
		backColor => $self->owner()->backColor(),
	);
	$self->pack( fill => 'x', expand => 0, side => "bottom", );
	return $self; # allows StatusBar->new()->prepare() call
}
print ".";

package GK;

print ".";

print " OK; ";
1;
