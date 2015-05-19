package GK; # Graphic Kit

print __PACKAGE__;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( ColorRow FontRow VBox HBox Table );
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
		$string = substr($string,0,1)x2 . substr($string,1,1)x2 . substr($string,2,1)x2;
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
		selectable => 0,
		text => ($self->text() or ""),
		backColor => $self->owner()->backColor(),
	);
	$self->pack( fill => 'x', expand => 0, side => "bottom", );
	return $self; # allows StatusBar->new()->prepare() call
}
print ".";

package Table;
# EXAMPLE:
# my $tt = $parent->insert(Table => backColor => 1279, pack => { fill => 'both', expand => 1, side => "left", }, );
# $tt->place_in_table(0,0, Button => text => "Click Me" );
# $tt->place_in_table(1,1, Label => text => "Position 1,1" );
# $tt->adjust_rows_all(1); # A full adjustment is recommended after table has been populated.

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
		maxWidth => 0, # the width of the table's avaiable space
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
	} elsif ($row < 0) { # otherwise, if the row is less than 0, assume the user wants us to put it in the highest row:
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
	my $w = $self->get_widest_column_width($column);
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

package GK;

print ".";

print " OK; ";
1;
