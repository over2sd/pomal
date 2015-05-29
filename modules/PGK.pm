package PGK; # Prima Graphic Kit

print __PACKAGE__;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( ColorRow FontRow VBox HBox Table applyFont getGUI convertColor labelBox sayBox Pdie Pwait );
use Prima qw(Application Buttons MsgBox FrameSet);

use FIO qw( config );

=head1 NAME

PGK - Prima Graphic Kit, a module for common graphic functions

=head2 DESCRIPTION

A library of common functions usable by multiple programs using a
Prima-based GUI.

=cut
package XButtons; # Exclusive buttons group (radio checkboxes)

=head2 XButtons

Exclusive buttons group (radio buttons)

=head3 Usage

 my $gender = $parent-> insert( XButtons => name => 'gen' );
 $gender->arrange("left"); # line up buttons horizontally
 my @presets = ("M","Male","F","Female");
 my $current = 0;
 $gender-> build("Sex:",$current,@presets); # turn key:value pairs into exclusive buttons

=head3 Methods

=cut
use vars qw(@ISA);
@ISA = qw(Prima::Widget);

my %profile = ( side => "top", );

=item build XBUTTONGROUP LABEL INTEGER PAIREDARRAY

Makes the row/column, using the PAIREDARRAY as values and display
strings, with a label LABEL and setting pair #INTEGER as the default
selection.

=cut
sub build {
	my ($self,$text,$default,@opts) = @_;
	$self{value} = $opts[$default*2]; # x2 because $default is the position of the pair, not the item, in a paired array
	$self->insert( Label => text => $text ) unless ($text eq "");
	my %buttons = @opts;
	foreach (keys %buttons) {
		my $b = $self->insert( SpeedButton => checkable => 1, text => $buttons{$_}, name => $_, pack =>  { fill => "none", expand => 0, }, );
		$b->checked(1) if ($_ eq $self{value});
		$b->onClick( sub { $self->xClick($b); });
	}
}

=item xClick BUTTON

Does the heavy lifting when an exclusive button is clicked. It is never
called directly by the user.

=cut
sub xClick {
	my ($self,$b) = @_;
	foreach ($self->get_widgets()) {
		next unless $_-> isa(q(Prima::Button));
		unless ("$b" eq "$_") {
			$_->checked(0);
			$_->enabled(1);
		} else {
			$_->checked(1);
			$self->value($_->name);
			$self-> notify(q(Change));
			$_->enabled(0);
		}
	}
}

=item value SCALAR

Gets the value of the group. If a SCALAR is supplied, sets the value to
the SCALAR first.

=cut
sub value {
	my ($self,$newval) = @_;
	$self{value} = $newval if (defined $newval);
	return $self{value} or undef;
}

=item insert SELF PROFILE

Inserts the item described by PROFILE into SELF and makes sure it is
packed to the correct edge. It is not usually called directly by the
user.

=cut
sub insert {
	my ($self,$class,@args) = @_;
	my $child = $self->SUPER::insert($class,@args);
	$child->pack(side => $self{side});
#	$self->prepArrow($child);
	return $child;
}

=item arrange STRING

Sets the profile's side attribute to STRING and repacks any existing
children to that side.

=cut
sub arrange {
	my ($self,$newside) = @_;
	$self{side} = $newside if (defined $newside);
	foreach ($self->get_widgets()) {
		$_->pack(side => $self{side});
	}
}

package ColorRow; #Replaces Gtk2::ColorSelectionDialog

=head2 ColorRow

Creates a row containing a label, an input box, and a button that
launches a color picker dialog.

=head3 Usage

 my $colRow = ColorRow->new(
 	owner => $mw,
	);
 $colRow->build("Header Color: ",{ color => "#BBEEFF" },{ text => "Wheel", });

=head3 Methods

=cut
use parent -norequire, 'HBox';

=item build SELF LABELTEXT ROWARGS BUTTTONARGS

Builds the row. The row will be labeled LABELTEXT, if it is defined and
not ''. Common ROWARGS include B<color>. Common BUTTONARGS include
B<text>.
Returns the input line so you can easily attach other signals to it or
pull its value directly.

=cut
sub build {
	my ($self,$ltxt,$exargs,$butargs) = @_;
	$self->pack( fill => 'x', expand => 0, side => "top", );
	if (defined $ltxt and $ltxt ne '') {
		$self->insert( Label =>
			text => $ltxt,
			pack => { fill => "none", expand => 0, },
			);
	}
	my $col = Prima::InputLine->new(
		owner => $self,
		name => 'coltxt',
		text => $exargs->{color},
		pack => { fill => 'x', expand => 1, padx => 3, side => "left", },
	);
	my $swatch = Prima::Button->new(
		owner => $self,
		name => 'colbut',
		text => "",
		readOnly => 1,
		selectable => 0,
		backColor => stringToColor($exargs->{color}),
		%$butargs,
		pack => { fill => 'none', expand => 0, padx => 3, side => "left", },
	);
	$swatch->set(onClick => sub {
			my $p = Prima::ColorDialog-> create( quality => 1, );
			$p->value(stringToColor($col->text()));
			my $ok = $p->execute();
			if ($ok == 1) {
				$col->text(sprintf "#%06x", $p-> value());
				matchColor($col,$swatch);
			}
		});
	$col->set(onChange => sub { return unless (length($col->text) >= 3); matchColor($col,$swatch); });
	$self->arrange();
	return $col; # for signal connection, value pulling, etc.
}

=item getKid NAME

Returns child widget named NAME, or undef, if not found.

=cut
sub getKid {
	my ($self,$target) = @_;
	foreach ($self->get_widgets()) {
		return $_ if ($_->name eq $target);
	}
	return undef;
}

=item getSwatch

Prerequisite: ColorRor->build()
Returns the row's color button.

=cut
sub getSwatch {
	my $self = shift;
	return getKid($self,'colbut');
}

=item getEntry

Prerequisite: ColorRor->build()
Returns the row's entry line.

=cut
sub getEntry {
	my $self = shift;
	return getKid($self,'coltxt');
}

=item matchColor MODEL TARGET

Applies the MODEL's text as a color string to the background of the
TARGET using L<stringToColor>().

=cut
sub matchColor {
	my ($model,$target) = @_;
	$target->backColor(stringToColor($model->text()));
}

=item stringToColor STRING

Converts a hex code to an integer Prima can use for a color value.
If STRING is shorter than three characters, returns 0 (black).
Returns an integer representing the given hexadecimal STRING.

=cut
sub stringToColor {
	my $string = shift;
	$string =~ s/^#//;
	return 0 unless (length($string) >= 3);
	if ($string =~ m/[\dA-Fa-f]{6}/) {
		return hex $string;
	} elsif ($string =~ m/[\dA-Fa-f]{3}/) {
		$string = substr($string,0,1)x2 . substr($string,1,1)x2 . substr($string,2,1)x2;
		return hex $string;
	}
	return 0;
}

package FontRow; #Replaces Gtk2::FontButton

=head2 FontRow

Creates a row containing a label, an entry box, and a button that
launches a font picker dialog.

=head3 Usage

 my $fontR = FontRow->new(
 	owner => $mw,
 	);
 my $bodyinputobject = $fontR->build("Body Font: ",{ font => "Arial 14" },{ text => "Select", });

=head3 Methods

=cut
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
	my $font = stringToFont($$exargs{font} or "Arial 14");
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
			$font = FontRow::clicked($lab->font());
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
	my ($string) = pop @_; # so it work with or without the unneeded FontRow argument
	if ($string =~ m/(.+) (\d+)/) { # use regex to grab name and size
		my $newfont = {
			name => $1,
			size => $2,
		};
		return $newfont;
	} else {
		if (0) { Common::errorOut('inline',0,string => "[I] An invalid or empty string was sent to stringToFont!"); }
		return {};
	}
}

=head2 HBox

A row widget.

=head3 Usage

 my $row = $target->insert( HBox => name => "row$i" );
 $row->insert( Label => text => "Name" );
 $row->insert( InputLine => name => 'namebox', text => '');

=head3 Methods

=cut
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

=item empty

Destroys all child widgets.

=cut
sub empty {
	my $self = shift;
	foreach ($self->get_widgets()) {
		$_->destroy();
	}
}
print ".";

=head2 VBox

A column widget.

=head3 Usage

 my $col = $target->insert( VBox => name => "column$i" );
 $col->insert( Label => text => "Entrees" );
 foreach (@list) {
  $col->insert( Label => text => $_);
 }

=head3 Methods

=cut
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

=item empty

Destroys all child widgets.

=cut
sub empty {
	my $self = shift;
	foreach ($self->get_widgets()) {
		$_->destroy();
	}
}
print ".";

package StatusBar; #Replaces Gtk2::Statusbar

=head2 StatusBar

A Statusbar widget.

To prevent an awkward-looking status bar, this item MUST be placed in
the window BEFORE any item that packs to the window's left or right!

=head3 Usage

 my $status = StatusBar->new(owner => $mainwindow)->prepare();

=head3 Methods

=cut
use vars qw(@ISA);
@ISA = qw(Prima::InputLine);

sub prepare {
	my $self = shift;
	$self->set(
		readOnly => 1,
		selectable => 0,
		text => ($self->text() or ""),
		backColor => $self->owner()->backColor(),
	);
	$self->pack( fill => 'x', expand => 0, side => "bottom", );
	return $self; # allows StatusBar->new()->prepare() call
}

sub push {
	my ($self,$text) = @_;
	$self->text($text);
	$self->repaint();
}
print ".";

package Table;

=head2 Table

Intended for generation of a table that works slightly more like GTK2
tables than Prima's Grid objects do.
B<Important:> This package is highly complex and highly experimental.

=head3 Usage

 my $tt = $parent->insert(Table =>
	backColor => 1279,
	pack => { fill => 'both', expand => 1, side => "left", },
 );
 $tt->place_in_table(0,0, Button => text => "Click Me" );
 $tt->place_in_table(1,1, Label => text => "Position 1,1" );
 $tt->adjust_rows_all(1);
 # A full adjustment is recommended after table has been populated.

=head3 Methods

=cut

use vars qw(@ISA);
@ISA = qw(VBox);


sub profile_default {
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		uniformHeight => 0, # uniform height, or dynamic?
		uniformWidth => 0, # uniform width, or dynamic?
		separator => 1, # separator between lines? (Not currently used)
		colStarts => [], # For storing column "left"s
		colWidths => [], # column widths, for calculating column "left"
		rowHeights => [], # row heights, for calculating row "top"
		uRowHeight => undef, # the tallest cell height
		uColWidth => undef, # the widest cell width
		modalRowCells => 0, # the column count in the row with the most columns
		remainder_column => undef, # The column whose width is variable (-1 puts extra space BEFORE first column, effectively justifying table to right)
		rows => [], # the rows of the table
		totalWidth => 0, # The table's total width
		maxWidth => 0, # the width of the table's available space
		cellMargin => 5, # the margin around the cells
		expand => 1, # expand to fill available width (versus setting right edge as sum of column widths)
		requiredSize => [], # width, height required by table's children and margins
		ownerResizable => 0, # should we ask our owner to get bigger when we get wider than max?
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub init {
	my $self = shift;
	foreach (qw( uniformHeight uniformWidth modalRowCells totalWidth maxWidth expand ownerResizable )) {
		$self->{$_} = 0;
	}
	foreach (qw( colStarts colWidths rowHeights rows)) {
		$self->{$_} = [];
	}
	$self->{uRowHeight} = undef;
	$self->{uColWidth} = undef;
	$self->{remainder_column} = undef;
	$self->{cellMargin} = 5;
	$self->{requiredSize} = [0,0];
	my %profile = $self-> SUPER::init(@_);	
	return %profile;
}

sub insert {
	my ($self,$class,@args) = @_;
	warn " [W] For finer control, use place_in_table(table,rownumber,columnumber,Widget,profile)\n";
	return place_in_table($self,-1,-1,$class,@args); # a fallback in case user calls insert, like other widgets
}

sub place_in_table {
	my ($self,$row,$column,$class,@args) = @_;
	my $child = $self->SUPER::insert($class,@args); # create the child
	my $r = $self->{rows}; # grab our list of rows
	my $max = ($#$r < 0 ? 0 : $#$r); # find the highest available row
#print "\nAsked to place in [$row,$column],";
	if ($max < $row) { # if higher than existing:
		my $newrow = []; # add a new row, as user indicated desire for a higher row
		push(@$r,$newrow); # push the new row into the list of rows
		$max = $#$r; # update max, since we're about to use it
		$row = $max; # whether we got to the desired row or not, put it in the new row
	} elsif ($row < 0) { # otherwise, if the row is less than 0, the user wants us to put it in the highest row:
		$row = ($#$r < 0 ? 0 : $#$r); # existing row is okay.
	}
	unless (defined $$r[$row]) { $$r[$row] = []; } # failsafe
	$r = $$r[$row]; # row established. Use this row.
	unless (defined $column and $column >= 0) { $column = ($#$r < 0 ? 0 : $#$r + 1);} # existing column is not allowed. Must be an unused column in the row.
	if ($column >= $self->{modalRowCells}) { # if requested column is too high:
		$column = $self->{modalRowCells}; # new column may be started, but only next to existing column
		$self->{modalRowCells}++; # update mode, since we've just made the table wider in cell units.
		$self->{totalWidth} = undef; # old total (pixel width) is no longer valid
	}
	# Currently, table may not contain more than 100 columns (It would be hard to fit that on most screens, and this gives some safety from infinite loops if I made a mistake).
	while (defined $$r[$column] and $column <= $self->{modalRowCells}) { $column++; } # don't overwrite an existing cell if given, e.g., place_in_table(0,0);
	if (defined $$r[$column]) { die "[E] Sorry. Asked to place object in an occupied space and couldn't recover by moving right"; }
	$self->{modalRowCells} += 1 if $column == $self->{modalRowCells};
	$$r[$column] = $child; # place our child in the row
#print " I'm placing child '" . $child->text() . "' in [$row,$column] @ ";
	my ($recol,$rerow) = $self->sizeCheck($row,$column,$child); # find out if child is bigger than existing column/row it's in and needs to be accomodated.
	$self->row_length_check($column + 1); # check if adding this widget makes this the widest row
	if ($recol) { # if child too wide, recalculate our columns
		$self->reset_column_widths();
	}
	if ($rerow) { # if child is too tall, recalculate our rows
		$self->reset_row_heights();
	}
	unless ($#{ $self->{colStarts} }) { ${ $self->{colStarts} }[0] = ($self->{cellMargin} or 0); } # initial column's left
	my $left = $self->get_column_left($r,$column); # find the child's column's left edge
	my $top = $self->get_row_top($row); # find the child's column's top edge
	my $margin = ($self->{cellMargin} or 0); # grab our margin
#print "(" . ($self->{totalWidth} + $left + $margin) . "," . -($top - $margin) . ").";
	$child->place(in => $self,); # make child our slave
	$self->position_cell_child($child,$left + $margin,$top - $margin); # position child in table canvas
	return $child;
}

sub get_row_top {
	my ($self,$position) = @_;
	my $top = (-$self->{cellMargin} or 0); # top starts at 0 because position function starts at paren'ts full height minus top.
	my @heights = @{ $self->{rowHeights} };
	foreach (0..$position-1) { # subtract the height of each row from the top value
		$top -= ($self->{uRowHeight} or $heights[$_] or 0) + ($self->{cellMargin} or 0);
	}
	return $top;
}

sub sizeCheck {
	my ($self,$r,$c,$widget) = @_;
	my ($wider,$taller) = (0,0);
	my $widths = $self->{colWidths};
	my $heights = $self->{rowHeights};
	my ($w,$h) = $widget->size();
	my $ow = ($self->{uColWidth} or $$widths[$c] or 0); # if using uniform widths, uCol should be set already, otherwise, use column width or 0 for old width
	my $oh = ($self->{uRowHeight} or $$heights[$r] or 0); # if using uniform heights, uRow should be set already, otherwise, use row height or 0 for old height
	if ($w > $ow) { # if widget is wider than old width:
		$$widths[$c] = $w; # replace column width
		$self->{uColWidth} = $w if ($self->{uniformWidth} and $w > ($self->{uColWidth} or 0)); # replace uniform width
		$wider++; # tell caller that we modified width
	}
	if ($h > $oh) { # if widget is taller than old height:
		$$heights[$r] = $h; # replace row height
		$self->{uRowHeight} = $h if ($self->{uniformHeight} and $h > ($self->{uRowHeight} or 0)); # replace uniform height
		$taller++; # tell caller that we modified height
	}
	return $wider,$taller; # return whether we changed them
}

sub row_length_check { # row length (number of cells in row) compared to reported row length and value for row with greatest length is replaced if not as big
	my ($self,$report) = @_;
	$self->{modalRowCells} = $report if $report > $self->{modalRowCells};
	return $self->{modalRowCells};
}

sub expand_width {
	my $self = shift;
	unless ($self->{maxWidth}) {
		$self->{maxWidth} = int(0.9 * $self->owner()->width());
	}
	# Expand if enabled:
#print "Expanding from $self->{totalWidth} to $self->{maxWidth}..." if (defined $self->{maxWidth} and (not defined $self->{totalWidth} or $self->{totalWidth} < $self->{maxWidth}));
	$self->{totalWidth} = $self->{maxWidth} if (defined $self->{maxWidth} and (not defined $self->{totalWidth} or $self->{totalWidth} < $self->{maxWidth}));
	if ($self->{totalWidth} > $self->{maxWidth} and $self->{ownerResizable}) {
warn "[W] BAD WIDTH: $self->{totalWidth}/$self->{maxWidth} :BAD\n";
		$self->{maxWidth} = $self->request_larger_space($self->{totalWidth} * (100/85));
		if ($self->{totalWidth} > $self->{maxWidth}) {
			warn "[W] Table width request wider than owner will become: $self->{totalWidth} vs. $self->{maxWidth}";
			$self->{totalWidth} = $self->{maxWidth};
			$self->{ownerResizable} = 0;
		}
print "Max width is now: $self->{maxWidth}.\n";
	}
}

sub reset_column_widths {
	my $self = shift;
	my $mode = 0;
	foreach my $row ($self->rows()) {
		$self->row_length_check(scalar @$row);
	}
	my $a = $self->{colWidths};
	my $starts = $self->{colStarts};
	foreach (0..$self->{modalRowCells} - 1) {
		$self->reset_column_width($_);
		if ($_ == 0) {
			$$starts[$_] = ($self->{cellMargin} or 0);
		} else {
			$$starts[$_] = ($self->{cellMargin} or 0) + ($self->{uColWidth} or $$a[$_-1]) + $$starts[$_-1];
		}
	}
	$self->{totalWidth} = ($self->{cellMargin} or 0);
	map { $self->{totalWidth} += ($self->{uColWidth} or $_) + ($self->{cellMargin} or 0) } @$a;
	$self->expand_width() if $self->{expand};
}

sub reset_column_width {
	my ($self,$column) = @_;
	my $a = $self->{colWidths};
	$$a[$column] = $self->get_widest_column_width($column);
	if ($self->{uniformWidth}) {
		$self->{uColWidth} = $$a[$column] if $$a[$column] > ($self->{uColWidth} or 0);
	}
}

sub reset_row_heights {
	my $self = shift;
	my @rows = $self->rows();
	foreach my $row (0..$#rows) {
		$self->reset_row_height($row);
	}
}

sub reset_row_height {
	my ($self,$row) = @_;
	my $a = $self->{rowHeights};
	$$a[$row] = $self->get_tallest_cell_height($row);
}

sub get_tallest_cell_height {
	my ($self,$row) = @_;
	my $height = 0;
	my $r = $self->rows($row);
	foreach (0..$#$r) {
		my ($w,$h) = $self->cellSize($r,$_);
		unless (defined $h) { next; }
		$height = $h if $h > $height;
	}
	if ($self->{uniformHeight}) {
		$self->{uRowHeight} = $height if $height > ($self->{uRowHeight} or 0);
	}
	return $height;
}

sub get_widest_column_width {
	my ($self,$column) = @_;
	my $width = 0;
	foreach (@{ $self->{rows} }) {
		my ($w,$h) = $self->cellSize($_,$column);
		unless (defined $w) { next; }
		$width = $w if ($w > $width and $w != 1);
	}
#	print "Decision: $width is the needed width for column $column.\n";
	if ($self->{uniformWidth}) {
		$self->{uColWidth} = $width if $width > ($self->{uColWidth} or 0);
	}
	return $width;
}

sub cellSize {
	my ($self,$rowref,$position,$newwidth,$newheight) = @_;
	unless (defined $self->{colWidths}) {
		$self->{colWidths} = [];
	}
	unless (defined $newwidth) {
		if (defined $$rowref[$position]) {
			my $child = $$rowref[$position];
			my ($w,$h) = $child->size();
			$w = $self->{uColWidth} if $self->{uniformWidth};
			$h = $self->{uRowHeight} if $self->{uniformHeight};
			return $w,$h;
		} else {
			return undef,undef;
		}
	}
die "resizing cell widgets is not yet supported";
}

sub position_cell_child {
	my ($self,$child,$left,$top) = @_;
	$child->place(relx => 0, x => $left, rely => 1.0, y => $top, anchor => "nw", );
	if (0) { print "$child now at $left x $top.\n"; }
}

sub adjust_column {
	my ($self,$column) = @_;
	$self->get_widest_column_width($column);
	foreach ($self->rows()) {
		my $child = $$_[$column];
		unless (defined $child) { next; }  # dont't try to adjust undef cell
		$self->position_cell_child($child,$self->get_column_left($_,$column),$child->top());
	}
}

sub adjust_row {
	my ($self,$row,$full) = @_;
	my $r = $self->rows($row);
	my $top = $self->get_row_top($row); # get row top
	my $i = -1;
	foreach (@$r) {
		$i++;
		unless (defined $_) { next; } # dont't try to adjust undef cell
		my $left = ($full ? $self->get_column_left($r,$i) : $_->left()); # If not making a full adjustment (i.e., if adjusting row top only), trust the child's existing left.
		$self->position_cell_child($_,$left,$top); # place at new height
	}
}

sub rows { # provides a particular row (ID $row) or an array of all rows
	my ($self,$row) = @_;
	my $r = $self->{rows};
	if (defined $row) {
		return $$r[$row] unless $row < 0; # return specified row,
		return scalar @$r; # or number of rows (aka, next rowID)
	}
	return @$r;
}

sub adjust_columns_all {
	my $self = shift;
	my $mode = 0;
	foreach my $r ($self->rows()) {
		$mode = $self->row_length_check($#$r);
	}
	foreach (0..$mode - 1) {
		$self->adjust_column($_);
	}
}

sub adjust_rows_all {
	my ($self,$full) = @_;
	my $rows = $self->{rows};
	foreach (0..$#$rows) {
#		print "\nAdjusting row $_...";
		$self->adjust_row($_,$full);
	}
}

sub get_column_left {
	my ($self,$rowr,$position,$rightonly) = @_;
	if (0) { print "\nS: $self R: $rowr P: $position\n"; }
	my $a = $self->{colWidths};
	# 1. Find widths of columns before this one. This is our minimum left.
	unless (defined ${ $self->{colStarts} }[$position]) {
		print "<$position:?>";
		$self->reset_column_widths();
	}
	my $left = ${ $self->{colStarts} }[$position];
	my $right = $self->{totalWidth};
	unless (defined $right and $right > 1) {
		$right += ($self->{cellMargin} or 0);
		map { $right += ($self->{uColWidth} or $_) + ($self->{cellMargin} or 0) } @$a;
		$self->{totalWidth} = $right;
	}
	$right = $self->{totalWidth};
	$self->expand_width() if $self->{expand};
	if ($position > ($self->{remainder_column} or $self->{modalRowCells})) { # if column is higher than remainder column, build position from right
		# 2. Calculate distances from right margin. This is our theoretical left.
		foreach (reverse ($position..$self->{modalRowCells})) {
			my $w = ($self->{uColWidth} or $$a[$_-1]);
			$right -= $w + ($self->{cellMargin} or 0); # subtract column's width (and margin)
		}
		# 3. Use whichever left is higher, theoretical or minimum.
		$left = $right if $right > $left;
	}
	return $left;
}

sub request_larger_space {
	my ($self,$width,$height) = @_;
	my $owner = $self->owner();
	print "Owner size was: (" . join(',',$owner->size()) . ") ";
	$self->sizeMin(($width or $self->width()),($height or $self->height()));
	my @s = $self->sizeMin();
	$self->requires($width,$height);
	print "Asking for $s[0],$s[1]...";
	# if one isn't specified, use owner's current size for that dimension
	$s[0] = $owner->width() unless defined $s[0] and $s[0] > $owner->width();
	$s[1] = $owner->height() unless defined $s[1] and $s[1] > $owner->height();
	print "Asking for $s[0],$s[1]...";
	$owner->size(@s);
	@s = $owner->size();
	print "is: (" . join(',',@s) . ")\n";
	return @s;
}

sub requires {
	my ($self,$w,$h) = @_;
	unless (defined $w and defined $h) {
		return @{ ($self->{requiredSize} or [0,0]) };
	}
	$self->{requiredSize} = [$w,$h];
}

sub describe_row {
	my ($self,$row,$verb) = @_;
	my $r = $self->rows($row);
	unless ($verb) {
		print "Row $row contains " . scalar @$r . " children.\n";
		return;
	}
	print "Row $row: [";
	unless ($verb < 1) {
		foreach (0..$#$r) {
			my $c = $$r[$_];
			print "$_:" . (defined $c ? $c->text() : "(undef)");
			unless ($verb < 2 or not defined $c) {
				print " @ (" . $c->left() . "x" . $c->top() . ")";
			}
			print ", ";
		}
	}
	print "]\n";
}

sub describe {
	my ($self,$verb) = @_;
	my @rows = $self->rows();
	print "Table " . ($self->name() or "---") . " has " . (scalar @rows) . " rows:\n";
	foreach (0..$#rows) {
		$self->describe_row($_,$verb);
	}
}

sub expand {
	my ($self,$expand) = @_;
	if (defined $expand) { $self->{expand} = $expand; }
	return $self->{expand};
}

sub use_uniform_heights {
	$_[0]->{uniformHeight} = $_[1];
}

sub use_uniform_widths {
	$_[0]->{uniformWidth} = $_[1];
}

sub remainder_column { # Sets remainder column. -1 will right-justify table if there's room. An undef or a value higher than the number of table columns will left-justify the table.
	$_[0]->{remainder_column} = $_[1]; # A valid table column will designate a remainder column, which will result in a column with dynamic right padding width.
}
print "."; # end of Table

package PGK;

=head2 PGK functions

=item Pdie MESSAGE

Causes program to die by closing the main window and exiting.
MESSAGE will be displayed in a message box before dying.

=cut
sub Pdie {
	my $message = shift;
	my $w = getGUI('mainWin');
	message_box("Fatal Error",$message,mb::Yes | mb::Error);
	$w->close();
	exit(-1);
}
print ".";

sub Pwait {
	# Placeholder for if I ever figure out how to do a non-blocking sleep function in Prima
	my $duration = shift or 1;
	my $start = time();
	my $end = ($start+$duration);
	while ($end > time()) {
#		while (events_pending()) {
			$::application->yield();
#		}
		# 10ms sleep.
		# Not much, but prevents processor spin without making waiting dialogs unresponsive.
		select(undef,undef,undef,0.01);
	}
	return 0;
}
print ".";

=item applyFont TYPE WIDGET

Attempts to get the font called TYPE from the configuration's Font
section (as a name and size) and apply it as a Prima font to the given
Prima WIDGET.
If no WIDGET is given, returns the font profile. This is useful in
object creation without a reference saved.
No return value.

=cut
sub applyFont {
	my ($key,$widget) = @_;
	if ($key eq 'welcomehead') { return FontRow->stringToFont("Arial 24"); }
	return undef unless (defined $key); # just silently fail if no key given.
	unless (defined $widget) { return FontRow->stringToFont(FIO::config('Font',$key) or FIO::config('Font','body') or ""); } # return the font if no wifget given (for use in insert() profiles).
	$widget->set( font => FontRow->stringToFont(FIO::config('Font',$key) or ""),); # apply the font; Yay!
}
print ".";

=item askbox WINDOW TITLE DEFAULTS QUESTIONS

Makes and displays a dialog owned by WINDOW with TITLE in the titlebar,
asking for the answer(s) to a given list of QUESTIONS, either a single
scalar, or an array of key/question pairs whose answers will be stored
in a hash with the given keys. DEFAULTS may be passed in using a hasref
whose keys match the even-indexed values in the QUESTIONS array.

=cut
sub askbox {
	my ($parent,$tibar,$defaults,@questions) = @_; # using an array allows single scalar question and preserved order of questions asked.
	my $numq = int((scalar @questions / 2)+ 0.5);
#	print "Asking $numq questions...\n";
	my $height = ($numq * 25) + 75;
	my $askbox = Prima::Dialog->create(
		centered => 1,
		borderStyle => bs::Sizeable,
		onTop => 1,
		width => 400,
		height => $height,
		owner => $parent,
		text => $tibar,
		valignment => ta::Middle,
		alignment => ta::Left,
	);
	my $extras = {};
	my $buttons = mb::OkCancel;
	my %answers;
	my $vbox = $askbox->insert( VBox => autowidth => 1, pack => { fill => 'both', expand => 0, }, );
	if (scalar @questions % 2) { # not a valid hash; assuming a single question
		$numq = 0;
		@questions = (one => $questions[0]); # discard all but the first element. Add a key for use by hash unpacker
	}
	my $i = 0;
	until ($i > $#questions) {
		my $row = labelBox($vbox,$questions[$i+1],"q$i",'h',boxfill=>'both', labfill => 'none', margin => 7, );
		my $ans = $row->insert(InputLine => text => '', );
		my $key = $questions[$i];
		$ans->text($$defaults{$key}) if exists $$defaults{$key};
		$ans->onChange( sub { $answers{$key} = $ans->text; } );
		$answers{$key} = $ans->text; # in case the default is acceptable
		$i += 2;
	}
	my $spacer = $vbox->insert( Label => text => " ", pack => { fill => 'both', expand => 1 }, );
	my $fresh = Prima::MsgBox::insert_buttons( $askbox, $buttons, $extras); # not reinventing wheel
	$fresh->set( font => applyFont('button'), );
	$askbox->execute;
	if ($numq == 0) {
		return $answers{one};
	} else {
		return %answers;
	}
}
print ".";

=item convertColor COLOR FORCE

Takes a COLOR as either an integer value recognized by Prima or a hex
string as #nnn or #nnnnnn.
If FORCE is 1, the program will send the value to the converter even if
it is only numerals (useful for sending 0x999  as '999' (without the #)
This is useful for calling from an input box, which we don't expect the
user to be putting valid Prima integers into.
Returns an INTEGER.

=cut
sub convertColor {
	my ($color,$force) = @_;
	return undef unless (defined $color); # undef if no color given
	return $color unless ($force or $color =~ m/^#/); # return color unchanged unless it starts with '#' (allows passing integer straight through, as saveConf is going to write it as int, but we want user to be able to write it as #ccf).
	return ColorRow::stringToColor($color); # convert e.g. "#ccf" to integer needed by Prima
}
print ".";

=item createMainWin VERSION WIDTH HEIGHT

Makes the main window and passes back a hashref to the window set
(allowing easy access to the main window, the statusbar, etc.). The
specified VERSION (required) goes in the titlebar. If a WIDTH and
HEIGHT are specified, the window is resized to these values. However,
if the configuration option to save window position is enabled, these
values will be overridden by the stored size.
Returns a HASREF.

=cut
my %windowset;
sub createMainWin {
	my ($program,$version,$w,$h) = @_;
	my $position;
	if (FIO::config('Main','savepos')) {
		unless ($w and $h) { $w = ($w or FIO::config('Main','width') or 800); $h = ($h or FIO::config('Main','height') or 500); }
		$position = [(FIO::config('Main','left') or undef),(FIO::config('Main','top') or undef)];
		unless (defined $$position[0] and defined $$position[1]) { $position = []; }
	}
	$w = ($w or 800); $h = ($h or 500);
	my $window = Prima::MainWindow->new(
		text => (FIO::config('Custom','program') or "$program") . " v.$version",
		size => [$w,$h],
		origin => $position,
		font => applyFont('body'),
	);
	$window->onClose( sub { FlexSQL::closeDB(); my $err = PGK::savePos($window) if (FIO::config('Main','savepos')); Common::errorOut('PGK::savePos',$err) if $err; } );
	$windowset{mainWin} = $window;
	$window->set( menuItems => PGUI::buildMenus(\%windowset));
	$windowset{menu} = $window->menu();
	#pack it all into the hash for main program use
	$windowset{status} = getStatus($window);
	return \%windowset;
}
print ".";

=item getGUI KEY

Gets (or creates if not present) the GUI, or returns a distinct part of
the GUI, such as the stausbar or the main window.
Returns a HASHREF, an OBJECT REFERENCE if a valid KEY was supplied, or
UNDEF if an invalid KEY was supplied.

=cut
sub getGUI {
	unless (defined keys %windowset) { die "getGUI cannot be called until main window has been created. Use createMainWin() first"; }
	my $key = shift;
	if (defined $key) {
		if (exists $windowset{$key}) {
			return $windowset{$key};
		} else {
			return undef;
		}
	}
	return \%windowset;
}
print ".";

=item getStatus PARENT

Places a statusbar in PARENT window, or returns the existing statusbar.
Returns an OBJECT REFERENCE to the statustbar.

=cut
my $status = undef;
sub getStatus {
	my $win = shift;
	unless(defined $status) {
		unless (defined $win) { $win = getGUI(); }
		$status = StatusBar->new(owner => $win)->prepare();
	}
	return $status;
}
print ".";

=item getTabByCode CODE

Attempts to find the tab page labeled CODE and return its page ID.
Returns an INTEGER, or UNDEF.

=cut
sub getTabByCode { # for definitively finding page ID of tabs...
	my $code = shift;
	my $tabs = (getGUI("tablist") or []);
	return Common::findIn($code,@$tabs);
}
print ".";

=item labelBox CONTAINER TEXT NAME ORIENTATION HASH

This function builds a vertical or horizontal box (depending on the
value of ORIENTATION; defaults to 'V' if missing or malformed) named
NAME and containing a label that says TEXT inside CONTAINER.

These additional arguments may be passed in the optional HASH:

* boxfill - How will the new box fill its parent? (pack=>fill values)

* boxex - Will the new box expand (pack=>expand values)

* margin - Padding around the new box

* labfill - How will the label fill the new box? (pack=>fill values)

* labex - Will the label expand (pack=>expand values)

Returns a VBox or HBox named NAME.

=cut
sub labelBox {
	my ($parent,$label,$name,$orientation,%args) = @_;
	die "[E] Missing parameter to labelBox" unless (defined $parent and defined $label and defined $name);
	my $box;
	unless (defined $orientation && $orientation =~ /[Hh]/) {
		$box = $parent->insert( VBox => name => "$name", alignment => ta::Left, );
		$box->pack( fill => ($args{boxfill} or 'none'), expand => ($args{boxex} or 1), padx => ($args{margin} or 1), pady => ($args{margin} or 1), );
	} else {
		$box = $parent->insert( HBox => name => "$name", alignment => ta::Left, );
		$box->pack( fill => ($args{boxfill} or 'none'), expand => ($args{boxex} or 1), padx => ($args{margin} or 1), pady => ($args{margin} or 1), );
	}
	$box->insert( Label => text => "$label", valignment => ta::Middle, alignment => ta::Left, pack => { fill => ($args{labfill} or 'x'), expand => ($args{labex} or 0), }  );
	return $box;
}
print ".";

=item refreshUI GUI HANDLE

This function refreshes the user interface. I think.

=cut
sub refreshUI {
	my ($gui,$dbh) = @_;
	$gui = getGUI() unless (defined $$gui{status});
	$dbh = FlexSQL::getDB() unless (defined $dbh);
	print "Refreshing UI...\n";
	PGUI::populateMainWin($dbh,$gui,1);
}
print ".";

Common::registerErrors('PGK::savePos',"[E] savePos was not passed a valid object!","[W] savePos requires an object to measure.");

=item savePos WINDOW

Given a WINDOW (or other oject with a size and origin), saves its
position and size in the configuration file.
Registers error codes.
Returns 0 on success.

=cut
sub savePos {
	my $o = shift;
	return 2 unless (defined $o);
	my ($w,$h,$l,$t) = ($o->size,$o->origin);
	unless (defined $w && defined $h && defined $t && defined $l) {
		return 1;
	}
	FIO::config('Main','width',$w);
	FIO::config('Main','height',$h);
	FIO::config('Main','top',$t);
	FIO::config('Main','left',$l);
	FIO::saveConf();
	return 0;
}
print ".";

=item sayBox PARENT TEXT

Makes a dialog box with a message of TEXT and an owner of PARENT.
GUI equivalent to 'print TEXT;'.
No return value.

=cut
sub sayBox {
	my ($parent,$text) = @_;
	message($text,owner=>$parent);
}
print ".";

Common::registerErrors('PGK::start',"[E] Exiting (no DB).","[E] Could neither find nor initialize tables.");
=item start GUI

Tries to load the database and fill the main window of the GUI.
Registers errors.
Returns error codes.
Returns 0 on success.

=cut
sub startwithDB {
	my ($gui,$program,$recursion) = @_;
	$recursion = 0 unless defined $recursion;
	die "Infinite loop" if $recursion > 10;
	my $window = $$gui{mainWin};
	my $box = $window->insert( VBox => name => "splashbox", pack => { fill => 'both', expand => 1, padx => 5, pady => 5, side => 'left', }, );
	my $label = $box->insert( Label => text => "Loading " . (config('Custom','program') or "$program") . "...", pack => { fill=> "x", expand => 0, side => "left", relx => 0.5, padx => 5, pady => 5,},);
	my $text = $$gui{status};
	$text->push("Loading database config...");
	my $dbh;
	$box->insert( Label => text => "Welcome to $program!", font => PGK::applyFont('welcomehead'), autoHeight => 1, );
	unless (defined config('DB','type') and defined config('DB','host')) {
		$box->insert( Button => text => "Quit without configuring", onClick => sub { $window->close(); },);
		$text->push("Getting settings from user...");
		$box->insert( Label => text => "All these settings can be changed later in the Prefereces dialog.\nChoose your database type.\nIf you have a SQL server, use MySQL.\nIf you can't use MySQL, choose SQLite to use a local file as a database.", autoHeight => 1, );
		my $dbtype = $box->insert( XButtons => name => "dbtype", pack => {fill=>'none',expand=>0});
		$dbtype->arrange('left');
		my @presets = ((defined config('DB','type') ? (config('DB','type') eq 'L' ? 1 : 0) : 0),"M","MySQL","L","SQLite");
		$dbtype-> build("Database type:",@presets);

		my $dboptbox = $box->insert( HBox => name => 'dbopts');
		my $mysqlopts = $dboptbox->insert( VBox => name => 'mysql', pack => {fill => 'x',expand => 0},);
		$mysqlopts->hide() if ($dbtype->value eq 'L');
		$dbtype->onChange( sub { $mysqlopts->hide() if ($dbtype->value eq 'L') or $mysqlopts->show; });
		# unless type is SQLite:
		my $hostbox = labelBox($mysqlopts,"Server address:",'servbox','H',);
		my $host = $hostbox->insert( InputLine => text => (config('DB','host') or "127.0.0.1"));
		my $umand = $mysqlopts->insert( CheckBox => name => "Username required", checked => (defined config('DB','uname') ? 1 : 0));
		# ask user for SQL username, if needed by server (might not be, for localhost)
		my $ubox = labelBox($mysqlopts,"Username",'ubox','h');
		$ubox->hide unless $umand->checked;
		$umand->onClick(sub { $ubox->show if $umand->checked or $ubox->hide;});
		my $uname = $ubox->insert( InputLine => text => (config('DB','user') or ""));
		my $pmand = $mysqlopts->insert( CheckBox => name => "Password required", checked => (config('DB','password') or 1));

		# type is SQLite:
		my $liteopts = $dboptbox->insert( VBox => name => 'sqlite', pack => {fill => 'x',expand => 0},);
		$liteopts->hide() if ($dbtype->value ne 'L');
		$dbtype->onChange( sub { $liteopts->hide() if ($dbtype->value ne 'L') or $liteopts->show; });
# TODO: Replace with SaveDialog to choose DB filename?
		my $filebox = labelBox($liteopts,"Database filename:",'filebox','h');
		my $file = $filebox->insert( InputLine => text => (config('DB','host') or Sui::passData('dbname') . ".dbl"));
		$filebox->insert( Button => text => "Choose", onClick => sub { my $o = Prima::OpenDialog->new( filter => [['Databases' => '*.db*'],['All' => '*'],],directory => '.',); $file->text = $o->fileName if $o->execute; }, hint => "Click here to choose an existing SQLite database file.", );
		$box->insert( Button => text => "Save", onClick => sub {
			$box->hide();
			$text->push("Saving database type...");
			config('DB','type',$dbtype->value);
			config('DB','host',($dbtype->value eq 'L' ? $file->text : $host->text)); config('DB','user',$uname->text); config('DB','password',($dbtype->value eq 'L' ? 0 : $pmand->checked));
			FIO::saveConf();
			$box->destroy();
			startwithDB($gui,$program,$recursion + 1);
		});
	} else {
		$box->insert( Label => text => "Establishing database connection. Please wait...");
		my ($base,$uname,$host,$pw) = (config('DB','type',undef),config('DB','user',undef),config('DB','host',undef),config('DB','password',undef));
		unless ($pw and $base eq 'M') { # if no password needed:
			my ($dbh,$error) = loadDB($base,$host,'',$uname,$text,$box->insert( Label => text => ""));
			$box->destroy();
			unless (defined $dbh) { Common::errorOut('PGK::loadDB',$error); return $error; }
			PGUI::populateMainWin($dbh,$gui);
		} else { # ask for password:
			my $passrow = labelBox($box,"Enter password for $uname\@$host:",'pass','h');
			my $passwd = $passrow->insert( InputLine => text => '', writeOnly => 1,);
			$passrow->insert( Button => text => "Send", onClick => sub {
				my ($dbh,$error) = loadDB($base,$host,$passwd->text,$uname,$text,$box->insert( Label => text => ""));
				$box->destroy();
				unless (defined $dbh) { Common::errorOut('PGK::loadDB',$error); return $error; }
				PGUI::populateMainWin($dbh,$gui);
			}, );
		}
	}
	return 0;
}
print ".";

Common::registerErrors('PGK::loadDB',"[E] Exiting (no DB).","[E] Could neither find nor initialize tables.");
=item loadDB DBTYPE HOST PASSWORD USER STATUSBAR

Attempts to load the database.
Registers errors.
Returns error codes (undef,ERROR).
Returns database HANDLE,0 on success.

=cut
sub loadDB {
	my ($base,$host,$passwd,$uname,$text,$widget) = @_;
	$text->push("Connecting to database...");
	my ($dbh,$error,$errstr) = FlexSQL::getDB($base,$host,Sui::passData('dbname'),$passwd,$uname);
	unless (defined $dbh) { # error handling
		Common::errorOut('FlexSQL::getDB',$error,string => $errstr);
	} else {
		Common::errorOut('FlexSQL::getDB',0);
		$text->push("Connected.");
	}
	if ($error =~ m/Unknown database/) { # rudimentary detection of first run
		$text->push("Database not found. Attempting to initialize...");
		($dbh,$error) = FlexSQL::makeDB($base,$host,Sui::passData('dbname'),$passwd,$uname);
	}
	unless (defined $dbh) { # error handling
		Pdie("ERROR: $error");
		return undef,1;
	} else {
		$text->push("Connected.");
	}
	foreach (keys %{ Sui::passData('tablekeys') }) {
		unless (FlexSQL::table_exists($dbh,$_)) {
			$text->push("Attempting to initialize database tables...");
			($dbh, $error) = FlexSQL::makeTables($dbh,$widget);
			return (undef,2) unless (defined $dbh);
		}
	}
	$text->push("Done loading database.");
	return $dbh,0;
}
print ".";

print " OK; ";
1;
