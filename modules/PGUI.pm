# Graphic User Interface module
use strict; use warnings;
package PGUI;
print __PACKAGE__;

use Prima qw(Application Buttons MsgBox FrameSet StdDlg Sliders Notebooks ScrollWidget);
$::wantUnicodeInput = 1;

use GK qw( VBox Table );

use FIO qw( config );

sub Pdie {
	my $message = shift;
	my $w = getGUI('mainWin');
	message_box("Fatal Error",$message,mb::Yes | mb::Error);
	$w->close();
	exit(-1);
}

sub Pwait {
	# Placeholder for if I ever figure out how to do a non-blocking sleep function in Prima
}

sub buildMenus { #Replaces Gtk2::Menu, Gtk2::MenuBar, Gtk2::MenuItem
	my $self = shift;
	my $menus = [
		[ '~File' => [
			['~Import', 'Ctrl-O', '^O', sub { importGUI() } ],
			['~Export', sub { message('export!') }],
#			['~Synchronize', 'Ctrl-S', '^S', sub { message('synch!') }],
#			['~Preferences', \&callOptBox],
			[],
			['Close', 'Ctrl-W', km::Ctrl | ord('W'), sub { $self->close() } ],
		]],
		[ '~Help' => [
			['~About',sub { message('About!') }], #\&aboutBox],
		]],
	];
	return $menus;
}
print ".";

sub buildTitleRows {
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
		$updater = PomalSQL::getDB();
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
				my $incbut = $pchabox->insert( Button =>
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
					my $incvbut = $pvolbox->insert( Button =>
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
			my $score = $target->place_in_table($rownum,3 + $numbered, Button =>
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

my %windowset;

sub createMainWin {
	my ($version,$w,$h) = @_;
	my $window = Prima::MainWindow->new(
		text => (config('Custom','program') or "PersonalOfflineManga/AnimeList") . " v.$version",
		size => [($w or 750),($h or 550)],
	);
	if (config('Main','savepos')) {
		unless ($w and $h) { $w = config('Main','width'); $h = config('Main','height'); }
		$window->size($w,$h);
		$window->place( x => (config('Main','left') or 40), rely => 1, y=> -(config('Main','top') or 30), anchor => "nw");
	}
# This line does nothing apparent:
#	if (defined config('Font','body')) { applyFont($window,0); }
	$window->set( menuItems => buildMenus($window));

	#pack it all into the hash for main program use
	$windowset{mainWin} = $window;
	$windowset{status} = getStatus($window);
	return \%windowset;
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

	$exargs{limit} = 5;

	my %statuses = Common::getStatHash($typ);
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
#	applyFont($label,1);
	$$gui{status}->text("Loading titles...");
	my $page = 0;
	foreach (Common::getStatOrder()) { # specific order
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
			pack => { fill => 'both', expand => 1, pady => 3, side => "left", },
		);
	}
	
	foreach (Common::getStatOrder()) {
		$page = $pages{$_};
		if (config('UI','statustabs') or 0) {
			$target = $snote->insert_to_page($page, VBox => name => "$typ$_", pack => { fill => 'both', expand => 1, }, );
		} else {
			$target = $snote->insert( VBox => name => "$typ$_", pack => { fill => 'both', expand => 1, }, );
		}
		# %exargs allows limit by parameters (e.g., at least 2 episodes (not a movie), at most 1 episode (movie))
		# $exargs{maxparts} = 1
		# getTitlesByStatus will put Watching (1) and Rewatching (3) together unless passed "rew" as type.
		my $h = PomalSQL::getTitlesByStatus($dbh,$rowtyp,$_,%exargs);
		my @keys = Common::indexOrder($h,$sortkey);
		# make a label
		my $label = $target->insert( Label => text => $$labeltexts[$page], pack => { fill => 'y', expand => 0, side => "left", padx => 5, },);
#		applyFont($labels{$_},1);
##		print "Looking for " . $typ . $_ . "...";
		my $table = $target->insert( Table =>
			backColor => (convertColor(config('UI','listbg') or "#eef")), pack => { fill => 'both', expand => 1, side => "left", padx => 5, pady => 5, }, );
		$table->expand_width(1);
# 		$table->separator(config('UI','rulesep') or 0);
		$table->remainder_column(config("UI",'linenos') ? 1 : 0); # which column is the title (dynamic sizing)
# config('UI','rulesep')
###	TODO: push table to $gui's list of tables
		my $tlist = { 'h' => {
			title => "Title",
			status => 0,
			score => "Score",
			sid => "?"
		}};
		buildTitleRows("head",$table,$tlist,0,'h');
		# fill the box with titles
		buildTitleRows($rowtyp,$table,$h,0,@keys);
		$table->adjust_rows_all(1); # A full adjustment is recommended after table has been populated.
		# compile statistics from @a
		# put in a label/box of labels with statistics (how many titles, total episodes watched, mean score, etc.)
	}
}
print ".";

sub getGUI {
	unless (defined keys %windowset) { createMainWin(); }
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

sub getTabByCode { # for definitively finding page ID of recent, suggested tabs...
	my $code = shift;
	my $tabs = (getGUI("tablist") or []);
	return Common::findIn($code,@$tabs);
}
print ".";

sub importGUI {
	use Import qw( importXML );
	my $gui = getGUI();
	my $dbh = PomalSQL::getDB();
	### Later, put selection here for type of import to make
	# For now, just allowing import of MAL XML file
	return Import::importXML($dbh,$gui);
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
	my ($dbh,$error) = PomalSQL::getDB($base,$host,'pomal',$passwd,$uname);
	if ($error =~ m/Unknown database/) { # rudimentary detection of first run
		$steps++;
		$curstep->text("Database not found. Attempting to initialize...");
		$text->text("Attempting to initialize database...");
		$prog->value(++$step/$steps*100);
		($dbh,$error) = PomalSQL::makeDB($base,$host,'pomal',$passwd,$uname);
	}
	unless (defined $dbh) { # error handling
		Pdie("ERROR: $error");
		print "Exiting (no DB).\n";
	} else {
		$curstep->text("---");
		$text->text("Connected.");
	}
	unless (PomalSQL::table_exists($dbh,'tags')) {
		$steps++;
		$prog->value(++$step/$steps*100);
		$text->text("Attempting to initialize database tables...");
		PomalSQL::makeTables($dbh);
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
	my $note = Prima::TabbedNotebook->create(
		owner => getGUI("mainWin"),
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
	$$gui{status}->text("Ready.");
}
print ".";

sub sayBox {
	my ($parent,$text) = @_;
	message($text,owner=>$parent);
}
print ".";

print " OK; ";
1;
