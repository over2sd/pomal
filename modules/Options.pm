package Options;

use strict;
use warnings;
print __PACKAGE__;

use FIO qw( config );

sub mkOptBox {
	# need: guiset (for setting window marker, so if it exists, I can present the window instead of recreating it?)
	my ($gui) = @_;
	my $changes = 0;
	my $pos = 0;
	my $optbox;
	my $running = 1;
	my $toSave = {};
# TODO: Figure out why this doesn't produce a reliable window (window is unresponsive after being hidden and reshown)
#	if (defined $$gui{optbox}) {
#		$optbox = $$gui{optbox};
#		$optbox->present();
#	} else {
		# First hash key (when sorted) MUST be a label containing a key that corresponds to the INI Section for the options that follow it!
		# EACH Section needs a label conaining the Section name in the INI file where it resides.
		my %opts = (
			'000' => ['l',"General",'Main'],
			'001' => ['c',"Save window positions",'savepos'],
##			'002' => ['x',"Foreground color: ",'fgcol',"#00000"],
##			'003' => ['x',"Background color: ",'bgcol',"#CCCCCC"],
			'004' => ['c',"Errors are fatal",'fatalerr'],

			'005' => ['l',"Import/Export",'ImEx'],
			'008' => ['c',"Use Disambiguation/Filter list",'filterinput'],
			'006' => ['c',"Store tracking site credentials gleaned from imported XML",'gleanfromXML'],
##			'007' => ['s',"Update existing series names/epcounts from imported XML?",'importdiffnames',0,"never","ask","always"],

			'010' => ['l',"Database",'DB'],
			'011' => ['r',"Database type:",'type',0,'M','MySQL','L','SQLite'],
			'012' => ['t',"Server address:",'host'],
			'013' => ['t',"Login name (if required):",'user'],
			'014' => ['c',"Server requires password",'password'],
##			'01a' => ['c',"Update episode record with date on first change of episode"],
##			'019' => ['r',"Conservation priority",'conserve',0,'mem',"Memory",'net',"Network traffic (requires synchronization)"],
##			'015' => ['c',"Maintain extended information table",'exinfo'],
##			'01b' => ['r',"Use ID from:",'idauthority',0,'a',"AnimeDB",'m',"MAL",'h',"Hummingbird",'l',"Local (order of addition)"],

			'030' => ['l',"User Interface",'UI'],
##			'032' => ['c',"Shown episode is next unseen (not last seen)",'shownext'],
			'034' => ['c',"Notebook with tab for each status",'statustabs'],
##			'036' => ['c',"Put movies on a separate tab",'moviesapart'],
			'038' => ['s',"Notebook tab position: ",'tabson',1,"left","top","right","bottom"],
##			'039' => ['c',"Show suggestions tab",'suggtab'],
##			'03a' => ['c',"Show recent activity tab",'recenttab'],
##			'03b' => ['c',"Recent tab active on startup",'activerecent'],
			'03c' => ['c',"Show progress bar for each title's progress",'graphicprogress'],
			'03d' => ['x',"Header background color code: ",'headerbg',"#CCCCFF"],
			'03e' => ['c',"5-star scoring",'starscore'],
			'03f' => ['c',"Limit scores to discrete points",'intscore'],
			'040' => ['c',"Show count in section tables",'linenos'],
			'041' => ['c',"Refresh pages when title is moved",'moveredraw'],
##			'042' => ['c',"Move to active when changing parts seen",'incmove'],
			'043' => ['x',"Background for list tables",'listbg',"#EEF"],

			'050' => ['l',"Fonts",'Font'],
			'054' => ['f',"Tab font/size: ",'label'],
			'051' => ['f',"General font/size: ",'body'],
			'053' => ['f',"Special font/size: ",'special'], # for lack of a better term
			'052' => ['f',"Progress font/size: ",'progress'],

			'070' => ['l',"Custom Text",'Custom'],
			'072' => ['t',"Anime:",'ani'],
			'073' => ['t',"Manga:",'man'],
			'071' => ['t',"POMAL:",'program'],
##			'074' => ['t',"Movies:",'mov'],
##			'075' => ['t',"Stand-alone Manga:",'sam'],
			'076' => ['t',"Options dialog",'options'],

			'ff0' => ['l',"Debug Options",'Debug'],
			'ff1' => ['c',"Colored terminal output",'termcolors']
		);
		# TODO: v. 2.0
##		callRegSect('options',\%opts); # let section of registered plugins add options
		$optbox = Gtk2::Window->new(); # Make a window
		my $vb = Gtk2::VBox->new();
		$vb->show();
		$optbox->add($vb);
		$optbox->set_position('center-always');
		$optbox->set_title((config('Custom','options') or "Preferences"));
		my $pages = Gtk2::Notebook->new(); # make a tabbed notebook
		$pages->show();
		$pages->set_tab_pos("left");
		$vb->pack_start($pages,1,1,2);
		my ($curtab,$section);
		my $saveB = Gtk2::Button->new("Save");
		$saveB->show();
		$saveB->set_sensitive(0);
		$saveB->signal_connect("clicked",\&saveFromOpt,[\$running,$toSave]);
		foreach my $k (sort keys %opts) {
			my @o = @{ $opts{$k} };
			if ($o[0] eq "l") { # label for tab
				$curtab = Gtk2::VBox->new(); # make a vbox to put all the options in a given Section in
				$curtab->show();
				my $l = Gtk2::Label->new($o[1]); # for each section, make a notebook page
				$section = $o[2];
	# should notebook page be a scrolled window, in case there are many options in the Section?
				$pages->append_page($curtab,$l); # make tab for this section
			}elsif (defined $section and defined $curtab) { # not first option in list
#				my $s = $section;
				addModOpts($curtab,$section,\$changes,$pos,$saveB,$toSave,@o); # build and add option to page
#print "Opt-$k: " . join(", ",@o) . "\n";
				$pos++;
			} else {
				warn "First option in hash was not a label! mkOptBox() needs a label for the first tab";
				if (config('Main','fatalerr')) { Gtkdie($$gui{mainWin},"mkOptBox not given label in first hash set"); }
				return -1;
			}
		}
	# When done with %opts...
	# add content filter options to notebook
		my $hb = Gtk2::HBox->new();
		$hb->show();
		$vb->pack_end($hb,0,0,2);
		my $cancelB = Gtk2::Button->new("Cancel"); # make a Close button
		$cancelB->show();
		$cancelB->signal_connect("clicked",sub { $running = 0; });
		$hb->pack_end($saveB,0,0,2); # pack the Save button (calls saveConf())
		$hb->pack_end($cancelB,0,0,2);
#		$$gui{optbox} = $optbox;
#	}
	$optbox->present();
	while ($running) {
		PGUI::Gtkwait(0.01);
	}
#	$optbox->hide();
	$optbox->destroy();
}
print ".";

sub addModOpts {
	my ($parent,$s,$change,$pos,$applyBut,$saveHash,@a) = @_;
	unless (scalar @a > 2) { print "array @a length: ". scalar @a . "."; return; } # malformed option, obviously
	my $item;
	my $t = $a[0];
	my $lab = $a[1];
	my $key = $a[2];
	my $col = ($a[3] or "#FF0000");
	splice @a, 0, 4; # leave 4-n in array
	for ($t) {
		if (/c/) {
			my $cb = Gtk2::CheckButton->new($lab);
			$cb->set_active(config($s,$key) or 0);
			$cb->signal_connect("toggled",\&optChange,[$change,$pos,$saveHash,$s,$key,$applyBut,(config($s,$key) or 0)]);
#			$cb->signal_connect("focus-in-event",scrollOnTab,scroll)
			$cb->show();
			$parent->pack_start($cb,0,0,1);
		}elsif (/f/) {
			my $row = Gtk2::HBox->new();
			$row->show();
			$parent->pack_start($row,0,0,1);
			my $l = Gtk2::Label->new($lab);
			$l->show();
			my $f = Gtk2::FontButton->new_with_font(config($s,$key) or "");
			$f->signal_connect("font-set",\&optChange,[$change,$pos,$saveHash,$s,$key,$applyBut,(config($s,$key) or "")]);
#			$f->signal_connect("focus-in-event",scrollOnTab,scroll)
			$f->show();
			$row->pack_start($l,1,0,0);
			$row->pack_start($f,1,1,0);
		}elsif (/m/) {
warn "Mask page $key will not be produced because the code is not finished";
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
			my $row = Gtk2::HBox->new();
			$row->show();
			$parent->pack_start($row,0,0,1);
			my $l = Gtk2::Label->new($lab);
			$l->show();
			my $e = Gtk2::Entry->new();
			$e->set_text(config($s,$key) or "");
			$e->signal_connect("focus-out-event",\&optChange,[$change,$pos,$saveHash,$s,$key,$applyBut,(config($s,$key) or "")]);
#			$e->signal_connect("focus-in-event",scrollOnTab,scroll)
			$e->show();
			$row->pack_start($l,0,0,0);
			$row->pack_start($e,1,1,0);
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
	unless ($$maskref == 0) { $button->set_sensitive(1); }
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
		if (/CheckButton/) {
			$value = $caller->get_active() or 0;
		} elsif (/Entry/) {
			$value = $caller->get_text();
		} elsif (/ComboBox/) {
			$value = $caller->get_active_text();
		} elsif (/FontButton/) {
			$value = $caller->get_font_name();
		} elsif (/RadioButton/) {
			($caller->get_active() ? $value = $rbval : return );
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
	my ($flagref,$href) = @$args;
	$caller->set_sensitive(0);
	foreach my $s (keys %$href) {
#		print "Section $s:\n";
		foreach (keys %{ $$href{$s} }) {
#			print "	Key $_: $$href{$s}{$_}\n";
			config($s,$_,($$href{$s}{$_} or 0));
		}
	}
	my $status = PGUI::getGUI("status");
	FIO::saveConf();
	$status->push(0,"Options applied.");
	$$flagref = 0;
	# check here to see if something potentially crash-inducing has been changed, and shut down cleanly, instead, after informing user that a restart is required.
	PGUI::populateMainWin(PomalSQL::getDB(),PGUI::getGUI(),1); # refresh the UI
}
print ".";

sub buildColorRow {
	my ($box,$options,$applyBut,$lab,$s,$key,$col,$change,$pos) = @_;
	my $row = Gtk2::HBox->new();
	my $label = Gtk2::Label->new($lab);
	$label->set_alignment(0.1,0.5);
	my $e = Gtk2::Entry->new();
	$e->show();
	$e->set_text(config($s,$key) or $col);
	$e->set_width_chars(24);
	$e->signal_connect("changed",\&optChange,[$change,$pos,$options,$s,$key,$applyBut,(config($s,$key) or "")]);
	$e->signal_connect("changed",\&PGUI::setBack,[$e,"normal"]);
	PGUI::setBack(undef,[$e,'normal']);
#	$e->signal_connect("focus-in-event",scrollOnTab,scroll)
	my $b = Gtk2::Button->new("Choose Color");
	$b->signal_connect("clicked",\&PGUI::selColor,$e);
	$b->show();
	$row->show();
	$label->show();
	$row->pack_start($label,1,1,2);
	$row->pack_start($e,0,0,2);
	$row->pack_start($b,0,0,2);
	$box->pack_start($row,0,0,1);
}
print ".";

sub buildComboRow {
	my ($box,$options,$applyBut,$lab,$s,$key,$d,$changes,$pos,$optyp,@presets) = @_;
	if ($d =~ m/^#/) { $d = 0; } # if passed a hex code
	my $row = Gtk2::HBox->new();
	$row->show();
	my $label = Gtk2::Label->new($lab);
	$label->set_alignment(0.1,0.5);
	$label->show();
	$row->pack_start($label,0,0,2);
	if ($optyp eq 's') {
		$d = int($d); # cast as a number
		my $c = Gtk2::ComboBox->new_text();
		my $selected = -1;
		my $i = 0;
		foreach my $f (@presets) {
			if ($i == $d) { $selected = $i; }
			$c->append_text($f);
			$i++;
		}
		$c->set_active($selected);
		$c->signal_connect("changed",\&optChange,[$changes,$pos,$options,$s,$key,$applyBut,config($s,$key)]);
		$c->signal_connect("move-active",\&optChange,[$changes,$pos,$options,$s,$key,$applyBut,config($s,$key)]);
		$c->show();
		$row->pack_start($c,0,0,2);
		my $blank = Gtk2::Label->new(" ");
		$blank->show(); # spacer to make combo box sit next to its label
		$row->pack_end($blank,1,0,0);
	} elsif ($optyp eq 'r') {
		my %options = @presets; # become hash
		my @g;
		foreach my $i (sort keys %options) {
			my $a = Gtk2::RadioButton->new($g[0],$options{$i});
			$a->show();
			if ($i eq $d) { $a->set_active(1); }
			$row->pack_start($a,1,0,1);
			$a->signal_connect('toggled',\&optChange,[$changes,$pos,$options,$s,$key,$applyBut,$d,$i]);
			push(@g,$a);
		}
	} else {
		warn "Incompatible selection type ($optyp)";
	}
	$box->pack_start($row,0,0,1);
}
print ".";

print " OK; ";
1;
