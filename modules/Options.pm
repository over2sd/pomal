package Options;

use strict;
use warnings;
use Prima qw(Application Buttons MsgBox FrameSet StdDlg Sliders Notebooks ComboBox);
print __PACKAGE__;

use FIO qw( config );

=item mkOptBox GUI HASH

Builds and displays a dialog box of options described in provided HASH.

=cut
sub mkOptBox {
	# need: guiset (for setting window marker, so if it exists, I can present the window instead of recreating it?)
	my ($gui,%opts) = @_;
	my $changes = 0;
	my $pos = 0;
	my $page = 0;
	my $optbox;
	my $running = 1;
	my $toSave = {};
	$optbox = Prima::Window->create( text => (config('Custom','options') or "Preferences"), owner => $$gui{mainWin}, size => [640,480] ); # Make a window
	my $vb = PGK::labelBox($optbox,"Options",'optlist','v',boxfill => 'both', boxex => 1);
	my %args;
	my @tablist;
	foreach my $k (sort keys %opts) {
		my @o = @{ $opts{$k} };
		next unless ($o[0] eq "l");
		push(@tablist,$o[1]);
	}
	if (defined config('UI','tabson')) { $args{orientation} = (config('UI','tabson') eq "bottom" ? tno::Bottom : tno::Top); } # set tab position based on config option
	my $buttons = $vb->insert( HBox => name => 'buttons', pack => { fill => 'x', side => 'left',},);
	my $pages = $vb->insert( TabbedScrollNotebook =>
		style => tns::Simple,
		tabs => \@tablist,
		name => 'optionbox',
		tabsetProfile => {colored => 0, %args, },
		pack => { fill => 'both', expand => 1, pady => 3, side => "left", },
	);
	my ($curtab,$section);
	my $spacer = $buttons->insert( Label => text => " ", pack => { fill => 'x', expand => 1, });
	my $cancelB = $buttons->insert( Button => text => "Cancel", onClick => sub { $optbox->destroy(); });
	my $saveB = $buttons->insert( Button => text => "Save", enabled => 0, );
	$saveB->onClick(sub { saveFromOpt($saveB,[$optbox,$toSave]); });
	foreach my $k (sort keys %opts) {
		my @o = @{ $opts{$k} };
		if ($o[0] eq "l") { # label for tab
			if (defined $curtab) { $curtab->insert( Label => text => " - - - ", pack => { fill => 'both', expand => 1, }, ); }
			$curtab = $pages->insert_to_page($page,VBox => name => 'page$page', pack => { fill => "both", expand => 1 }, ); # make a vbox to put all the options in a given Section in
			my $l = $curtab->insert( Label => text => $o[1] ); # for each section, make a notebook page
#			$curtab = PGUI::labelBox($pages,$o[1],$o[2],'v');
			$section = $o[2];
			$page++;
		}elsif (defined $section and defined $curtab) { # not first option in list
			addModOpts($curtab,$section,\$changes,$pos,$saveB,$toSave,@o); # build and add option to page
#print "Opt-$k: " . join(", ",@o) . "\n";
			$pos++;
		} else {
			warn "First option in hash was not a label! mkOptBox() needs a label for the first tab";
			if (config('Main','fatalerr')) { PGK::Pdie($$gui{mainWin},"mkOptBox not given label in first hash set"); }
			return -1;
		}
	}
	return;
}
print ".";

#####=> Migration marker
sub addModOpts {
	my ($parent,$s,$change,$pos,$applyBut,$saveHash,@a) = @_;
	unless (scalar @a > 2) { print "\n[W] Option array too short: @a - length: ". scalar @a . "."; return; } # malformed option, obviously
	my $item;
	my $t = $a[0];
	my $lab = $a[1];
	my $key = $a[2];
	my $col = ($a[3] or "#FF0000");
	splice @a, 0, 4; # leave 4-n in array
	for ($t) {
		if (/c/) {
			my $cb = $parent->insert( CheckBox => text => $lab );
			my $checkit = (config($s,$key) or 0);
			$checkit = (("$checkit" eq "1" or "$checkit" =~ /[Yy]/) ? 1 : 0);
			$cb->checked($checkit);
			$cb->onClick( sub { optChange($cb,[$change,$pos,$saveHash,$s,$key,$applyBut,(config($s,$key) or 0)]); } );
		}elsif (/d/) { # Date row (with calendar button if option enabled)
PGUI::devHelp($parent,"Date type options ($key)");

		}elsif (/f/) {
			my $f = FontRow->new( owner => $parent );
			my $e = $f->build($lab,{ font => (config($s,$key) or "") },{ text => "Select", });
			$e->onChange( sub { optChange($e,[$change,$pos,$saveHash,$s,$key,$applyBut,(config($s,$key) or "")]); } );
		}elsif (/g/) {
			$parent->insert( Label => text => $lab, alignment => ta::Center, pack => { fill => 'x', expand => 0 }, font => PGK::applyFont($key));
		}elsif (/m/) {
PGUI::devHelp($parent,"Mask page options ($key)");
		}elsif (/n/) {
			my $col = (config($s,$key) or $col); # pull value from config, if present
			buildNumericRow($parent,$saveHash,$applyBut,$lab,$s,$key,$col,$change,$pos,@a);
		}elsif (/r/) {
			my $col = (config($s,$key) or $col);
			buildComboRow($parent,$saveHash,$applyBut,$lab,$s,$key,$col,$change,$pos,$_,@a);
		}elsif (/s/) {
			my $val = (config($s,$key) or "");
			foreach my $i (0..$#a) { # find the value among the options
				if ($a[$i] eq $val) { $col = $i; }
			}
			buildComboRow($parent,$saveHash,$applyBut,$lab,$s,$key,$col,$change,$pos,$_,@a);
		}elsif (/t/) {
			my $row = PGK::labelBox($parent,$lab,'textrow','h');
			my $e = $row->insert( InputLine => text => (config($s,$key) or "") );
			$e->onChange( sub { optChange($e,[$change,$pos,$saveHash,$s,$key,$applyBut,(config($s,$key) or "")]); });
		}elsif (/x/) {
			buildColorRow($parent,$saveHash,$applyBut,$lab,$s,$key,$col,$change,$pos);
		} else {
			warn "Ignoring bad option $a[0].\n";
			return;
		}
	}
}
print ".";

sub mayApply {
	my ($button,$maskref) = @_;
	unless ($$maskref == 0) { $button->enabled(1); }
}
print ".";

sub optChange {
	my ($caller,$args,$altargs) = @_;
	unless ($args =~ m/ARRAY/) { $args = $altargs; } # combobox sends an extraneous event argument before the user args
	my ($maskref,$p,$href,$sec,$k,$aButton,$default,$rbval) = @$args;
#	print "my (\$maskref,\$p,\$href,\$sec,\$k,\$aButton,\$default,\$rbval)\n";
#	printf("my (%s,%s,%s,%s,%s,%s,%s,%s)\n",$maskref,$p,$href,$sec,$k,$aButton,$default,$rbval);
	my $value;
	for (ref($caller)) {
		if (/CheckBox/) {
			$value = $caller->checked or 0;
			$value = ($value ? 1 : 0);
		} elsif (/InputLine/) {
			$value = $caller->text;
		} elsif (/ComboBox/) {
			$value = $caller->text;
		} elsif (/FontButton/) {
			$value = $caller->get_font_name();
		} elsif (/RadioButton/) {
			($caller->get_active() ? $value = $rbval : return );
		} elsif (/XButtons/ or /MaskGroup/) {
			$value = $caller->value;
		} elsif (/SpinEdit/ or /SpinButton/ or /AltSpinButton/) {
			$value = $caller->value;
		} else {
			warn "Fail! '$_' (" . (defined $default ? $default : "undef") . ") unhandled";
		}
#				$value = $caller->get_value_as_int();
#				$value = $caller->get_value_as_int() * 100;
#		print "$_: $value\n";
	}
	unless (defined $default) {
		$$maskref = Common::setBit($p,$$maskref);  $$href{$sec}{$k} = $value or 0;
		mayApply($aButton,$maskref);
	} else {
		unless ($value eq $default) {
			$$maskref = Common::setBit($p,$$maskref); $$href{$sec}{$k} = $value or 0;
			mayApply($aButton,$maskref);
		} else {
			$$maskref = Common::unsetBit($p,$$maskref); delete $$href{$sec}{$k};
		}
	}
}
print ".";

sub saveFromOpt {
	my ($caller,$args) = @_;
	my ($window,$href) = @$args;
	$caller->enabled(0);
	foreach my $s (keys %$href) {
#		print "Section $s:\n";
		foreach (keys %{ $$href{$s} }) {
#			print "	Key $_: $$href{$s}{$_}\n";
			config($s,$_,($$href{$s}{$_} or 0));
		}
	}
	my $status = PGUI::getGUI("status");
	FIO::saveConf();
	$status->push("Options applied.");
	$window->destroy();
	# TODO: check here to see if something potentially crash-inducing has been changed, and shut down cleanly, instead, after informing user that a restart is required.
	formatTooltips(); # set tooltip format, in case it was changed.
	PGK::refreshUI(PGUI::getGUI(),FlexSQL::getDB()); # refresh the UI
}
print ".";

sub buildColorRow {
	my ($box,$options,$applyBut,$lab,$s,$key,$col,$change,$pos) = @_;
	my $row = ColorRow->new(
		owner => $box,
	);
	$row->build($lab,{ color => (config($s,$key) or $col) },{ text => "Select", });
	my $e = $row->getEntry();
#my $text = sprintf("Color me #%06x!\n",$row->getSwatch()->backColor);
#	print $text;
	$e->onChange( sub { optChange($e,[$change,$pos,$options,$s,$key,$applyBut,(config($s,$key) or "")]); });
# TODO: Change background of $e to color selected in color dialog
}
print ".";

sub buildComboRow {
	my ($box,$options,$applyBut,$lab,$s,$key,$d,$changes,$pos,$optyp,@presets) = @_;
	if ($d =~ m/^#/) { $d = 0; } # if passed a hex code
	my $row = PGK::labelBox( $box,$lab,'comborow','h', boxex => 0, labex => 0) unless ($optyp eq 'r');
	if ($optyp eq 's') {
		$d = int($d); # cast as a number
		my $selected = -1;
		foreach my $f (0..$#presets) {
			if ($f == $d) { $selected = $f; }
			$f++;
		}
		my $c = $row->insert( ComboBox => style => cs::DropDown, items => \@presets, text => (config($s,$key) or ''), height => 30 );
		$c->onChange( sub { optChange($c,[$changes,$pos,$options,$s,$key,$applyBut,config($s,$key)]); });
	} elsif ($optyp eq 'r') {
		my $g = $box-> insert( XButtons => name => $lab, pack => { fill => "none", expand => 0, }, );
		$g->onChange( sub { optChange($g,[$changes,$pos,$options,$s,$key,$applyBut,$d,$g->value()]); }, );
		$g->arrange("left"); # line up buttons horizontally (TODO: make this an option in the options hash? or depend on text length?)
		my $current = config($s,$key); # pull current value from config
		if (defined $current) { # translate current value to an array position (for default)
			$d = Common::findIn($current,@presets); # by finding it in the array
			$d = ($d == -1 ? scalar @presets : $d/2); # and dividing its position by 2 (behavior is undefined if position is odd)
		}
		$g-> build($lab,$d,@presets); # turn key:value pairs into exclusive buttons
	} else {
		warn "Incompatible selection type ($optyp)";
	}
}
print ".";

sub buildNumericRow {
	my ($box,$options,$applyBut,$lab,$s,$key,$v,$changes,$pos,@boundaries) = @_;
	my $row = PGK::labelBox( $box,$lab,'numrow','h', boxex => 0, labex => 0);
	my $n = $row->insert( SpinEdit => value => $v, min => ($boundaries[0] or 0), max => ($boundaries[1] or 10), step => ($boundaries[2] or 1), pageStep => ($boundaries[3] or 5));
	$n->onChange( sub { optChange($n,[$changes,$pos,$options,$s,$key,$applyBut,config($s,$key)]); });
}
print ".";

=item formatTooltips

Formats (or reformats after options have been changed) the font,
colors, and delay of the tooltips (hints) displayed by the program.
Takes no arguments, as it gets its settings from L<FIO/config>().

=cut
sub formatTooltips {
	return $::application->set(
		hintPause => 2500,
		hintColor => PGK::convertColor((FIO::config('UI','hintfore') or '#000')),
		hintBackColor => PGK::convertColor((FIO::config('UI','hintback') or '#CFF')),
		hintFont => PGK::applyFont('hint'),
	);
}
print ".";

print " OK; ";
1;
