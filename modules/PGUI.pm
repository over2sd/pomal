# Graphic User Interface module
use strict; use warnings;
package PGUI;
print __PACKAGE__;

use Prima qw(Application Buttons MsgBox FrameSet StdDlg Sliders Notebooks ScrollWidget ImageViewer);
$::wantUnicodeInput = 1;

use PGK qw( VBox Table Pdie Pwait applyFont getGUI );
use FIO qw( config );

sub buildMenus { #Replaces Gtk2::Menu, Gtk2::MenuBar, Gtk2::MenuItem
	my $gui = shift;
	my $menus = [
		[ '~File' => [
			['~Import', 'Ctrl-O', '^O', sub { importGUI() } ],
			['~Export', sub { exportGUI() }],
#			['~Synchronize', 'Ctrl-S', '^S', sub { message('synch!') }],
			['~Preferences', sub { return callOptBox($gui); }],
			[],
			['Close', 'Ctrl-W', km::Ctrl | ord('W'), sub { $$gui{mainWin}->close() } ],
		]],
		[ '~Add' => [
			['~Anime',sub { addTitle($gui,'ani') }],
			['~Manga',sub { addTitle($gui,'man') }],
		]],
		[ '~Help' => [
			['~About',sub { message('About!') }], #\&aboutBox],
		]],
	];
	return $menus;
}
print ".";

sub convertColor {
	my ($color,$force) = @_;
	return undef unless (defined $color); # undef if no color given
	return $color unless ($force or $color =~ m/^#/); # return color unchanged unless it starts with '#' (allows passing integer straight through, as saveConf is going to write it as int, but we want user to be able to write it as #ccf).
	return ColorRow::stringToColor($color); # convert e.g. "#ccf" to integer needed by Prima
}
print ".";

sub fillPage {
	my ($dbh,$index,$typ,$gui) = @_;
	unless (defined $$gui{tabbar}) { Pdie("fillPage couldn't find tab bar!"); }
	my ($target,$snote,%pages);
	my %exargs;

#	$exargs{limit} = 5;

	my %statuses = Sui::getStatHash($typ);
	my $labeltexts;
	for ($typ) {
		if (/ani/) { }
		elsif (/man/) { }
		elsif (/mov/) { $exargs{max} = 1; }
		elsif (/sam/) { $exargs{max} = 1; }
		elsif (/sug/) { warn "Suggestions are not yet supported"; return; }
		elsif (/rec/) {
			return if (config('UI','notabs')); # no tabs option creates its own recent box.
			$$gui{status}->text("Preparing recent activity box...");
			$::application->yield();
			$snote = $$gui{tabbar}->insert_to_page($index, VBox => name => "$typ$_", pack => { fill => 'both', expand => 1, pady => 3, side => "top",}, alignment => ta::Left, );
			$$gui{recent} = $snote;
			$snote->insert( SpeedButton => text => "Show Recent", onClick => sub { spreadRecent($dbh,$$gui{recent}); });
			return; }
		else { warn "Something unexpected happened"; return; }
	}
	$$gui{status}->text("Loading titles...");
	my @cumulativestats = (0,0,0,0,0);
	my @cumulativescores;
	my $watched = ($typ eq 'man' ? "Chapters read" : "Episodes watched");
	unless (config('UI','statustabs') or 0) { # single box
		$$gui{status}->text("Placing titles in common box...");
		$snote = $$gui{tabbar}->insert_to_page($index, VBox => name => "$typ", pack => {fill => 'both', expand => 0} );
		my $buttonbar = $snote->insert( HBox => name => "buttons", pack => {fill => 'x', expand => 0});
		$buttonbar->insert(SpeedButton => text => "Please wait...");
# calculate box size (also needed for buttons)
		my $sizer = $snote->insert( Label => text => "Calculating size...", pack => { fill => 'both', expand => 1, anchor => 'nw'}, backColor => convertColor("#ccf"), sizeMin => [10,(FIO::config('Main','height') or 2000)]); #ensures a scrollbar will be generated
		my ($w,$h,$bh) = ($sizer->size,$buttonbar->height);
		$sizer->destroy();
		$buttonbar->empty();
		my @tabs = $$gui{tabbar}->get_widgets();
		my $t = $tabs[0]; # TabSet
#		my ($x,$y) = $t->origin;
		my ($x,$y) = (0,-7);#-$bh);
		$h -= $bh;
		my $placement = [$x,$y,$w,$h];
# insert box
		$target = $snote->insert( VBoxE => name => "$typ", pack => { fill => 'both', expand => 1, }, sizeMin => [$w,$h]);
# insert buttons to display different statuses
		my @order = Sui::getStatOrder;
		my $buts = {};
		if (FIO::config('UI','jitload') or 0) {
			foreach (@order) {
				$$buts{$_} = $buttonbar->insert( SpeedButton =>
					checkable => 1,
					name => $_,
					text => $statuses{$_},
# each button will call switchToStatus, which will check target for that status, and load a new box into it if that status is not found.
					onClick => sub { switchToStatus($dbh,$target,$typ,$_[0]->name,$buttonbar,$_[0],$placement,%exargs); },
				);
			}
			@order = ($order[0],); # trim array if loading Just-In-Time
		}
		foreach (reverse @order) {
# display titles using switchToStatus
			my $typestring = (config('Custom',$typ) or ($typ eq 'man' ? "Manga" : "Anime"));
			my $status = $statuses{$_};
			$$gui{status}->text("Placing titles in common box ($typestring/$status)...");
			my $h = switchToStatus($dbh,$target,$typ,$_,$buttonbar,($$buts{$_} or undef),$placement,%exargs);
			if (FIO::config('Table','statsummary')) { # put in a label/box of labels with statistics (how many titles, total episodes watched, mean score, etc.)
				my ($list,@stats) = insertStats($snote,($typ eq 'man' ? 'pub' : 'series'),$h,$watched);
				push(@cumulativescores,@$list);
				foreach (0..$#stats) {
					$cumulativestats[$_] += $stats[$_];
				}
			}
# try to find scrollbar
			my $sb = (PGK::getScroll($snote) or PGK::getScroll($$gui{tabbar}));
# try to move scrollbar to 0
			$sb->value(0) if defined $sb; # put scrollbar at top
			$::application->yield();
		}
		return;
	} else { # 'UI','statustabs' = 1
		my $page = 0;
		foreach (Sui::getStatOrder()) { # specific order
			push(@$labeltexts,$statuses{$_});
			$pages{$_} = $page++;
		}
		$$gui{status}->text("Placing titles in tabs...");
		my %args;
		if (defined config('UI','tabson')) { $args{orientation} = (config('UI','tabson') eq "bottom" ? tno::Bottom : tno::Top); } # set tab position based on config option
		$snote = $$gui{tabbar}->insert_to_page($index, "Prima::TabbedScrollNotebook" =>
			style => tns::Simple,
			tabs => $labeltexts,
			name => 'SeriesTypes',
			tabsetProfile => {colored => 0, %args, },
			pack => { fill => 'both', expand => 1, pady => 3, side => "top", },
		);
		foreach (Sui::getStatOrder()) {
			my $typestring = (config('Custom',$typ) or ($typ eq 'man' ? "Manga" : "Anime"));
			my $status = $statuses{$_};
			$$gui{status}->text("Placing titles in tabs ($typestring/$status)...");
			$::application->yield();
			$page = $pages{$_};
			$target = $snote->insert_to_page($page, VBox => name => "$typ$_", pack => { fill => 'both', expand => 1, }, );
 			my $h = pullRows($dbh,$target,$typ,$_,$$labeltexts[$page],undef,%exargs);
			if (FIO::config('Table','statsummary')) { # put in a label/box of labels with statistics (how many titles, total episodes watched, mean score, etc.)
				my ($list,@stats) = insertStats($snote,($typ eq 'man' ? 'pub' : 'series'),$h,$watched);
				push(@cumulativescores,@$list);
				foreach (0..$#stats) {
					$cumulativestats[$_] += $stats[$_];
				}
			}
			# Try to find scrollbar:
			my $sb = PGK::getScroll($snote) or PGK::getScroll($$gui{tabbar});
			$sb->value(0) if defined $sb; # put scrollbar at top
			$::application->yield();
		}
		if (FIO::config('Table','statsummary')) {
			$cumulativestats[1]++ unless $cumulativestats[1]; # prevent divide by zero
			my $statline = (FIO::config('Table','withmedian') ? withMedian(\@cumulativestats,$watched,@cumulativescores) : withoutMedian(\@cumulativestats,$watched,@cumulativescores));
			$$gui{tabbar}->insert_to_page($index, Label => text => $statline, pack => { fill => 'x', expand => 0,}, );
		}
	}
}
print ".";

sub insertStats {
	my ($target,$rowtyp,$h,$watched) = @_;
	# compile statistics from @a
	my @tablestats = (0,0,0,0,0);
	my $scorelist;
	foreach (values %$h) {
		push(@$scorelist,$$_{score}) unless $$_{score} == 0;
		$tablestats[0]++;
		$tablestats[1] += 1 unless $$_{score} == 0;
		$tablestats[2] += $$_{score};
		$tablestats[3] += ($$_{status} == 4 ? ($rowtyp eq 'series' ? $$_{episodes} : $$_{chapters} ) : ($rowtyp eq 'series' ? ($$_{status} == 3 ? $$_{lastrewatched} : $$_{lastwatched} ) : ($$_{status} == 3 ? $$_{lastreread} : $$_{lastreadc} )));
	}
	$::application->yield();
	$tablestats[1]++ unless $tablestats[1]; # prevent divide by zero
	my $statline = (FIO::config('Table','withmedian') ? withMedian(\@tablestats,$watched,@$scorelist) : withoutMedian(\@tablestats,$watched,@$scorelist));
	$target->insert( Label => text => $statline, pack => { fill => 'x', expand => 0,}, );
	return ($scorelist,@tablestats);	
}
print ".";

sub withMedian {
	my ($a,$watched,@list) = @_;
	$$a[4] = Common::median(\@list,0);
	my $var = sprintf("Titles: $$a[0] Mean score: %.2f Median score: %.2f $watched: $$a[3]\n",($$a[2]/($$a[1]*10)),$$a[4]/10);

}
print ".";

sub withoutMedian {
	my ($a,$watched) = @_;
	my $var = sprintf("Titles: $$a[0] Mean score: %.2f $watched: $$a[3]\n",($$a[2]/($$a[1]*10)));
}
print ".";

sub getTabByCode { # for definitively finding page ID of recent, suggested tabs...
	my ($code,$tablist) = @_;
	my $tabs = ($tablist or getGUI("tablist") or []);
	return Common::findIn($code,@$tabs);
}
print ".";

sub passTableByCode {
	my ($code1,$code2) = @_;
	my $tab = getTabByCode($code1);
#print "Tab: $tab \n";
	my $target = PGK::getGUI('tabbar');
	my @list = $target->widgets_from_page($tab);
	foreach (@list) {
		$target = $_ if (ref($_) =~ m/Notebook/);
	}
	$tab = -1;
	unless ($target == PGK::getGUI('tabbar')) {
		@list = @{$target->tabs()};
		my %stats = Sui::getStatHash($code1);
		my $i = 0;
		foreach my $text (@list) {
			$tab = $i if $stats{$code2} eq $text;
			$i++;
		}
		my @w = $target->widgets_from_page($tab);
		return undef if $tab == -1;
		foreach ($w[0]->get_widgets()) {
			return $_ if $_->name eq "${code2}table";
		}
	}
	return undef;
}
print ".";

sub importGUI {
	use Import qw( importXML );
	my $gui = PGK::getGUI();
	my $dbh = FlexSQL::getDB();
	my $filename = PGK::askbox($$gui{mainWin},"Enter a filename",undef,"Filename:");
	### Later, put selection here for type of import to make
	# For now, just allowing import of MAL XML file
	PGK::refreshUI($gui,$dbh) unless(Import::importXML($dbh,$gui,$filename));
}
print ".";

sub exportGUI {
	use Export qw( exportParts );
	my $gui = PGK::getGUI();
	my $dbh = FlexSQL::getDB();
	### Later, put selection here for type of export to make
	my $target = $$gui{questionparent};
	$target->bring_to_front();
	my $exbox = $target->insert( VBox => name => "export");
	my $value = 0;
	my $xb = $exbox-> insert( XButtons => name => 'type', pack => {fill => 'x'} );
	$xb->arrange("left"); # line up buttons horizontally
	my @presets = ('series',"Episodes",'pub',"Chapters and Volumes");
	my $current = 0;
	$xb-> build("Export type:",$current,@presets); # turn key:value pairs into exclusive buttons
	$exbox->insert( SpeedButton => text => "Export", pack => { fill => 'x' }, onClick => sub { $value = $xb->value; $exbox->destroy(); $exbox = undef; });
	while ($exbox) {
		PGK::Pwait(1);
	}
	$target->insert( Label => text => "Please wait while export processes...");
	Export::exportParts($dbh,$gui,$value);
	$target->empty();
	$target->send_to_back();
}
print ".";

sub populateMainWin {
	my ($dbh,$gui,$refresh) = @_;
	$$gui{status}->text(($refresh ? "Reb" : "B") . "uilding UI...");
	if (defined $$gui{tabbar}) {
		unless ($refresh) { warn "populateMainWin called twice without refresh flag"; return; }
		$$gui{tabbar}->close(); # refresh
	}
	# TODO: Refresh should check to see if there are existing objects (if conserving net traffic) and use those, if possible
	# TODO: Refresh should be able to refresh just one of the tabs, say 'man', if importing Manga...
	my %exargs;
	if (defined config('UI','tabson')) { $exargs{orientation} = (config('UI','tabson') eq "bottom" ? tno::Bottom : tno::Top); } # set tab position based on config option
	my @tabtexts;
	my @tabs = qw[ ani man ];
	push(@tabs,'mov') if config('UI','moviesapart');
	push(@tabs,'sam') if config('UI','moviesapart');
	push(@tabs,'sug') if config('UI','suggtab');
	push(@tabs,'rec') if config('UI','recenttab');
	foreach (@tabs) { # because tabs are controlled by option, tabnames must also be.
		if (/ani/) { push(@tabtexts,(config('Custom',$_) or "Anime")); }
		elsif (/man/) { push(@tabtexts,(config('Custom',$_) or "Manga")); }
		elsif (/mov/) { push(@tabtexts,(config('Custom',$_) or "Movies")); }
		elsif (/sam/) { push(@tabtexts,(config('Custom',$_) or "Books")); }
		elsif (/sug/) { push(@tabtexts,(config('Custom',$_) or "Suggestions")); }
		elsif (/rec/) { push(@tabtexts,(config('Custom',$_) or "Recent")); }
		else { push(@tabtexts,"Unknown"); }
	}
	$$gui{tablist} = \@tabs;
	$$gui{questionparent} = $$gui{mainWin}->insert( VBox => name => 'qparent', place => { fill => 'both', expand => 0, relx => 0, rely => 1, anchor => 'nw', relwidth => 1, relheight => 0.9, } );
	my $waiter = $$gui{mainWin}->insert( Label => text => "Building display.\nPlease wait...", pack => { fill => 'x', expand => 1, }, valign => ta::Center, alignment => ta::Center, font => applyFont('bighead'), autoHeight => 1, );
	$::application->yield();
	if (config('UI','notabs')) {
		populateWithoutTabs($dbh,$gui,$refresh,\%exargs,$$gui{tablist},@tabtexts);
		$waiter->destroy();
		return;
	}
	my $profile = {
		style => tns::Simple,
		tabs => \@tabtexts,
		name => 'SeriesTypes',
		tabsetProfile => {colored => 0, %exargs, },
		pack => { fill => 'both', expand => 1, pady => 3, side => "left", },
	};
	my $note;
	unless (config('UI','statustabs') or 0) {
		$note = $$gui{mainWin}->insert( 'Prima::TabbedScrollNotebook' => %$profile);
	} else {
		$note = $$gui{mainWin}->insert( 'Prima::TabbedNotebook' => %$profile);
	}
	$$gui{tabbar} = $note; # store for additional tabs
	$note->hide();
	foreach (0..$#tabs) {
		fillPage($dbh,$_,$tabs[$_],$gui);
	}
	$note->show();
# try to find scrollbar
	my $sb = PGK::getScroll($note);
# try to move scrollbar to 0
	$sb->value(0) if defined $sb; # put scrollbar at top
	PGK::resetScroll($sb);
	$::application->yield();
	$waiter->destroy();
	$note->pageIndex((FIO::config('UI','recenttab') and FIO::config('Recent','activerecent') ? getTabByCode('rec') : 0));
	$$gui{status}->text("Ready.");
	spreadRecent($dbh,$$gui{recent}) if (FIO::config('UI','recenttab') and FIO::config('Recent','activerecent'));
}
print ".";

sub populateWithoutTabs {
	my ($dbh,$gui,$refresh,$exargs,$tablist,@tabtexts) = @_;
	$$gui{buttonbar} = $$gui{mainWin}->insert( HBox => name => 'pager', pack => { fill => 'x', expand => 0, } );
	$$gui{dispboxes} = [];
	$$exargs{limit} = config('UI','titlesperpage') if (config('UI','titlesperpage') or 0);
	foreach (0..$#$tablist) {
		my $box;
		if ($$tablist[$_] eq 'rec') {
			print "Recent\n";
			$box = $$gui{mainWin}->insert( VBox => name => $$tablist[$_], place => { fill => 'both', expand => 0, relx => 0, rely => 0.9, anchor => 'nw', relwidth => 1, relheight => 0.9, } );
			$$gui{recent} = $box;
			$box->insert( SpeedButton => text => "Show Recent", onClick => sub { spreadRecent($dbh,$$gui{recent}); });
		} else {
			$box = $$gui{mainWin}->insert( VBox => name => $$tablist[$_], place => { fill => 'both', expand => 0, relx => 0, rely => 0.9, anchor => 'nw', relwidth => 1, relheight => 0.9, } );
			my $status = $box-> insert( XButtons => name => 'stat' );
			$status->arrange("left"); # line up buttons horizontally
			my @order = Sui::getStatOrder;
			my %statuses = Sui::getStatHash($box->name);
			my @presets;
			foreach (@order) {
				push(@presets,$_,$statuses{$_});
			}
			$status->build("Status:",0,@presets); # turn key:value pairs into exclusive buttons
			my $hb = $box->insert( HBox => name => 'layout', pack => {fill => 'both', expand => 1});
			my @lettergroup;
			my $page = $$tablist[$_];
			die "[E] Bad table name passed to populateWithoutTabs" if (Common::findIn($page,qw[ani mov sab man]) < 0);
			my $table = (($page eq 'ani' or $page eq 'mov') ? 'series' : 'pub');
			unless (config('UI','dynamicletters')) {
				@lettergroup = ('#','A'..'Z','all');
			} else {
				my $lettergetter = "SELECT LEFT(" . substr($table,0,1) . "name,1) AS letter FROM $table WHERE " . substr($table,0,1) . "name IS NOT NULL GROUP BY letter;";
				$lettergetter = FlexSQL::doQuery(7,$dbh,$lettergetter);
				unless (scalar @$lettergetter) {
					my $count = FlexSQL::doQuery(0,$dbh,"SELECT COUNT(*) FROM $table;"); # this line detects brand new database!
					die "OUCH! $dbh->errstr" if $count;	
					$lettergetter = [];
				}
				@lettergroup = (@$lettergetter,'all');
			}
			my $letters1 = $hb->insert( VBox => name => '#-M', pack => { fill => 'y', expand => 0}, backColor => convertColor((config('UI','letterbg') or '#CCCCFF')));# build letter buttons
			my $letters2 = $hb->insert( VBox => name => 'N-Z', pack => { fill => 'y', expand => 0}, backColor => convertColor((config('UI','letterbg') or '#CCCCFF')));
			my $titlebox = $hb->insert( VBox => name => $tabtexts[$_], pack => { fill => 'both', expand => 1, }, backColor => convertColor(config('UI','listbg') or '#eef'));# build target box
			$status->onChange( sub { fillBoxwithTitles($dbh,'all',$page,$status->value,$gui,$titlebox,$exargs); });
			foreach (@lettergroup[0..$#lettergroup/2]) {
				my $text = "$_";
				$letters1->insert( SpeedButton => text => $text, onClick => sub { fillBoxwithTitles($dbh,$text,$page,$status->value,$gui,$titlebox,$exargs); }, backColor => convertColor((config('UI','letterbg') or '#CCCCFF')));
			}
			foreach (@lettergroup[$#lettergroup/2+1..$#lettergroup]) {
				my $text = "$_";
				$letters2->insert( SpeedButton => text => $text, onClick => sub { fillBoxwithTitles($dbh,$text,$page,$status->value,$gui,$titlebox,$exargs); }, backColor => convertColor((config('UI','letterbg') or '#CCCCFF')));
			}
			fillBoxwithTitles($dbh,undef,$$tablist[$_],$status->value,$gui,$titlebox,$exargs);
		}
		$box->send_to_back() unless ($$tablist[$_] eq 'ani' or ($$tablist[$_] eq 'rec' and config('Recent','activerecent')));
		$$gui{buttonbar}->insert( SpeedButton => text => $tabtexts[$_], onClick => sub { $box->bring_to_front(); });
	}
	$::application->yield();
	$$gui{status}->text("Ready.");
	spreadRecent($dbh,$$gui{recent}) if (FIO::config('UI','recenttab') and FIO::config('Recent','activerecent'));
}
print ".";

sub fillBoxwithTitles {
	my ($dbh,$letter,$table,$stat,$gui,$target,$exargs) = @_;
	$target->empty();
	my $showing = "Currently showing: ";
	if (not defined $letter or $letter eq 'all') {
		$showing = $showing."All ";
		delete $$exargs{begins} if exists $$exargs{begins};
	}
	my %stats = Sui::getStatHash($table);
	my $status = $stats{$stat};
	my $statusadj = $status;
	$statusadj =~ s/ /-/g;
	$showing = $showing."$statusadj titles";
	unless (not defined $letter or $letter eq 'all') {
		$showing = "$showing beginning with $letter";
		$$exargs{begins} = $letter;
	}
	my ($lim,$off) = (0,0);
	foreach (keys %$exargs) {
print "$_:$$exargs{$_}";
		for ($_) {
			if (/limit/) {
				$lim = ($$exargs{$_} or 0);
			} elsif (/offset/) {
				$off = ($$exargs{$_} or 0);
			}
		}
	}
	my $showlbl = $target->insert( Label => text => $showing, pack => { fill => 'none', expand => 0});
	my $h = switchToStatus($dbh,$target,$table,$stat,0,$showlbl,undef,%$exargs);
	$target->insert( Label => text => "$table/$stat:".($letter or "none"));
}
print ".";

sub sayBox {
	my ($parent,$text) = @_;
	message($text,owner=>$parent);
}
print ".";

sub callOptBox {
	my $gui = shift || getGUI();
	my %options = Sui::passData('opts');
	return Options::mkOptBox($gui,%options);
}
print ".";

sub buildTitleRows {
	my ($titletype,$target,$tlist,$rownum,@keys) = @_;
#print "\nbTR($titletype,$target,$tlist,$rownum,[".join(',',@keys)."])\n";
	my $numbered = (config('UI','linenos') ? 1 : 0);
	my @widths = Sui::passData('twidths');
	shift(@widths) unless config("UI",'linenos');
	my $rowshown = $rownum;
	my $headcolor = "#CCCCFF";
	my $backcolor = "#EEF";
	my $buttoncolor = "#aac";
	$headcolor = convertColor(config('UI','headerbg') or $headcolor) if $titletype eq 'head';
	$backcolor = convertColor(config('UI','listbg') or $backcolor);
	$buttoncolor = convertColor(config('UI','buttonbg') or $buttoncolor);
	# each item in hash is a hash
	my @rows;
	my $rowheight = (config('Table','t1rowheight') or 60);
	my $updater;
	unless ((config('DB','conserve') or '') eq 'net') {
		$updater = FlexSQL::getDB();
	} else {
		warn "Conserving net traffic is not yet supported"; $updater = PomallSQL::getDB();
	}
	my $statlabels = Sui::getStatArray($titletype);
	my $movetext = "Move to a different status";
	foreach my $k (@keys) { # loop over list
		$rownum++; $rowshown++;
##		print "Building row for title $k...\n";
		my $row = $target->insert( HBox => name => "row$rownum", pack => { fill => 'x', expand => 0, },);
		applyFont('body',$row);
		$row->backColor($titletype eq 'head' ? $headcolor : $backcolor);
		my %record = %{$$tlist{$k}};
		if ($titletype eq 'head') {
			if ($numbered) {
				my $nolabel = $row->insert( Label => text => "#");
				$nolabel->sizeMin($widths[0],$nolabel->height) if (defined $widths[0] and $widths[0] > 0);
				applyFont('body',$nolabel);
				$nolabel->backColor($headcolor);
				$rownum--;
			}
		} else {
			my $nolabel = $row->insert( Label => text => ($numbered ? "$rowshown" : ""));
			$nolabel->sizeMin($widths[0],$nolabel->height) if (defined $widths[0] and $widths[0] > 0);
			applyFont('body',$nolabel);
		}
		# column between 0 and 1, remainder column. Ignore width
		my $title = $row->insert( Label => text => Common::shorten($record{title},30), pack => { fill => 'x', expand => 1, }, ); # put in the title of the series
		unless ($title->text eq $record{title}) { $title->hint($record{title}); } # if I shortened the title, make the full title available in a tooltip
		applyFont('body',$title);
		$title->onClick(sub {
			my $qbox2 = getGUI('mainWin')->insert( VBox => name => 'qparent', place => { fill => 'both', expand => 0, relx => 0, rely => 1, anchor => 'nw', relwidth => 1, relheight => 0.9, } );
			tiDets($updater,$qbox2,$titletype,$k,$record{title},($record{status} == 4 ? "" : ($titletype eq 'series' ? ($record{status} == 3 ? "$record{lastrewatched}" : "$record{lastwatched}" ) : ($record{status} == 3 ? "$record{lastreread}" : "$record{lastreadc}" ))));
			});
		if ($titletype eq 'head') {
			$title->backColor($headcolor);
		}
		if ($titletype eq 'head') {
			my $cb = $row->insert( Label => text => "Status", pack => { fill => 'none', expand => 0, }, );
			$cb->sizeMin($widths[1],$cb->height) if (defined $widths[1] and $widths[1] > 0);
			$cb->backColor($headcolor);
		} else {
			my $icon = Prima::Image->new( size => [16,16]);
			my $status = $record{status};
			unless ($status == 4) { # No move button for completed page
				$icon->load("modules/move.png") or print "Could not load icon";
			} else { # Instead, make "Rewatch this show" button
				$icon->load("modules/reset.png") or print "Could not load icon";
			}
			my $rbox = $row->insert( HBox => backColor => $backcolor, pack => { fill => 'none', expand => 0, }, );
			$rbox->arrange();
			my $changer = $rbox->insert( SpeedButton =>
				sizeMax => [17,17],
				backColor => $buttoncolor,
				image => $icon,
				hint => ($status == 4 ? "Start again" : $movetext),
onClick => sub { devHelp($target,"Moving titles to new status");},
	# TODO: code chooseStatus function for moving to another status
			);
			$rbox->sizeMin($widths[1],$rbox->height) if (defined $widths[1] and $widths[1] > 0);
			my $staticon = Prima::Image->new( size => [16,16]);
			$staticon->load("modules/status$status.png") or print "Could not load icon";
			my $rew = $rbox->insert(ImageViewer => sizeMax => [23,17], backColor => $backcolor, alignment => ta::Right, valignment => ta::Top, image => $staticon, hint => $$statlabels[$status]);
			$changer->onClick( sub { ($status == 4 ? chooseStatus($updater,$row,$rew,$status,$k,$titletype) : setStatus($updater,$row,$rew,3,$k,$titletype) )});
			my $seen = ($titletype eq 'series' ? 'seentimes' : 'readtimes');
			$rbox->insert( Label => text => "x" . ($record{$seen} + 1)) if ($record{status} == 4 and $record{$seen} > 0);
		}
		if ($titletype eq 'head') {
			my $plabel = $row->insert( Label => text => "Progress");
			$plabel->sizeMin($widths[2],$plabel->height) if (defined $widths[2] and $widths[2] > 0);
			applyFont('body',$plabel);
			$plabel->backColor($headcolor);
		} else {
			my $updateform = ($titletype eq "series" ? ($record{status} == 3 ? 1 : 0 ) : ($record{status} == 3 ? 3 : 2 ) );
			my $pvbox = $row->insert( VBox => backColor => $backcolor);
			my $pchabox = $pvbox->insert( HBox => name => 'partbox', backColor => $backcolor);
		# put in the number of watched/episodes (button) -- or chapters
			$record{chapters} = 0 unless defined $record{chapters};
			my $pprog = ($record{status} == 4 ? "" : ($titletype eq 'series' ? ($record{status} == 3 ? "$record{lastrewatched}" : "$record{lastwatched}" ) : ($record{status} == 3 ? "$record{lastreread}" : "$record{lastreadc}" )) . "/") . (($titletype eq 'series' ? $record{episodes} : $record{chapters}) or "-");
			my $pbut = $pchabox->insert( Label =>
				name => 'partlabel',
				text => $pprog,
				pack => { expand => 1, fill => 'both', },
				onClick => sub { askPortion($pvbox,$updateform,$k,$updater,$record{title},($record{status} == 3));},
			);
			applyFont('button',$pbut);
			unless ($record{status} == 4) { # to save processing power, no full gauges
				# put in a label giving the % completed (using watch or rewatched episodes)
				my $num = ($titletype eq 'series' ? ($record{status} == 3 ? $record{lastrewatched} : $record{lastwatched} ) : ($record{status} == 3 ? $record{lastreread} : $record{lastreadc} ));
				my $div = (($titletype eq 'series' ? $record{episodes} : $record{chapters} ));
				my $rawperc = ($div ? ($num / $div * 100) : ($num ? int(rand(99)) : 0));
				# read config option and display percentage as either a label or a progress bar
				if (config('UI','graphicprogress')) {
					my $percb = $pvbox->insert( Gauge => name => 'partbar', size => [100,24], value => $rawperc, pack => { expand => 0, fill => 'none', },);
					applyFont('progress',$percb);
				} else {
					my $pertxt = ($div ? sprintf("%.2f%%",$rawperc/100) : "??.??%");
					my $percl = $pvbox->insert( Label => name => 'parttxt', text => $pertxt);
					applyFont('progress',$percl);
				}
			}
			# put in a button to increment the number of episodes or chapters (using watch or rewatched episodes)
			unless ($record{status} == 4 or $record{status} == 5) {
				my $incbut = $pchabox->insert( SpeedButton =>
					text => "+",
					backColor => $buttoncolor,
					font => applyFont('progbut'),
					autoHeight => 1,
					autowidth => 1,
					minSize => [10,10],
					pack => { fill => "none", expand => 0, },
					onClick => sub { incrementPortion($_[0],$pvbox,$updateform,$k,$record{title},$updater,0); },
				);
			}
			# if manga, put in the number of read/volumes (button)
			if ($titletype eq 'pub') {
				my $pvolbox = $pvbox->insert(HBox => name => 'volbox', backColor => $backcolor);
				# put in the number of watched/episodes (button) -- or chapters
				my $vbut = $pvolbox->insert( Label =>
					name => 'vollabel',
					text => "$record{lastreadv}/$record{volumes}",
					onClick => sub { askPortion($pvbox,'volume',$k,$updater,$record{title},($record{status} == 3)); },
				);
				# link the button to a dialog asking for a new value
				my $upform = ($record{status} == 3 ? 5 : 4 );
				# put in a button to increment the number of volumes (using read or reread volumes)
				unless ($record{status} == 4) {
					my $incvbut = $pvolbox->insert( SpeedButton =>
						text => "+",
						backColor => $buttoncolor,
						font => applyFont('progbut'),
						minSize => [10,10],
						pack => { fill => "none", expand => 0, },
						onClick => sub { incrementPortion($_[0],$pvbox,$upform,$k,$record{title},$updater,1) },
					);
				}
			}
			$pvbox->sizeMin($widths[2],$rowheight * ($titletype eq 'pub' ? 2 : 1)) if (defined $widths[2] and $widths[2] > 0);
		}
		if ($titletype eq 'head') {
			my $score = $row->insert( Label =>
				text => $record{score},
				backColor => convertColor($headcolor),
			);
			$score->sizeMin($widths[3],$score->height) if (defined $widths[3] and $widths[3] > 0 and $widths[3] != 52); # not sure why 52 causes Prima::ScrollGroup::reset to go belly up, but I've tried other values near and far.
		} else {
			my $score = $row->insert( SpeedButton =>
				text => sprintf("%.1f",($record{score} or 0) / 10), # put in the score
				font => applyFont('button'),
				onClick => sub { scoreTitle($k,$titletype,$_[0],$updater); },
#				onClick => sub { scoreSlider($k,$titletype,$updater) },
			);
			$score->sizeMin($widths[3],$score->height) if (defined $widths[3] and $widths[3] > 0);
		}
		if ($titletype eq 'head') {
#			my $tags = Gtk2::Label->new("Tags");
#			$tags->show();
#			if ($bodyfont) { applyFont($tags,0); }
#			my $cb = Gtk2::EventBox->new();
#			$cb->add($tags);
#			$cb->show();
#			$cb->modify_bg("normal",Gtk2::Gdk::Color->parse(config('UI','headerbg') or $headcolor));
#			$target->attach($cb,4,5,0,1,qw( fill ),qw( fill ),0,0);
#			$tags->width($widths[4]) if (defined $widths[4] and $widths[4] > 0);
		} else {
#			my $tags = Gtk2::Button->new("Show/Edit tags"); # put in the tag list (button?)
## use $k for callback; it should contain the series/pub id #.
#			$tags->show();
#			$target->attach($tags,4,5,$rownum,$rownum+1,qw( shrink ),qw( shrink),1,0);
#			$tags->width($widths[4]) if (defined $widths[4] and $widths[4] > 0);
		}
		# put in a button to edit the title/list its volumes/episodes
#			$view->width($widths[6]) if (defined $widths[6] and $widths[6] > 0);
	} # end foreach my $k (@keys)
#	return @rows;
}
print ".";

my $partmax = 2000; # TODO: make this an option

sub addTitle {
	my ($gui,$tab) = @_;
	unless ($tab eq 'man' or $tab eq 'ani') { print "[E] addTitle does not recognize '$tab' as a valid option.\n"; return; }
	my $dbh = FlexSQL::getDB();
	my $box = $$gui{questionparent};
	$$gui{tabbar}->hide();
	$box->empty();
	my $tabstr = ($tab eq 'man' ? ' manga' : 'n anime');
	my $see = ($tab eq 'man' ? "read" : "watch");
	$box->insert( Label => text => "Add a$tabstr title", font => applyFont('bighead'), autoheight => 1, pack => { fill => 'x', expand => 1,}, autoHeight => 1, alignment => ta::Center, );
# status TINYINT DEFAULT 0,
	my $titlestat = $box->insert( XButtons => name => "status", pack => {fill=>'none',expand=>0});
	$titlestat->arrange('left');
	my @presets = (0,Sui::getStatHash($tab),'rew',"Re${see}ing");
	$titlestat-> build("Status:",@presets);
	my $row0 = $box->insert( HBox => name => 'row0');
	$row0->insert( Label => text => "Title", sizeMin => [150,20], pack => { fill => 'x', expand => 0 },);
	$row0->insert( Label => text => ($tab eq 'man' ? "Chapters" : "Episodes"), sizeMin => [100,20]);
	$row0->insert( Label => text => "Parts Seen", sizeMin => [100,20]);
	my $row1 = $box->insert( HBox => name => 'row1');
	my $name = $row1->insert( InputLine => text => "", name => 'sname', sizeMin => [150,20], hint => "The title of the anime", pack => { fill => 'x', expand => 0 },);
	$name->name('pname') if $tab eq 'man';
	my $parts = $row1->insert( SpinEdit => value => 0, name => 'episodes', min => 0, max => $partmax, step => 1, pageStep => 10, sizeMin => [100,20]);
	$parts->name('chapters') if $tab eq 'man';
	my $lastpart = $row1->insert( SpinEdit => value => 0, name => 'lastwatched', min => 0, max => $partmax, step => 1, pageStep => 10, sizeMin => [100,20]);
	my $row2 = $box->insert( HBox => name => 'row2');
	$row2->insert( Label => text => "Started", sizeMin => [150,20]);
	$row2->insert( Label => text => "Ended", sizeMin => [150,20]);
	my $row3 = $box->insert( HBox => name => 'row3');
	my $started = PGK::insertDateWidget($row3,$$gui{mainWin},{name => 'started',default => Common::today(), });
# ended DATE,
	my $ended = PGK::insertDateWidget($row3,$$gui{mainWin},{name => 'ended',default => Common::today(), });
# score TINYINT UNSIGNED,
	my $row4 = $box->insert( HBox => name => 'row4');
	$row4->insert( Label => text => "Score", sizeMin => [100,20]);
	$row4->insert( Label => text => "Seen", sizeMin => [100,20]);
	$row4->insert( Label => text => "Tags (comma separated)", sizeMin => [250,20]);
	$row4->insert( Label => text => "Type", sizeMin => [50,20]);
	my $row5 = $box->insert( HBox => name => 'row5');
	my $score = $row5->insert( InputLine => name => 'score', text => '0', sizeMin => [100,20]);
	my $seentimes = $row5->insert( SpinEdit => name => 'seentimes', value => 0, min => 0, max => 100, step => 1, pageStep => 5, sizeMin => [100,20], enabled => 0, );
	$titlestat->onChange(sub { unless ($titlestat->value eq 'com' or $titlestat->value eq 'rew') { $seentimes->enabled(0); $seentimes->value(0); } else { $seentimes->enabled(1); } });
# content INT(35) UNSIGNED,
	#my $content;
# rating TINYINT UNSIGNED,
	#my $rating;
	my $tags = $row5->insert( InputLine => name => 'tags', text => '', sizeMin => [250,20]);
	my $stype = $row5->insert( InputLine => text => 'TV', sizeMin => [50,20]); # TV, ONA, etc.
	my $row6 = $box->insert( HBox => name => 'row6');
	$row6->insert( Label => text => "Notes", sizeMin => [500,20]);
	my $row7 = $box->insert( HBox => name => 'row7');
	my $note = $row7->insert( InputLine => name => 'note', text => '', sizeMin => [500,20]);

	my $buttons = $box->insert( HBox => name => 'buttons', pack => { fill => 'x', expand => 1, });
	$buttons->insert( Button => text => "Cancel", onClick => sub { $box->empty(); $box->send_to_back(); $$gui{tabbar}->show(); $$gui{status}->text("Title addition cancelled."); });
	$buttons->insert( Button => text => "Add", onClick => sub {
		return unless ($name->text ne '');
		$_[0]->enabled(0);
		my %data; # hashify
		if ($titlestat->value eq 'com') {
			$lastpart->value = $parts->value;
		}
		foreach ($name, $started, $ended, $score, $stype, $note, $tags, $parts) {
			$data{$_->name} = $_->text;
		}
		foreach ($parts, $seentimes, ) {
			$data{$_->name} = $_->value;
		}
		if ($titlestat->value eq 'rew') {
			$data{($tab eq 'man' ? 'lastreread' : 'lastrewatched')} = $lastpart->value;
			$data{($tab eq 'man' ? 'lastreadc' : 'lastwatched')} = $parts->value;
		} else {
			$data{($tab eq 'man' ? 'lastreadc' : 'lastwatched')} = $lastpart->value;
		}
		delete $data{ended} if ($data{ended} eq $data{started});
		$data{score} = int($data{score}) * 10;
		my %stats = Sui::getStatIndex();
		$data{status} = $stats{$titlestat->value};
		my $tid = ($tab eq 'ani' ? 'sid' : 'pid');
		$data{$tid} = -1;
		my $target = passTableByCode($tab,$titlestat->value);
		die "No target" unless defined $target;
		my $ttype = ($tab eq 'man' ? 'pub' : 'series');
		my ($found,$realid) = Sui::getRealID($dbh,$$gui{questionparent},'usr',$ttype,\%data);
		if ($found) {
			print "[I] Title to be added was existing record $realid. Cancelling.";
			$$gui{tabbar}->show();
			$box->empty();
			$box->send_to_back();
			return;
		}
		$data{$tid} = $realid;
		my ($error,$cmd,@parms) = FlexSQL::prepareFromHash(\%data,$ttype,1,{idneeded => 1}); # prepare
		if ($error) { print "e: $error c: $cmd p: " . join(",",@parms) . "\n"; }
		$error = FlexSQL::doQuery(2,$dbh,$cmd,@parms); # submit
		$error = Sui::addTags($dbh,substr($ttype,0,1),$data{$tid},$data{tags});
		$$gui{tabbar}->show();
		$data{title} = $data{(substr($ttype,0,1) eq 'p' ? 'pname' : 'sname')};
		my $h = {"$realid" => \%data };
		my @rows = $target->get_widgets();
		buildTitleRows($ttype,$target,$h,@rows -1,$realid); # display
		$box->empty();
		$box->send_to_back();
	}, );
}
print ".";

sub incrementPortion {
	my ($caller,$target,$ttype,$titleid,$title,$updater,$volume) = @_;
	$caller->enabled(0);
	my ($value,$max,$volno) = getPortions($updater,$ttype,$titleid,$volume);
	unless (defined $max) {
		sayBox(getGUI('mainWin'),"Error: Could not retrieve count max.");
		$caller->enabled(1); # un-grey caller
		return;
	}
	unless ($value >= $max) { $value++; } else { return; }
	my $complete = 0;
	if (defined $value and $value == $max) { # ask to set complete if portions == total
# TODO: make this happen unless option says not to
		$complete = 1;
	}
	my $result = updatePortion($ttype,$titleid,$value,$updater,$complete); # call updatePortion
	if ($result == 0) { warn "Oops!";
	} else {
		setProgress($target,$volume,$value,$max) if (defined $target);
	}
	editPortion($title,$titleid,$value, ($volume ? 'volume' : ($ttype > 1 ? 'chapter' : 'episode')),$volno);
	$caller->enabled(1);
	return $value;
}
print ".";

sub getPortions {
	my ($updater,$uptype,$titleid,$volume) = @_;
	my ($value,$max,$volno);
	if ((config('DB','conserve') or 'mem') eq 'net') { # updating objects
		my $sobj = $updater; # get object
		# check if REF is for an Anime or Manga object
		# use uptype for this?
		# increment portion count
		warn "This is only a dream. I haven't really updated your objects, because this part hasn't been coded. Sorry. Smack the coder";
	} else {
		my $dbh = $updater;
		unless (defined $dbh) {
			$dbh = FlexSQL::getDB(); # attempt to pull existing DBH
		}
		unless (defined $dbh) { # if that failed, I have to die.
			die "getPortions was not passed a database handler!";
		}
		my $st = "SELECT episodes,lastwatched,lastrewatched FROM series WHERE sid=?";
		if ($uptype > 1) { $st = "SELECT chapters,lastreadc,lastreread,volumes FROM pub WHERE pid=?"; }
		if ($uptype > 3) { $st = "SELECT volumes,lastreadv, lastreadv FROM pub WHERE pid=?"; }
		if (0) { print "$st <= $titleid\n"; }
		my $res = FlexSQL::doQuery(5,$dbh,$st,$titleid);
		unless (defined $res) { return; } # no response: return
		$value = @$res[($uptype % 2 ? 2 : 1 )];
		$max = @$res[0];
		$volno = @$res[3] or 0;
		if (0) { print "Count: ($value/$max)\n"; }
	}
	return $value,$max,$volno;
}
print ".";

sub updatePortion {
	my ($uptype,$titleid,$value,$uph, $complete) = @_;
	if ((config('DB','conserve') or 'mem') eq 'net') { # updating objects
		my $sobj = $uph; # get object
		# check if REF is for an Anime or Manga object
		# use uptype for this?
		# increment portion count
		warn "This is only a dream. I haven't really updated your objects, because this part hasn't been coded. Sorry. Smack the coder";
	} else {
		my $dbh = $uph;
		unless (defined $dbh) {
			$dbh = FlexSQL::getDB(); # attempt to pull existing DBH
		}
		unless (defined $dbh) { # if that failed, I have to die.
			die "updatePortion was not passed a database handler!";
		}
		my @criteria = ( "lastwatched", "lastrewatched", "lastreadc", "lastrereadc", "lastreadv", "lastrereadv" );
		my $data = {};
		$$data{$criteria[$uptype]} = $value;
		$$data{($uptype < 2 ? "sid" : "pid" )} = $titleid;
		$$data{status} = 4 if $complete;
		my ($error,$st,@parms) = FlexSQL::prepareFromHash($data,($uptype < 2 ? "series" : "pub" ),1);
		unless ($error) {
			my $stat = getTitleStatus($dbh,$uptype,$titleid); # find out if re-viewing
			my $res = FlexSQL::doQuery(2,$dbh,$st,@parms); # update SQL table
			unless ($res == 1) { sayBox(getGUI('mainWin'),"Error: " . $dbh->errstr); return 0; } # rudimentary error message for now...
			incrementRepeats($dbh,$uptype,$titleid) if ($stat == 3 and $complete); # increment read/seentimes if completed re-viewing
		} else {
			sayBox(getGUI('mainWin'),"Error: $st"); return 0;
		}
	}
	return $value;
}
print ".";

sub setProgress {
	my ($target,$volume,$value,$max) = @_;
	# update the widgets that display the portion count
	my ($txtar,$nutar,$extar) = unpackProgBox($target);
	$txtar = $extar if ($volume);
	my $pprog = $value . "/" . ($max or '-');
	$txtar->text($pprog);
	unless ($volume) {
		my $rawperc = $value / ($max or $value * 2)  * 100;
		if (ref($nutar) =~ m/Gauge/) { $nutar->value($rawperc); }
		$nutar->text(sprintf("%.2f%%",$rawperc));
	}
}
print ".";

sub unpackProgBox {
	my ($pbox) = @_;
	my ($countwidget,$percwidget,$volwidget);
	my @kids = $pbox->get_widgets();
	foreach (@kids) {
		if (ref($_) =~ m/Gauge/ and $_->name eq 'partbar') { $percwidget = $_; }
		elsif (ref($_) =~ m/HBox/) {
			if ($_->name eq 'partbox') {
				my @a = $_->get_widgets();
				$countwidget = $a[0] if ($a[0]->name eq 'partlabel'); # should be this one
			} elsif ($_->name eq 'volbox') {
				my @a = $_->get_widgets();
				$volwidget = $a[0] if ($a[0]->name eq 'vollabel'); # should be this one
			}
		}
		print $_ . " " . $_->name . "\n" if (FIO::config('Debug','v') or 0);
	}
	return $countwidget,$percwidget,$volwidget;
}
print ".";

sub editPortion {
	my ($displaytitle,$title,$part,$ptype,$vol) = @_;
print "$displaytitle, $title, $part, $ptype";
	my ($dets,$dorate) = (FIO::config('Main','askdetails'),FIO::config('Main','rateparts'));
	return -1 unless ($dets or $dorate); # not doing anything unless there's something to do.
	my $click = 0;
	my $gui = getGUI();
	my $qbox = $$gui{questionparent};
	my $tabs = $$gui{tabbar};
	$tabs->hide() if defined $tabs;
	$qbox->empty();
	$qbox->bring_to_front();
	$qbox->insert( Label => text => "$displaytitle: $part ${ptype}s completed.", font => applyFont('body'), autoheight => 1, pack => { fill => 'x', expand => 1,}, autoHeight => 1, alignment => ta::Center, );
	my $values = {part => $part,};
	my $st = {
		'episode' => "SELECT * FROM episode WHERE sid=? AND eid=?;",
		'chapter' => "SELECT * FROM chapter WHERE pid=? AND cid=?;",
		'volume' => "SELECT * FROM volume WHERE pid=? AND vid=?;",
	};
	my $key = { 'episode' => 'eid', 'chapter' => 'cid', 'volume' => 'vid' };
	$st = $$st{$ptype} or die "Bad table name"; # no sympathy for bad tables!
	$key = $$key{$ptype}; # already validated in previous line.
	my $dbh = FlexSQL::getDB() or sayBox(getGUI('mainWin'),"portionExecute couldn't get database handler.");
	return unless $dbh;
	my $res = FlexSQL::doQuery(3,$dbh,$st,$title,$part,$key);
	my $defaults = {};
	if ($res) {
		$$defaults{title} = $$res{$part}{ename} if defined $$res{$part}{ename};
		$$defaults{title} = $$res{$part}{vname} if defined $$res{$part}{vname};
		$$defaults{title} = $$res{$part}{cname} if defined $$res{$part}{cname};
		$$defaults{date} = $$res{$part}{firstwatch} if defined $$res{$part}{firstwatch};
		$$defaults{date} = $$res{$part}{firstread} if defined $$res{$part}{firstread};
		$$defaults{score} = $$res{$part}{score} if defined $$res{$part}{score};
		$$defaults{rating} = $$res{$part}{rating} if defined $$res{$part}{rating};
		$$defaults{content} = $$res{$part}{content} if defined $$res{$part}{content};
	}
	sub portionExecute {
		my ($dbh,$title,$part,$ptype,$data,$target,$parent,$volno) = @_;
		return unless $dbh;
		my $st = {
			'episode' => "SELECT firstwatch FROM episode WHERE sid=? AND eid=?;",
			'chapter' => "SELECT firstread FROM chapter WHERE pid=? AND cid=?;",
			'volume' => "SELECT firstread FROM volume WHERE pid=? AND vid=?;",
		};
		$st = $$st{$ptype} or die "Bad table name"; # no sympathy for bad tables!
		my $res = FlexSQL::doQuery(6,$dbh,$st,$title,$part);
		unless ($res) {
			$st = "INSERT INTO";
		} else {
			$st = "UPDATE";
		}
		$st = "$st $ptype SET "; # the validity of $ptype was checked already, so we can trust it now.
		my %columns = (
			episode => {
				title => 'ename',
				date => 'firstwatch',
				score => 'score',
				rating => 'rating',
				content => 'content',
			},
			chapter => {
				title => 'cname',
				date => 'firstread',
				score => 'score',
				rating => 'rating',
				content => 'content',
			},
			volume => {
				title => 'vname',
				date => 'firstread',
				score => 'score',
				rating => 'rating',
				content => 'content',
			},
		);
#		print "Title $title/$part:";
		my @parms;
		foreach (keys %$data) {
#			print "\n$_ => $columns{$ptype}{$_}: $$data{$_}";
			next unless defined $columns{$ptype}{$_};
			$st = "$st$columns{$ptype}{$_}=?, ";
			push(@parms,$$data{$_});
		}
		$st = substr($st,0,length($st)-2); # trim final ", "
		if ($res) {
			$st = "$st WHERE";
			$st = "$st " . ($ptype eq 'episode' ? "sid=? AND eid=?" : ($ptype eq 'volume' ? "pid=? AND vid=?" : "pid=? AND cid=?")) . ";";
		} else {
			$st = "$st, " . ($ptype eq 'episode' ? "sid=?, eid=?" : ($ptype eq 'volume' ? "pid=?, vid=?" : "pid=?, cid=?")) . ";";
		}
		push(@parms,$title,$part);
#		push(@parms,($volno or 0)) if ($ptype eq 'chapter');
		$res = FlexSQL::doQuery(2,$dbh,$st,@parms);
		$target->empty();
		unless ($res == 1) {
			$target->insert( Label => text => "$res: " . (defined $dbh->errstr ? $dbh->errstr : 'unknown'));
			$target->insert( Button => text => "Continue", onClick => sub {
				$target->empty();
				$parent->show() if defined $parent;
				$target->send_to_back();
			});
			return 2;
		} else {
			$parent->show() if defined $parent;
			$target->send_to_back();
			return 0;
		}
	}
	if ($dets) { # If askdetails, show form for details
		$qbox->insert( Label => text => "You can enter any details about this $ptype you would like to store:");
		my $tibox = PGK::labelBox($qbox,"Title of $ptype",'h',boxex=>0); # show episode details form
		$tibox->insert( InputLine => text => ($$defaults{title} or ''), onChange => sub { $$values{title} = $_[0]->text; });
#		my $cbox = PGK::labelBox($qbox,"Objectionable content",'h',boxex=>0);
#		my $rbox = PGK::labelBox($qbox,"Appropriate for age",'h',boxex=>0);
#		$rbox->insert( SpinEdit => value => ($$defaults{rating} or 0), min => 0, max => 100, step => 1, pageStep => 5, onChange => sub { $$values{rating} = $_[0]->value; }, );
	}
	my $seen = ($ptype eq 'episode' ? "watched" : "read");
	my $date = PGK::insertDateWidget($qbox,$$gui{mainwin},{label => "First $seen", default => ($$defaults{date} or Common::today()),boxex=>0, });
	$$values{date} = $date->text;
	$date->onClick( sub { $$values{date} = $date->text; });
	if ($dorate) { # If rateparts, show buttons to rate
		my $score = $qbox-> insert( XButtons => name => 'score' ); # show rating buttons
		$score->arrange("left"); # line up buttons horizontally
		my @presets = ("0","Don't Rate","1","1","2",'2','3','3','4','4','5','5');
		my $current = (int($$defaults{score} or 0));
		$score-> build("Score for $ptype:",$current,@presets); # turn key:value pairs into exclusive buttons
		$score->onChange( sub { $$values{score} = $score->value(); } );
	}
	$qbox->insert( Label => text => ' ', pack => { fill => 'both', expand => 1 });
	my $butbox = $qbox->insert( HBox => name => 'buttons');
	$butbox->insert( Button => text => 'Set Details', onClick => sub { $$values{date} = $date->text; portionExecute($dbh,$title,$part,$ptype,$values,$qbox,$tabs,$vol); $click = 2; }, );
	$butbox->insert( Button => text => 'Skip Setting Details', onClick => sub {
		$tabs->show() if defined $tabs;
		$qbox->empty();
		$qbox->send_to_back();
		$click = 1;
	} );
	$::application->yield();
#	while ($click == 0) { # magic command that keeps function from returning until user presses button goes here
#		$::application->yield();
#		PGK::Pwait(1);
#	}
}
print ".";

sub scoreTitle {
# scoreTitle($k,$titletype,$record{score},$_[0],$updater); },
	my ($title,$ttype,$caller,$dbh) = @_;
	my ($dets,$dorate) = (FIO::config('Main','askdetails'),FIO::config('Main','rateparts'));
	my $gui = getGUI();
	my $qbox = $$gui{questionparent};
	my $tabs = $$gui{tabbar};
	$tabs->hide() if defined $tabs;
	$qbox->bring_to_front();
	$qbox->empty();
	my $st = {
		'series' => "SELECT sid,sname,episodes,score FROM series WHERE sid=?",
		'pub' => "SELECT pid,pname,chapters,score FROM pub WHERE pid=?",
	};
	my $key = {
		'series' => 'sid',
		'pub' => 'pid',
	};
	$st = $$st{$ttype} or die "Bad table name $ttype"; # no sympathy for bad tables!
	$key = $$key{$ttype}; # already validated in previous line.
	unless (defined $dbh) { $dbh = FlexSQL::getDB() or sayBox(getGUI('mainWin'),"scoreTitle couldn't get database handler."); }
	return unless $dbh;
	my %tdata;
	my $res = FlexSQL::doQuery(3,$dbh,$st,$title,$key);
	return unless ($res);
	$tdata{score} = $$res{$title}{score};
	$tdata{title} = $$res{$title}{($ttype eq 'series' ? 'sname' : 'pname')};
	$tdata{ptype} = ($ttype eq 'series' ? 'episodes' : 'chapters');
	$tdata{ttype} = ($ttype eq 'series' ? 'series' : 'pub');
	$tdata{max} = $$res{$title}{$tdata{ptype}};
	$tdata{key} = $key;
	$qbox->insert( Label => text => "What is your rating of $tdata{title} ($tdata{max} $tdata{ptype})?", font => applyFont('body'), autoheight => 1, pack => { fill => 'x', expand => 1,}, autoHeight => 1, alignment => ta::Center, );
	my $barbox = $qbox->insert( HBox => name => 'scores', pack => {fill => 'x', expand => 0} );
	my $suggtxt = $qbox->insert( Label => text => "Calculating...", wordWrap => 1, autoHeight => 1, pack => {fill => 'x', expand => 0},);
	my $parms = {
		circ => (FIO::config('UI','knobscore') or 0),
		value => $tdata{score},
	};
	my @ticks;
	my $i = 0;
	while ($i <= ((FIO::config('Main','starscore') or 0) ? 50 : 100)) {
		push(@ticks,{ value => $i, text => sprintf("%d",$i/10), });
		$i += 10;
	}
	my $score = $qbox-> insert( ($$parms{circ} ? 'CircularSlider' : 'Slider') =>
		value => ($$parms{value} or 0),
		min => 0,
		max => ((FIO::config('Main','starscore') or 0) ? 50 : 100),
		step => 1,
		pageStep => 10,
		vertical => 0,
		width => 400,
		);
	$score->set_ticks(@ticks);
	my $spacer = $qbox->insert( Label => text => " ", pack => { fill => 'both', expand => 1 }, );
	my $buttons = $qbox->insert( HBox => name => 'buttons', pack => { fill => 'x', expand => 0 },);
	$buttons->insert( SpeedButton => text => "Set", onClick => sub {
		$st = "UPDATE $ttype SET score=? WHERE $tdata{key}=?;"; # update score
		my @parms = ($score->value,$title);
		my $result = FlexSQL::doQuery(2,$dbh,$st,@parms);
		$caller->text(sprintf("%.1f",$score->value / 10));
		$qbox->empty();
		$tabs->show() if defined $tabs;
		$qbox->send_to_back();
	});
	$buttons->insert( SpeedButton => text => "Cancel", onClick => sub {
		$qbox->empty();
		$tabs->show() if defined $tabs;
		$qbox->send_to_back();
	});
	unless (FIO::config('Main','autoscore')) {
		$suggtxt->destroy();
	} else {
		$st = {
			'series' => "SELECT eid,score,ename FROM episode WHERE sid=?",
			'pub' => "SELECT cid,score,cname FROM chapter WHERE pid=?",
		};
		$key = {
			'series' => 'eid',
			'pub' => 'cid',
		};
		$st = $$st{$ttype}; # already validated
		$key = $$key{$ttype}; # already validated
		$st = "$st ORDER BY $key;";
		$res = FlexSQL::doQuery(4,$dbh,$st,$title);
		my ($scores,$bars) = (0,[]);
		my $suggested = 0;
		my $frames = 20; # because we're using gauges, we have to base it on 100, not 5 or 10.
		if ($res) {
			($scores,$suggested) = fillBoxwithBars($barbox,$scores,$bars,$frames,$res,{width => ($tdata{max} > 12 ? ($tdata{max} > 24 ? ($tdata{max} > 36 ? 7 : 14) : 21) : 28)});
		}
		$suggested /= $scores if ($scores);
		$suggested *= 2 unless (FIO::config('Main','starscore'));
		$suggested *= ((($tdata{max} or 0) or $scores) / $scores) if (FIO::config('Main','extendscore') and $scores);
		$suggested *= (10/(FIO::config('Main','wowfactor') or 8.45)) if ($suggested > (FIO::config('Main','wowfactor') or 8.45) * 0.56); # This is a ratio, so no need to adjust for 5-star scoring;
		$suggested = 5 if ($suggested > 5 and FIO::config('Main','starscore'));
		$suggested = 11 if ($suggested > 11);
		$suggtxt->text(sprintf("Based on your rated $tdata{ptype}, $tdata{title} deserves a score of %.1f",$suggested));
		if ($score->value == 0) {
			$suggested = 10 if ($suggested > 10);
			$suggested = int($suggested + 0.5) if (FIO::config('Main','intscore'));
			$score->value(int($suggested * 10));
		}
	}
}
print ".";

sub pulseBars {
	my ($group,$mult) = (@_,20);
	return unless (ref($group) eq "ARRAY");
	foreach (@$group) {
		$_->value($_->value + int($_->name));
#		$_->text('');
	}
	shift @$group if ($$group[0]->value >= int($$group[0]->name) * $mult);
	$::application->yield; # try to make this animate smoothly
}
print ".";

sub askPortion {
	my ($target,$uptype,$titleid,$updater,$title) = @_;
	my ($value,$max,$volno) = getPortions($updater,$uptype,$titleid,($uptype > 3));
	unless (defined $max) {
		sayBox(getGUI('mainWin'),"Error: Could not retrieve count max.");
		return;
	}
	my $gui = getGUI();
	my $qbox = $$gui{questionparent};
	my $tabs = $$gui{tabbar};
	$tabs->hide() if defined $tabs;
	$qbox->empty();
	my $rp = ($uptype % 2 ? '' : 're');
	my ($key,$ptype,$ttype,$column) = ('sid','episodes','series',"last${rp}watched");
	if ($uptype > 1) { ($key,$ptype,$ttype,$column) = ('pid','chapters','pub',"last${rp}readc"); }
	if ($uptype > 3) { ($ptype,$column) = ('volumes','lastreadv'); }
	$qbox->insert( Label => text => " ", name => 'spacer', pack => { fill => 'y', expand => 1},);
	$qbox->insert( Label => text => "How many $ptype of $title have you finished?", wordWrap => 1, autoHeight => 1, pack => { fill => 'x', expand => 0}, valign => ta::Bottom, alignment => ta::Center);
	my $row = PGK::labelBox( $qbox,"",'numrow','h', boxex => 0, labex => 0);
	my $n = $row->insert( SpinEdit => value => $value, min => 0, max => ($max or 1000), step => 1, pageStep => 5, autoHeight => 1, font => applyFont('bigent'), sizeMin => [100,50]);
	$row->insert( Label => text => " ", name => 'spacer', pack => { fill => 'x', expand => 1}, sizeMin => [75,20]);
	$row->insert( SpeedButton => text => "Set", onClick => sub {
		my $value = $n->value;
		my $result = updatePortion($uptype,$titleid,$value,$updater); # call updatePortion
		if ($result == 0) { warn "Oops!";
		} else {
			setProgress($target,($uptype > 3),$value,$max);
		}
		editPortion($title,$titleid,$value,($uptype > 3 ? 'volume' : ($ttype eq 'pub' ? 'chapter' : 'episode')));
		if (defined $value and $value == $max) { # ask to set complete if portions == total
			warn "Not asking to move to Completed, because it hasn't been coded! Smack the coder";
		}
	});
	$row->insert( SpeedButton => text => "Cancel", onClick => sub {
		$qbox->empty();
		$tabs->show();
		$qbox->send_to_back();
	});
	$qbox->insert( Label => text => " ", name => 'spacer', pack => { fill => 'y', expand => 1},);
}
print ".";

sub spreadRecent {
	my ($dbh,$recent) = @_;
	my $st = "SELECT DISTINCT %s,%s FROM %s";
	my %fields = (
		pub => ['pid','firstread','chapter','cid','cname','pname',"Manga",'lastreadc','lastreread'],
		series => ['sid','firstwatch','episode','eid','ename','sname',"Anime",'lastwatched','lastrewatched'],
	);
	my $limit = (FIO::config('Recent','reclimit') or 5);
	$limit += 3 if $limit; # allow for 3 duplicates
	$recent->empty();
	my $refresher = $recent->insert( SpeedButton => text => "Refresh", onClick => sub { spreadRecent($dbh,$recent); }, enabled => 0);
	foreach ('series','pub') {
		my $timeframe = (FIO::config('Recent','days') or 10);
		my $rcmd = sprintf("$st WHERE %s > DATE_SUB(CURDATE(),INTERVAL $timeframe DAY) ORDER BY %s DESC LIMIT %d;",$fields{$_}[0],$fields{$_}[1],$fields{$_}[2],$fields{$_}[1],$fields{$_}[1],$limit);
		my $cmd = sprintf("$st ORDER BY %s DESC LIMIT %d;",$fields{$_}[0],$fields{$_}[1],$fields{$_}[2],$fields{$_}[1],$limit);
# print "Asking database: $cmd\n";
		my $res = FlexSQL::doQuery(4,$dbh,$rcmd);
		(scalar @$res or ($res = FlexSQL::doQuery(4,$dbh,$cmd)));
		if ($res) {
			$recent->insert( Label => text => "$fields{$_}[6] Activity", font => applyFont('head'), alignment => ta::Left, pack => {fill => 'x'}, autoHeight => 1);
			my $key = $_;
			my @sids;
			foreach (@$res) {
				next unless ((scalar(@sids) <= 1 or Common::findIn($$_[0],@sids) < 0) and $limit);
				push(@sids,$$_[0]); # ^ skip if already used, <- record use
				$limit--; # keep extras from exceeding user-set limit
				my $date = $$_[1];
				$cmd = sprintf("SELECT %s,%s,%ss,status,%s,%s,score FROM %s WHERE %s=?;",$fields{$key}[0],$fields{$key}[5],$fields{$key}[2],$fields{$key}[7],$fields{$key}[8],$key,$fields{$key}[0]);
				my $subres = FlexSQL::doQuery(3,$dbh,$cmd,$$_[0],$fields{$key}[0]);
				unless ($subres) {
					warn "Something went wrong with the query: $dbh->errstr";
					next;
				}
				my ($bars,$frames,$max,$tname,$tprog,$status,$tid,$rated) = ([],20,$$subres{$$_[0]}{$fields{$key}[2] . "s"},$$subres{$$_[0]}{$fields{$key}[5]},$$subres{$$_[0]}{($$subres{$$_[0]}{status} == 3 ? $fields{$key}[8] : $fields{$key}[7])},$$subres{$$_[0]}{status},$$_[0],$$subres{$$_[0]}{score});
				my $shorttitle = Common::shorten($tname,25);
				print "$tname was last active on $date.\n" if (FIO::config('Debug','v'));
				my $ifdate = (FIO::config('Recent','showdate') ? "($date)" : "");
				my $row = $recent->insert( HBox => name => "$$_[0] row", alignment => ta::Left, pack => {fill => 'x', expand => 0}, ipady => 1, pady => 4, );
				my $barbox = $row->insert( HBox => name => "$$_[0] bars", alignment => ta::Left, pack => {fill => 'x', expand => 1}, ipady => 1, pady => 1, );
#				$row->insert( Widget => name => 'spacer', pack => {fill => 'x', expand => 1, }, sizeMax => [1000,10]);
				my $lab = $row->insert( Label => text => "$ifdate: $shorttitle", alignment => ta::Left, pack => {fill => 'none'}, hint => "$tname\nLast watched on $date");
				$cmd = sprintf("SELECT %s,score,%s FROM %s WHERE %s=? ORDER BY %s ASC;",$fields{$key}[3],$fields{$key}[4],$fields{$key}[2],$fields{$key}[0],$fields{$key}[3]);
				$subres = FlexSQL::doQuery(4,$dbh,$cmd,$tid);
				my ($scores,$suggested) = (0,0);
				if ($subres) {
					unless (FIO::config('Recent','hiddenepgraph')) {
						($scores,$suggested) = fillBoxwithBars($barbox,0,$bars,$frames,$subres,{height => 30, width => 7});
					} else {
						foreach (@$subres) {
							my ($k,$n,$s) = (sprintf("%03d",$$_[0]),($$_[2] or ""),$$_[1]);
							$suggested += $s;
							$scores++;
							$barbox->insert( Label => text => $s, hint => "$k ($n)", margin => 2);
						}
					}
					$lab->text(sprintf("%s %s - Total: %02d",$ifdate,$shorttitle,$suggested));
				} else {
					warn "Something went wrong with the query: $dbh->errstr";
				}
				my $uform = ($key eq "series" ? ($status == 3 ? 1 : 0 ) : ($status == 3 ? 3 : 2 ) );
				unless ($status == 4 or $tprog >= $max) {
					$tprog++;
					$row->insert( SpeedButton =>
						text => sprintf("Watch %s %02d",$fields{$key}[2],$tprog),
						onClick => sub {
							my $prog = incrementPortion($_[0],undef,$uform,$tid,$tname,$dbh,0);
							# pull new part from part table
#							$cmd = sprintf("SELECT %s,score,%s,%s FROM %s WHERE %s=? AND %s=?;",$fields{$key}[3],$fields{$key}[4],$fields{$key}[1],$fields{$key}[2],$fields{$key}[0],$fields{$key}[3]);
#							$subres = FlexSQL::doQuery(4,$dbh,$cmd,$tid,$prog);
							# add bar to barbox
#							($scores,$suggested) = fillBoxwithBars($barbox,0,$bars,$frames,$subres,{height => 30, width => 7});
							# update total
#							$lab->text("($date) $tname - Total: $suggested" );
							$prog++;
							$_[0]->text(sprintf("Watch %s %02d",$fields{$key}[2],$prog));
						},
#						sizeMin => [100,15],
					);
				} elsif ($rated == 0) {
					my $score = $row->insert( SpeedButton =>
						text => "Rate title",
						font => applyFont('button'),
						onClick => sub { scoreTitle($tid,$key,$_[0],$dbh); },
					);					
				} else {
					$row->insert( Label => text => "Completed and scored");
				}
			}
		}
	}
	$refresher->enabled(1);
}
print ".";

sub fillBoxwithBars {
	my ($target,$scores,$bars,$frames,$mylist,$exargs) = @_;
	my $suggested = 0;
	foreach (@$mylist) {
#		printf("%03d: $$_[1] (%s)\n",$$_[0],($$_[2] or "?"));
		my ($k,$n,$inc) = (sprintf("%03d",$$_[0]),($$_[2] or ""),$$_[1]);
#		next unless $inc; # no need to make a bar for non-scored item
		my $val = 0;
		if (FIO::config('UI','noanimate')) {
			$val = $inc * $frames;
		}
		$suggested += $inc;
		$scores++;
		my $this = $target->insert( Gauge => vertical => 1, value => $val, name => "$inc", hint => "$k ($n)", size => [($$exargs{width} or 28),($$exargs{height} or 100)],);
		unless ($inc) {
			if (defined $$exargs{title} and defined $$exargs{titleid} and defined $$exargs{part}) {
				my @parms = ($$exargs{title},$$exargs{titleid},$k,$$exargs{part});
				$this->onClick(sub { editPortion(@parms); });
			} else {
				warn "Required extra arguments were not provided" . Common::lineNo(1) . "\n";
			}
		}
		push(@$bars,$this);
		pulseBars($bars,$frames);
	}
	while (@$bars) {
		pulseBars($bars,$frames);
	}
	return $scores,$suggested;
}
print ".";

sub getTitleStatus {
	my ($dbh,$uptype,$tid) = @_;
	my $st = "SELECT status FROM series WHERE sid=?";
	if ($uptype > 1) { $st = "SELECT status FROM pub WHERE pid=?"; }
	my $res = FlexSQL::doQuery(0,$dbh,$st,$tid);
	return $res unless ("" eq "$res");
	warn $dbh->errstr;
	return -1;
}
print ".";

sub incrementRepeats {
	my ($dbh,$typ,$tid) = @_;
	my $st = "UPDATE series SET seentimes=seentimes+1 WHERE sid=?";
	if ($typ > 1) { $st = "UPDATE pub SET readtimes=readtimes+1 WHERE pid=?"; }
	my $res = FlexSQL::doQuery(2,$dbh,$st,$tid);
	unless ($res == 1) {
		my $string = "incrementRepeats could not increment field because of error: $res";
		(FIO::config('Main','fatalerr') ? die $string : warn $string);
	}
}
print ".";

=item devHelp PARENT UNFINISHEDTASK

Displays a message that UNFINISHEDTASK is not done but is planned.
TODO: Remove from release.
No return value.

=cut
sub devHelp {
	my ($target,$task) = @_;
	sayBox($target,"$task is on the developer's TODO list.\nIf you'd like to help, check out the project's GitHub repo at http://github.com/over2sd/pomal.");
}
print ".";

sub checkTitle {
	my ($dbh,$target,$name,$safetable,$pattern) = @_;
	$pattern = qr|([Tt]he )?([A-Za-z\w]+)| unless (defined $pattern and length($pattern) > 0); # Different patterns allowed via option
	$safetable =~ m/([ps])/;
	my $x = $1;
	my $id = -1;
	$name =~ m/$pattern/;
	my $likename = ($2 or $1);
	unless (length($likename) > 1) {
		my $err = "You must supply checkTitle with a title.";
		Common::errorOut('inline',-1,{string => $err});
		PGK::sayBox($target,$err);
		return -1;
	}
	$target->insert( Label => text => "Searching for $likename...");
	$likename = "%$likename" unless FIO::config('DB','checkfromstart');
	$target = getGUI("questionparent") unless defined $target;
# yesnoXB($target);
	my $st = "SELECT ${x}id,${x}name,status FROM $safetable WHERE ${x}name LIKE ?;";
	my $res = FlexSQL::doQuery(4,$dbh,$st,"$likename%");
	if (@$res) {
		my $query = $target->insert( VBox => name => "questionbox" );
		$query->insert( Label => text => "Is one of the following titles the same as $name?" );
		my $stats = Sui::getStatArray(($x eq 'p' ? 'man' : 'ani'));
		foreach (@$res) {
			my ($i,$t,$s) = @$_;
			$s = $$stats[$s];
			$query->insert( SpeedButton => text => "$t ($s)", onClick => sub { $id = $i; });
		}
		$query->insert( SpeedButton => text => "No, $name is a new title.", onClick => sub { $id = -2; });
		while ($id == -1 and defined $target) { # wait until button pressed or target destroyed
			PGK::Pwait(1);
		}
		$query->empty();
		$query->destroy();
	} else {
		$id = -2; # not found, so not asking. Title needs new ID.
	}
	return $id;
}
print ".";

sub switchToStatus {
	my ($dbh,$target,$typ,$stat,$buttonbar,$button,$placement,%exargs) = @_;
# DB handle, target, title type (a/m), status, container of buttons to enable, button to disable
	unless (config('UI','notabs')) {
		foreach ($buttonbar->get_widgets) {
			$_->checked(0);
			$_->enabled(1); # enable all buttons
			$button = $_ if (not defined $button and $_->name eq $stat);
		}
		$button->checked(1) if defined $button; # otherwise, oops?
		$button->enabled(0) if defined $button; # otherwise, oops?
		foreach ($target->get_widgets) { # which will check target for that status...
			if ($_->name eq "$typ$stat") {
				$_->bring_to_front();
				return;
			}
		}
	}
	# and load a new box into it if that status is not found.
##1285 ERROR?
	my $boxtext = ($button->text or "$typ/$stat" or "?");
#	print "Emptying box..." if (FIO::config('UI','jitload') or 0) and (1 or FIO::config('Debug','v')); # if jit-load enabled, this will clear the target of other status boxes before inserting new box.
	$target->empty() if (FIO::config('UI','jitload') or config('UI','notabs') or 0); # if jit-load enabled, this will clear the target of other status boxes before inserting new box.
	$::application->yield();
	my $rows;
	unless (config('UI','notabs')) {
		my ($x,$y,$w,$h) = @$placement;
		my $box = $target->insert( VBox => name => "$typ$stat", place => { in => $target, relx => 0, x => $x, rely => 1, y => $y, anchor => 'nw', }, sizeMin => [$w,$h]);
		$rows = pullRows($dbh,$box,$typ,$stat,$boxtext,undef,%exargs);
		foreach ($target->get_widgets) { # which will check target for that status...
			if ($_->name eq "$typ$stat") {
				$_->bring_to_front();
			}
		}
	} else {
		$rows = pullRows($dbh,$target,$typ,$stat,$boxtext,undef,%exargs);
	}
	return $rows;
}
print ".";

sub pullRows {
	my ($dbh,$target,$typ,$stat,$text,$h,%exargs) = @_;
	my $sortkey = 'title';
	$exargs{sortkey} = $sortkey;
	$exargs{offset} = ($exargs{offset} or 0); 
	my $rowtyp = ($typ eq 'man' ? 'pub' : 'series');
	# %exargs allows limit by parameters (e.g., at least 2 episodes (not a movie), at most 1 episode (movie))
	# $exargs{maxparts} = 1
	# getTitlesByStatus will put Watching (1) and Rewatching (3) together unless passed "rew" as type.
	unless ($h) {
		$h = Sui::getTitlesByStatus($dbh,$rowtyp,$stat,%exargs);
	}
#print scalar keys(%$h) . " rows pulled\n";
	my @keys = Common::indexOrder($h,$sortkey);
	# make a label
	my $fulltext = $text;
	if ($exargs{limit}) {
		my $off = $exargs{offset}; my $lim = $exargs{limit};
		@keys = splice(@keys,$off,$lim);
		$fulltext = "$fulltext (" . ($off + 1) ."-" . ($off + @keys) . ")";
		unless (scalar @keys < $exargs{limit} and $exargs{offset} == 0) {
			my $navbox = $target->insert( HBox => name => "navigation bar", pack => { fill => 'x', expand => 0});
			$navbox->insert( SpeedButton => text => "|<", onClick => sub { $target->empty; $exargs{offset} = 0; pullRows($dbh,$target,$typ,$stat,$text,$h,%exargs); }) if $exargs{offset} != 0;
			$navbox->insert( SpeedButton => text => "<", onClick => sub { $target->empty; $exargs{offset} -= $exargs{limit}; pullRows($dbh,$target,$typ,$stat,$text,$h,%exargs); }) if $exargs{offset} >= $exargs{limit};
			$navbox->insert( SpeedButton => text => ">", onClick => sub { $target->empty; $exargs{offset} += $exargs{limit}; pullRows($dbh,$target,$typ,$stat,$text,$h,%exargs); }) unless (scalar @keys < $exargs{limit});
		}
	}
	my $label = $target->insert( Label => text => $fulltext, pack => { fill => 'y', expand => 0, side => "left", padx => 5, }, font => applyFont('label'), );
##	print "Looking for " . $typ . "/" . $stat . "...";
	my $table = $target->insert( VBox => name => "${stat}table", backColor => (convertColor(config('UI','listbg') or "#eef")), pack => { fill => 'both', expand => 1, side => "left", padx => 5, pady => 5, }, );
###	TODO: push table to $gui's list of tables
	my $tlist = { 'h' => {
		title => "Title",
		status => 0,
		score => "Score",
		sid => "?"
	}};
	$::application->yield();
	buildTitleRows("head",$table,$tlist,0,'h');
	# fill the box with titles
	buildTitleRows($rowtyp,$table,$h,($exargs{offset} or 0),@keys);
	unless (scalar @keys) {
		$table->insert( Label => text => "There are no " . ($exargs{offset} ? "more " : " ") . "results to display.", pack => {fill => 'x', expand => 1});
	}
	return $h;
}
print ".";

sub chooseStatus{
devHelp(getGUI('mainWin'),"Choosing a status");
return;
	my ($dbh,$row,$icon,$status,$k,$typ) = @_;
}
print ".";

sub setStatus {
	my ($dbh,$row,$icon,$status,$tid,$typ) = @_;
	die "[E] setStatus really can't function without a DB handle, a status, and a title type and id.\n" unless (defined $dbh and defined $tid and defined $status and defined $typ);

}
print ".";

sub tiDets {
	my ($dbh,$target,$ttype,$titleid,$title,$max) = @_;
	$target->bring_to_front(); # WARNING: target will be destroyed when we finish with it.
	$target->insert(Label => text => "Details of title $title:", pack => { fill => 'x', expand => 0});

	$target->insert(Label => text => ($ttype eq 'pub' ? 'Chapter' : 'Episode') . "s:",pack => { fill => 'x', expand => 0});
	my $lab = $target->insert( Label => text => "Thinking...");
	my $barbox = $target->insert( HBox => name => "ratebars", pack => { fill => 'x', expand => 1});
	my %fields = (
		pub => ['pid','firstread','chapter','cid','cname','pname',"Manga",'lastreadc','lastreread'],
		series => ['sid','firstwatch','episode','eid','ename','sname',"Anime",'lastwatched','lastrewatched'],
	);
	my ($frames,$scores,$suggested,$bars) = (20,0,0,[]);
	my $cmd = sprintf("SELECT %s,score,%s FROM %s WHERE %s=? ORDER BY %s ASC;",$fields{$ttype}[3],$fields{$ttype}[4],$fields{$ttype}[2],$fields{$ttype}[0],$fields{$ttype}[3]);
	my $subres = FlexSQL::doQuery(4,$dbh,$cmd,$titleid);
	if ($subres) {
		unless (FIO::config('Recent','hiddenepgraph')) {
			($scores,$suggested) = fillBoxwithBars($barbox,0,$bars,$frames,$subres,{height => 30, width => 7,title => $title, titleid => $titleid, parts => ($ttype eq 'pub' ? 'chapter' : 'episode')});
		} else {
			foreach (@$subres) {
				my ($k,$n,$s) = (sprintf("%03d",$$_[0]),($$_[2] or ""),$$_[1]);
				$suggested += $s;
				$scores++;
				$barbox->insert( Label => text => $s, hint => "$k ($n)", margin => 2);
			}
		}
		$lab->text("Total: $suggested" );
	}
	my $st = sprintf("SELECT %s FROM %s WHERE %s=? AND score NOT IN (NULL,0);",($ttype eq 'pub' ? 'cid' : 'eid'),($ttype eq 'pub' ? 'chapter' : 'episode'),($ttype eq 'pub' ? 'pid' : 'sid'));
	my $result = (FlexSQL::doQuery(7,$dbh,$st,$titleid) or []);;
	my $hb = $target->insert( HBox => name => "unrated", pack => { fill => 'x', expand => 1});
	foreach (1 .. $max) {
		if (scalar @$result && Common::findIn($_,@$result) != -1) { next; } # only rate episodes not found in list of rated episodes
		my @parms = ($_, ($ttype eq 'pub' ? 'chapter' : 'episode'));
		$hb->insert( SpeedButton => text => $_, onClick => sub { print "Firing $parms[0]!\n"; editPortion($title,$titleid,@parms); });
	}
	my $canc = $target->insert( Button => text => "Done", onClick => sub { $target->destroy(); });
}
print ".";

print " OK; ";

1;
