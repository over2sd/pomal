# Graphic User Interface module
use strict; use warnings;
package PGUI;
print __PACKAGE__;

use Prima qw(Application Buttons MsgBox FrameSet StdDlg Sliders Notebooks ScrollWidget);
$::wantUnicodeInput = 1;

use PGK qw( VBox Table Pdie Pwait applyFont getGUI );
use FIO qw( config );

sub buildMenus { #Replaces Gtk2::Menu, Gtk2::MenuBar, Gtk2::MenuItem
	my $gui = shift;
	my $menus = [
		[ '~File' => [
			['~Import', 'Ctrl-O', '^O', sub { importGUI() } ],
			['~Export', sub { message('export!') }],
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

sub buildTableRows {
	my ($titletype,$target,$tlist,$rownum,@keys) = @_;
#print "\nbTR($titletype,$target,$tlist,$rownum,[".join(',',@keys)."])\n";
	my $numbered = (config('UI','linenos') ? 1 : 0);
	my $rowshown = $rownum;
	my $headcolor = "#CCCCFF";
	my $backcolor = "#EEF";
	my $buttoncolor = "#aac";
	$headcolor = convertColor(config('UI','headerbg') or $headcolor) if $titletype eq 'head';
	$backcolor = convertColor(config('UI','listbg') or $backcolor);
	$buttoncolor = convertColor(config('UI','buttonbg') or $buttoncolor);
	# each item in hash is a hash
	my @rows;
	my $needrows = scalar @keys + $rownum;
	my $bodyfont = (defined config('Font','body') ? 1 : 0);
	my $updater;
#	if ($bodyfont) { applyFont($target,0); }
	unless ((config('DB','conserve') or '') eq 'net') {
		$updater = FlexSQL::getDB();
	} else {
		warn "Conserving net traffic is not yet supported"; $updater = PomallSQL::getDB();
	}
	foreach my $k (@keys) { # loop over list
		$rownum++; $rowshown++;
##		print "Building row for title $k...\n";
		my %record = %{$$tlist{$k}};
		if ($titletype eq 'head') {
			if ($numbered) {
				my $nolabel = $target->place_in_table(0,0, Label => text => "#");
#				if ($bodyfont) { applyFont($nolabel,0); }
				$nolabel->backColor($headcolor);
				$rownum--;
			}
		} else {
			my $nolabel = $target->place_in_table($rownum,0, Label => text => ($numbered ? "$rowshown" : ""));
#			if ($bodyfont) { applyFont($nolabel,0); }
		}
		my $title = $target->place_in_table($rownum,0 +$numbered, Label => text => Common::shorten($record{title},30)); # put in the title of the series
#		$title->set_alignment(0.0,0.1);
#		if ($bodyfont) { applyFont($title,0); }
		if ($titletype eq 'head') {
			$title->backColor($headcolor);
			$title->place( fill => 'x');
		}
		if ($titletype eq 'head') {
			my $cb = $target->place_in_table($rownum,1 + $numbered, Label => text => "", place => { fill => 'none', expand => 0, }, );
			$cb->backColor($headcolor);
		} else {
			my $rbox = $target->place_in_table($rownum,1 + $numbered, HBox => backColor => $backcolor, place => { expand => 0, fill => 'x', }, );
			my $rew = $rbox->insert(Label => text => ($record{status} == 3 ? " (Re" . ($titletype eq 'series' ? "watch" : "read" ) . "ing) " : "---")); # put in the rewatching status
			$rbox->arrange();
#			if ($bodyfont) { applyFont($rew,0); }
			unless ($record{status} == 4) { # No move button for completed page
				my $status = $record{status};
				$rbox->insert( Label =>
					text => "m",
					backColor => $buttoncolor,
#					pack => { fill => 'none', expand => 0, side => "top", },
#					onClick => sub { chooseStatus($rew,\$status,$k,$titletype); },
		# put in button(s) for moving to another status? TODO later
				);
			} # but there might some day be a "Rewatch this show" button here
		}
		if ($titletype eq 'head') {
			my $plabel = $target->place_in_table($rownum,2 + $numbered, Label => text => "Progress");
#			if ($bodyfont) { applyFont($plabel,0); }
			$plabel->backColor($headcolor);
		} else {
			my $updateform = ($titletype eq "series" ? ($record{status} == 3 ? 1 : 0 ) : ($record{status} == 3 ? 3 : 2 ) );
			my $pvbox = $target->place_in_table($rownum,2 + $numbered, VBox => backColor => $backcolor);
			my $pchabox = $pvbox->insert(HBox => backColor => $backcolor);
		# put in the number of watched/episodes (button) -- or chapters
			my $pprog = ($record{status} == 4 ? "" : ($titletype eq 'series' ? ($record{status} == 3 ? "$record{lastrewatched}" : "$record{lastwatched}" ) : ($record{status} == 3 ? "$record{lastreread}" : "$record{lastreadc}" )) . "/") . ($titletype eq 'series' ? "$record{episodes}" : "$record{chapters}" );
			my $pbut = $pchabox->insert( Label =>
				text => $pprog
#				onClick => sub { askPortion($pvbox,$updateform,$k,$updater);},
			);
#			applyFont($pbut,2);
		# link the button to a dialog asking for a new value
		# put in a label giving the % completed (using watch or rewatched episodes)
			my $rawperc = ($titletype eq 'series' ? ($record{status} == 3 ? $record{lastrewatched} : $record{lastwatched} ) : ($record{status} == 3 ? $record{lastreread} : $record{lastreadc} )) / (($titletype eq 'series' ? $record{episodes} : $record{chapters} ) or 100) * 100;
		# read config option and display percentage as either a label or a progress bar
			if (config('UI','graphicprogress')) {
				my $percb = $pvbox->insert( Gauge => size => [100,24], value => $rawperc);
### TODO: figure out how to resize this widget
#				applyFont($percb,2);
			} else {
				my $pertxt = sprintf("%.2f%%",$rawperc);
				my $percl = $pvbox->insert( Label => text => $pertxt);
#				applyFont($percl,2);
			}
		# put in a button to increment the number of episodes or chapters (using watch or rewatched episodes)
			unless ($record{status} == 4) {
				my $font = FontRow::stringToFont(config('Font','progress') or "");
				my $incbut = $pchabox->insert( SpeedButton =>
					text => "+",
					backColor => $buttoncolor,
					font => $font,
					autoHeight => 1,
					autowidth => 1,
					minSize => [10,10],
					pack => { fill => "none", expand => 0, },
#					onClick => sub { incrementPortion($pvbox,$updateform,$k,$updater); },
				);
#				applyFont($incbut,2);
			}
		# if manga, put in the number of read/volumes (button)
			if ($titletype eq 'pub') {
				my $pvolbox = $pvbox->insert(HBox => backColor => $backcolor);
				# put in the number of watched/episodes (button) -- or chapters
				my $vbut = $pvolbox->insert( Label =>
					text => "$record{lastreadv}/$record{volumes}"
#					onClick => sub { askPortion($pvbox,$upform,$k,$updater); },
				);
#				applyFont($vbut,2);
				# link the button to a dialog asking for a new value
				my $upform = ($record{status} == 3 ? 5 : 4 );
				# put in a button to increment the number of volumes (using read or reread volumes)
				unless ($record{status} == 4) {
					my $font = FontRow::stringToFont(config('Font','progress') or "");
					my $incvbut = $pvolbox->insert( SpeedButton =>
						text => "+",
						backColor => $buttoncolor,
						font => $font,
						minSize => [10,10],
						pack => { fill => "none", expand => 0, },
#						onClick => sub { incrementPortion($pvbox,$upform,$k,$updater) },
					);
#					applyFont($incvbut,2);
				}
			}
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
		} else {
#			my $tags = Gtk2::Button->new("Show/Edit tags"); # put in the tag list (button?)
## use $k for callback; it should contain the series/pub id #.
#			$tags->show();
#			$target->attach($tags,4,5,$rownum,$rownum+1,qw( shrink ),qw( shrink),1,0);
		}
		if ($titletype eq 'head') {
			my $score = $target->place_in_table($rownum,3 + $numbered, Label =>
				text => $record{score},
				backColor => convertColor($headcolor),
			);
#			if ($bodyfont) { applyFont($score,0); }
		} else {
			my $score = $target->place_in_table($rownum,3 + $numbered, SpeedButton =>
				text => sprintf("%.1f",$record{score} / 10), # put in the score
#				onClick => sub { scoreSlider($k,$titletype,$updater) },
			);
		}
		# put in a button to edit the title/list its volumes/episodes
	} # end foreach my $k (@keys)
#	return @rows;
}
print ".";

sub convertColor {
	my ($color,$force) = @_;
	return undef unless (defined $color); # undef if no color given
	return $color unless ($force or $color =~ m/^#/); # return color unchanged unless it starts with '#' (allows passing integer straight through, as saveConf is going to write it as int, but we want user to be able to write it as #ccf).
	return ColorRow::stringToColor($color); # convert e.g. "#ccf" to integer needed by Prima
}
print ".";

sub createSplash {
	my $window = shift;
	my $vb = $window->insert( VBox => name => "splashbox", pack => { anchor => "n", fill => 'x', expand => 0, relx => 0.5, rely => 0.5, padx => 5, pady => 5, }, );
	my $label = $vb->insert( Label => text => "Loading POMAL...", pack => { fill=> "x", expand => 0, side => "left", relx => 0.5, padx => 5, pady => 5,},);
	my $progress = $vb->insert( Gauge =>
		value => 0,	
		relief => gr::Raise,
		height => 35,
		pack => { fill => 'x', expand => 0, padx => 3, side => "left", },
	);
	return $progress,$vb;
}
print ".";

sub fillPage {
	my ($dbh,$index,$typ,$gui) = @_;
	unless (defined $$gui{tabbar}) { Pdie("fillPage couldn't find tab bar!"); }
	my $rowtyp = "???";
	my $sortkey = 'title';
	my ($target,$snote,%pages);
	my %exargs;

#	$exargs{limit} = 5;

	my %statuses = Sui::getStatHash($typ);
	my $labeltexts;
	for ($typ) {
		if (/ani/) { $rowtyp = "series"; }
		elsif (/man/) { $rowtyp = "pub"; }
		elsif (/mov/) { $rowtyp = "series"; $exargs{max} = 1; }
		elsif (/sam/) { $rowtyp = "pub"; $exargs{max} = 1; }
		elsif (/sug/) { warn "Suggestions are not yet supported"; return; }
		elsif (/rec/) { warn "Recent activity is not yet supported"; return; }
		else { warn "Something unexpected happened"; return; }
	}
	$$gui{status}->text("Loading titles...");
	my $page = 0;
	foreach (Sui::getStatOrder()) { # specific order
		push(@$labeltexts,$statuses{$_});
		$pages{$_} = $page++;
	}
	unless (config('UI','statustabs') or 0) { # single box
		$$gui{status}->text("Placing titles in box...");
		$snote = $$gui{tabbar}->insert_to_page($index, ScrollWidget => name => "$typ" );
	} else {
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
	}
#	$snote->hide();
	my @cumulativestats = (0,0,0,0,0);
	my @cumulativescores;
	my $watched = ($rowtyp eq 'pub' ? "Chapters read" : "Episodes watched");
	foreach (Sui::getStatOrder()) {
		my $typestring = ($rowtyp eq 'pub' ? (config('Custom','man') or "Manga") : (config('Custom','ani') or "Anime"));
		my $status = $statuses{$_};
		$$gui{status}->text("Placing titles in tabs ($typestring/$status)...");
		$::application->yield();
		$page = $pages{$_};
		if (config('UI','statustabs') or 0) {
			$target = $snote->insert_to_page($page, VBox => name => "$typ$_", pack => { fill => 'both', expand => 1, }, );
		} else {
			$target = $snote->insert( VBox => name => "$typ$_", pack => { fill => 'both', expand => 1, }, );
		}
#		$target->enabled(0);
		# %exargs allows limit by parameters (e.g., at least 2 episodes (not a movie), at most 1 episode (movie))
		# $exargs{maxparts} = 1
		# getTitlesByStatus will put Watching (1) and Rewatching (3) together unless passed "rew" as type.
		my $h = Sui::getTitlesByStatus($dbh,$rowtyp,$_,%exargs);
		my @keys = Common::indexOrder($h,$sortkey);
		# make a label
		my $label = $target->insert( Label => text => $$labeltexts[$page], pack => { fill => 'y', expand => 0, side => "left", padx => 5, },);
		applyFont('label',$label);
#		applyFont('label',$labels{$_});
##		print "Looking for " . $typ . "/" . $_ . "...";
		my $table = $target->insert( VBox =>
			name => $$labeltexts[$page],
			backColor => (convertColor(config('UI','listbg') or "#eef")), pack => { fill => 'both', expand => 1, side => "left", padx => 5, pady => 5, }, );
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
		buildTitleRows($rowtyp,$table,$h,0,@keys);
		if (FIO::config('Table','statsummary')) { # put in a label/box of labels with statistics (how many titles, total episodes watched, mean score, etc.)
			# compile statistics from @a
			my @tablestats = (0,0,0,0,0);
			my @scorelist;
			foreach (values %$h) {
				push(@scorelist,$$_{score}) unless $$_{score} == 0;
				$tablestats[0]++;
				$tablestats[1] += 1 unless $$_{score} == 0;
				$tablestats[2] += $$_{score};
				$tablestats[3] += ($$_{status} == 4 ? ($rowtyp eq 'series' ? $$_{episodes} : $$_{chapters} ) : ($rowtyp eq 'series' ? ($$_{status} == 3 ? $$_{lastrewatched} : $$_{lastwatched} ) : ($$_{status} == 3 ? $$_{lastreread} : $$_{lastreadc} )));
# @cumulativestats = [count,scorecount,scoresum,progress,medianscore]
			}
			$::application->yield();
			$tablestats[1]++ unless $tablestats[1]; # prevent divide by zero
			my $statline = (FIO::config('Table','withmedian') ? withMedian(\@tablestats,$watched,@scorelist) : withoutMedian(\@tablestats,$watched,@scorelist));
			if (config('UI','statustabs') or 0) {
				$snote->insert_to_page($page, Label => text => $statline, pack => { fill => 'x', expand => 0,}, );
			} else {
				$snote->insert( Label => text => $statline, pack => { fill => 'x', expand => 0,}, );
			}
			push(@cumulativescores,@scorelist);
			$cumulativestats[0] += $tablestats[0];
			$cumulativestats[1] += $tablestats[1];
			$cumulativestats[2] += $tablestats[2];
			$cumulativestats[3] += $tablestats[3];
		}
	}
	$::application->yield();
	if (FIO::config('Table','statsummary')) {
		$cumulativestats[1]++ unless $cumulativestats[1]; # prevent divide by zero
		my $statline = (FIO::config('Table','withmedian') ? withMedian(\@cumulativestats,$watched,@cumulativescores) : withoutMedian(\@cumulativestats,$watched,@cumulativescores));
		$$gui{tabbar}->insert_to_page($index, Label => text => $statline, pack => { fill => 'x', expand => 0,}, );
	}
#	$target->enabled(1);
#	$snote->show();
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
	my $code = shift;
	my $tabs = (getGUI("tablist") or []);
	return Common::findIn($code,@$tabs);
}
print ".";

sub importGUI {
	use Import qw( importXML );
	my $gui = PGK::getGUI();
	my $dbh = FlexSQL::getDB();
	### Later, put selection here for type of import to make
	# For now, just allowing import of MAL XML file
	PGK::refreshUI($gui,$dbh) unless(Import::importXML($dbh,$gui));
}
print ".";

sub loadDBwithSplashDetail {
	my $gui = shift;
	my ($prog,$box) = createSplash($$gui{mainWin});
	my $text = $$gui{status};
	# do stuff using this window...
	my $pulse = 0;
	my $steps = 4;
	my $step = 0;
	my $base = "";
	$text->text("Loading database config...");
	$prog->value(++$step/$steps*100);
	my $curstep = $box->insert( Label => text => "");
	unless (defined config('DB','type')) {
		$steps ++; # number of steps in type dialogue
		my $dbtype = undef;
		$text->text("Getting settings from user...");
		$prog->value(++$step/$steps*100); # 0 (matches else)
		my $result = message("Choose database type:",mb::Cancel | mb::Yes | mb::No,
			buttons => {
					mb::Yes, {
						text => "MySQL", hint => "Use if you have a MySQL database.",
					},
					mb::No, {
						text => "SQLite", hint => "Use if you can't use MySQL.",
					},
					mb::Cancel, {
						text => "Quit", hint => "Abort loading the program (until you set up your database?)",
					},
			}
		);
		if ($result == mb::Yes) {
			$dbtype = 'M';
		} elsif ($result == mb::No) {
			$dbtype = 'L';
		} else {
			print "Exiting (abort).\n";
			$$gui{mainWin}->close();
		}
		$text->text("Saving database type...");
		$prog->value(++$step/$steps*100);
		# push DB type back to config, as well as all other DB information, if applicable.
		config('DB','type',$dbtype);
		$base = $dbtype;
	} else {
		$curstep->text("Using configured database type.");
		$prog->value(++$step/$steps*100);
		$base = config('DB','type');
	}
	unless (defined config('DB','host')) {
		$steps ++; # host
		# unless type is SQLite:
		unless ($base eq 'L') {
			$steps ++; # type dialogue
			$curstep->text("Enter database login info");
			$text->text("Getting login credentials...");
			$prog->value(++$step/$steps*100); # 0
		# ask user for host
			my $host = input_box("Server Info","Server address:","127.0.0.1");
		# ask user for SQL username, if needed by server (might not be, for localhost)
			my $uname = input_box("Login Credentials","Username (if required)","");
		# ask user if username required
			my $umand = (message("Username required?",mb::YesNo) == mb::Yes ? 'y' : 'n');
		# ask user if password required
			my $pmand = (message("Password required?",mb::YesNo) == mb::Yes ? 'y' : 'n');
			$curstep->text("---");
			# save data from entry boxes...
			$text->text("Saving server info...");
			$prog->value(++$step/$steps*100); # 1
			$uname = ($umand ? $uname : undef);
			config('DB','host',$host); config('DB','user',$uname); config('DB','password',$pmand);
		} else {
			$text->text("Using file as database...");
			config('DB','host','localfile'); # to prevent going through this branch every time
			$prog->value(++$step/$steps*100); # 0a
		}
		FIO::saveConf();
	}
	my ($uname,$host,$pw) = (config('DB','user',undef),config('DB','host',undef),config('DB','password',undef));
	# ask for password, if needed.
	my $passwd = ($pw =~ /[Yy]/ ? input_box("Login Credentials","Enter password for $uname\@$host:") : '');
	$curstep->text("Establish database connection.");
	$text->text("Connecting to database...");
	$prog->value(++$step/$steps*100);
	my ($dbh,$error) = FlexSQL::getDB($base,$host,'pomal',$passwd,$uname);
	if ($error =~ m/Unknown database/) { # rudimentary detection of first run
		$steps++;
		$curstep->text("Database not found. Attempting to initialize...");
		$text->text("Attempting to initialize database...");
		$prog->value(++$step/$steps*100);
		($dbh,$error) = FlexSQL::makeDB($base,$host,'pomal',$passwd,$uname);
	}
	unless (defined $dbh) { # error handling
		Pdie("ERROR: $error");
		print "Exiting (no DB).\n";
	} else {
		$curstep->text("---");
		$text->text("Connected.");
	}
	unless (FlexSQL::table_exists($dbh,'tags')) {
		$steps++;
		$prog->value(++$step/$steps*100);
		$text->text("Attempting to initialize database tables...");
		FlexSQL::makeTables($dbh);
	}
	$text->text("Done loading database.");
	$prog->value(++$step/$steps*100);
	if (0) { print "Splash screen steps: $step/$steps\n"; }
	$box->close();
	return $dbh;
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
	$$gui{questionparent} = $$gui{mainWin}->insert( VBox => name => 'qparent', place => { fill => 'both', expand => 0, relx => 0, rely => 1, anchor => 'nw', relwidth => 1, relheight => 0.9, } );
	my $waiter = $$gui{mainWin}->insert( Label => text => "Building display.\nPlease wait...", pack => { fill => 'x', expand => 1, }, valign => ta::Center, alignment => ta::Center, font => applyFont('bighead'), autoHeight => 1, );
	$::application->yield();
	my $note = Prima::TabbedNotebook->create(
		owner => getGUI('mainWin'),
		style => tns::Simple,
		tabs => \@tabtexts,
		name => 'SeriesTypes',
		tabsetProfile => {colored => 0, %exargs, },
		pack => { fill => 'both', expand => 1, pady => 3, side => "left", },
	);
	$$gui{tabbar} = $note; # store for additional tabs
	$$gui{tablist} = \@tabs;
	$note->hide();
	foreach (0..$#tabs) {
		fillPage($dbh,$_,$tabs[$_],$gui);
	}
	$note->pageIndex(0);
	$note->show();
	$waiter->destroy();
	$$gui{status}->text("Ready.");
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
		applyFont('body',$title);
		if ($titletype eq 'head') {
			$title->backColor($headcolor);
		}
		if ($titletype eq 'head') {
			my $cb = $row->insert( Label => text => "", pack => { fill => 'none', expand => 0, }, );
			$cb->sizeMin($widths[1],$cb->height) if (defined $widths[1] and $widths[1] > 0);
			$cb->backColor($headcolor);
		} else {
			my $rbox = $row->insert( HBox => backColor => $backcolor, pack => { fill => 'none', expand => 0, }, );
			my $rew = $rbox->insert(Label => text => ($record{status} == 3 ? " (Re" . ($titletype eq 'series' ? "watch" : "read" ) . "ing) " : "   ")); # put in the rewatching status
			$rbox->arrange();
#			applyFont('body',$rew);
			unless ($record{status} == 4) { # No move button for completed page
				my $status = $record{status};
				$rbox->insert( Label =>
					text => "m",
					backColor => $buttoncolor,
#					onClick => sub { chooseStatus($rew,\$status,$k,$titletype); },
		# put in button(s) for moving to another status? TODO later
				);
			} # but there might some day be a "Rewatch this show" button here
			$rbox->sizeMin($widths[1],$rbox->height) if (defined $widths[1] and $widths[1] > 0);
		}
		if ($titletype eq 'head') {
			my $plabel = $row->insert( Label => text => "Progress");
			$plabel->sizeMin($widths[2],$plabel->height) if (defined $widths[2] and $widths[2] > 0);
			applyFont('body',$plabel);
			$plabel->backColor($headcolor);
		} else {
			my $updateform = ($titletype eq "series" ? ($record{status} == 3 ? 1 : 0 ) : ($record{status} == 3 ? 3 : 2 ) );
			my $pvbox = $row->insert( VBox => backColor => $backcolor);
			my $pchabox = $pvbox->insert( HBox => backColor => $backcolor);
		# put in the number of watched/episodes (button) -- or chapters
			my $pprog = ($record{status} == 4 ? "" : ($titletype eq 'series' ? ($record{status} == 3 ? "$record{lastrewatched}" : "$record{lastwatched}" ) : ($record{status} == 3 ? "$record{lastreread}" : "$record{lastreadc}" )) . "/") . ($titletype eq 'series' ? "$record{episodes}" : "$record{chapters}" );
			my $pbut = $pchabox->insert( Label =>
				text => $pprog,
				pack => { expand => 1, fill => 'both', },
					# link the button to a dialog asking for a new value
#				onClick => sub { askPortion($pvbox,$updateform,$k,$updater);},
			);
			applyFont('button',$pbut);
			# put in a label giving the % completed (using watch or rewatched episodes)
			my $rawperc = ($titletype eq 'series' ? ($record{status} == 3 ? $record{lastrewatched} : $record{lastwatched} ) : ($record{status} == 3 ? $record{lastreread} : $record{lastreadc} )) / (($titletype eq 'series' ? $record{episodes} : $record{chapters} ) or 100) * 100;
			# read config option and display percentage as either a label or a progress bar
			if (config('UI','graphicprogress')) {
				my $percb = $pvbox->insert( Gauge => size => [100,24], value => $rawperc, pack => { expand => 0, fill => 'none', },);
				applyFont('progress',$percb);
			} else {
				my $pertxt = sprintf("%.2f%%",$rawperc);
				my $percl = $pvbox->insert( Label => text => $pertxt);
				applyFont('progress',$percl);
			}
			# put in a button to increment the number of episodes or chapters (using watch or rewatched episodes)
			unless ($record{status} == 4) {
				my $incbut = $pchabox->insert( SpeedButton =>
					text => "+",
					backColor => $buttoncolor,
					font => applyFont('progbut'),
					autoHeight => 1,
					autowidth => 1,
					minSize => [10,10],
					pack => { fill => "none", expand => 0, },
#					onClick => sub { incrementPortion($pvbox,$updateform,$k,$updater); },
				);
			}
			# if manga, put in the number of read/volumes (button)
			if ($titletype eq 'pub') {
				my $pvolbox = $pvbox->insert(HBox => backColor => $backcolor);
				# put in the number of watched/episodes (button) -- or chapters
				my $vbut = $pvolbox->insert( Label =>
					text => "$record{lastreadv}/$record{volumes}"
#					onClick => sub { askPortion($pvbox,$upform,$k,$updater); },
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
#						onClick => sub { incrementPortion($pvbox,$upform,$k,$updater) },
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
				text => sprintf("%.1f",$record{score} / 10), # put in the score
				font => applyFont('button'),
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
	my $dbh = FlexSQL::getDB();
	unless ($tab eq 'man' or $tab eq 'ani') { print "[E] addTitle does not recognize '$tab' as a valid option.\n"; return; }
	my $box = $$gui{questionparent};
	$$gui{tabbar}->hide();
	$box->empty();
	my $tabstr = ($tab eq 'man' ? ' manga' : 'n anime');
	$box->insert( Label => text => "Add a$tabstr title", font => applyFont('bighead'), autoheight => 1, pack => { fill => 'x', expand => 1,}, autoHeight => 1, alignment => ta::Center, );
	my $titlestat = $box->insert( XButtons => name => "status", pack => {fill=>'none',expand=>0});
	$titlestat->arrange('left');
	my @presets = (0,Sui::getStatHash($tab),'rew',"Rewatching");
	$titlestat-> build("Status:",@presets);
	my $row0 = $box->insert( HBox => name => 'row0');
	$row0->insert( Label => text => "Title", sizeMin => [150,20]);
	$row0->insert( Label => text => "Episodes", sizeMin => [100,20]);
	$row0->insert( Label => text => "Watched", sizeMin => [100,20]);
	$row0->insert( Label => text => "Started", sizeMin => [100,20]);
	$row0->insert( Label => text => "Ended", sizeMin => [100,20]);
	my $row1 = $box->insert( HBox => name => 'row1');
	my $name = $row1->insert( InputLine =>
		text => "", name => 'sname', sizeMin => [150,20]);
	my $episodes = $row1->insert( SpinEdit => value => 0, min => 0, max => $partmax, step => 1, pageStep => 10, sizeMin => [100,20]);
	my $lastwatched = $row1->insert( SpinEdit => value => 0, min => 0, max => $partmax, step => 1, pageStep => 10, sizeMin => [100,20]);
#	my $lastrewatched
	my $started = $row1->insert( InputLine => text => '0000-00-00', sizeMin => [100,20]);
	my $ended = $row1->insert( InputLine => text => '0000-00-00',sizeMin => [100,20]);
	my $row2 = $box->insert( HBox => name => 'row2');
	$row2->insert( Label => text => "Score", sizeMin => [100,20]);
	$row2->insert( Label => text => "Seen", sizeMin => [100,20]);
	my $row3 = $box->insert( HBox => name => 'row3');
	my $score = $row3->insert( InputLine => text => '0', sizeMin => [100,20]);
# seentimes should be enabled only if rewatching or completed.
	my $seentimes = $row3->insert( SpinEdit => value => 0, min => 0, max => 100, step => 1, pageStep => 5, sizeMin => [100,20], enabled => 0, );
$titlestat->onChange(sub { unless ($titlestat->value eq 'com' or $titlestat->value eq 'rew') { $seentimes->enabled(0); $seentimes->value(0); } else { $seentimes->enabled(1); } });
	#my $content;
	#my $rating;
	my $note;
	my $stype; # TV, ONA, etc.


	$box->insert( Button => text => "Cancel", onClick => sub { $box->empty(); $$gui{tabbar}->show(); $$gui{status}->text("Title addition cancelled."); });
#	onClick => sub {
		# hashify
		# prepare
		# submit
#		$$gui{tabbar}->show();
		# display
#		$box->empty();
#	}
}
print ".";

print " OK; ";

1;
