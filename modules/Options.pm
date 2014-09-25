package Options;

use strict;
use warnings;
print __PACKAGE__;

sub config { use FIO; return FIO::config(@_); }

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
##			'007' => ['s',"Existing series names/epcounts will be updated from imported XML?",'importdiffnames',0,"never","ask","always"],

			'010' => ['l',"Database",'DB'],
			'011' => ['r',"Database type:",'type',0,'M','MySQL','L','SQLite'],
			'012' => ['t',"Server address:",'host'],
			'013' => ['t',"Login name (if required):",'user'],
			'014' => ['c',"Server requires password",'password'],
##			'01a' => ['c',"Update episode record with date on first change of episode"],
##			'019' => ['r',"Conservation priority",'conserve','mem',"Memory",'net',"Network traffic (requires synchronization)"],
##			'015' => ['c',"Maintain extended information table",'exinfo'],

			'030' => ['l',"User Interface",'UI'],
##			'032' => ['c',"Shown episode is next unseen (not last seen)",'shownext'],
			'034' => ['c',"Notebook with tab for each status",'statustabs'],
##			'036' => ['c',"Put movies on a separate tab",'moviesapart'],
			'038' => ['s',"Notebook tab position: ",'tabson',0,"left","top","right","bottom"],
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

			'050' => ['l',"Fonts",'Font'],
			'051' => ['t',"Tab font/size: ",'label'],
			'052' => ['t',"General font/size: ",'body'],
			'059' => ['t',"Special font/size: ",'special'], # for lack of a better term
			'053' => ['t',"Progress font/size: ",'progress'],

			'070' => ['l',"Custom Text",'Custom'],
			'072' => ['t',"Anime:",'ani'],
			'073' => ['t',"Manga:",'man'],
			'071' => ['t',"POMAL:",'program'],
##			'074' => ['t',"Movies:",'mov'],
##			'075' => ['t',"Stand-alone Manga:",'sam'],

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
	my $lab = $a[1];
	my $col = $a[3] or "#FF0000";
#	my @extra = ($#a > 3 ? $a[4..$#a] : ());
	my $key = $a[2];
	for ($a[0]) {
		if (/c/) {
			my $cb = Gtk2::CheckButton->new($lab);
			$cb->set_active(config($s,$key) or 0);
			$cb->signal_connect("toggled",\&optChange,[$change,$pos,$saveHash,$s,$key,$applyBut,(config($s,$key) or 0)]);
#			$cb->signal_connect("focus-in-event",scrollOnTab,scroll)
			$cb->show();
			$parent->pack_start($cb,0,0,1);
		}elsif (/m/) {
warn "Mask page $key will not be produced because the code is not finished";
		}elsif (/r/) {
warn "Radio button group $key will not be produced because the code is not finished";
		}elsif (/s/) {
warn "Selection box $key will not be built because the code is not finished";
		}elsif (/t/) {
			my $row = Gtk2::HBox->new();
			$row->show();
			$parent->pack_start($row,0,0,1);
			my $l = Gtk2::Label->new($lab);
			$l->show();
			my $e = Gtk2::Entry->new();
			$e->set_text(config($s,$key) or "");
			$e->signal_connect("changed",\&optChange,[$change,$pos,$saveHash,$s,$key,$applyBut,(config($s,$key) or "")]);
#			$e->signal_connect("focus-in-event",scrollOnTab,scroll)
			$e->show();
			$row->pack_start($l,0,0,0);
			$row->pack_start($e,1,1,0);
		}elsif (/x/) {
warn "Color (hex) row $key will not be built because the code is not finished";
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
	my ($caller,$args) = @_;
	my ($maskref,$p,$href,$sec,$k,$aButton,$default) = @$args;
	my $value;
	for (ref($caller)) {
		if (/CheckButton/) {
			$value = $caller->get_active() or 0;
		} elsif (/Entry/) {
			$value = $caller->get_text();
		} else {
			print "Fail! ";
		}
#				$value = $caller->get_text();
#				$value = $caller->get_active_text();
#				$value = $caller->get_value_as_int();
#				$value = $caller->get_value_as_int() * 100;
	}
	unless (defined $default) {
		$$maskref = Common::setBit($p,$$maskref);  $$href{$sec}{$k} = $value or 0;
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
		print "Section $s:\n";
		foreach (keys %{ $$href{$s} }) {
			print "	Key $_: $$href{$s}{$_}\n";
			config($s,$_,($$href{$s}{$_} or 0));
		}
	}
	my $status = PGUI::getGUI("status");
	FIO::saveConf();
	$status->push(0,"Options applied.");
	$$flagref = 0;	
}
print ".";

print " OK; ";
1;
