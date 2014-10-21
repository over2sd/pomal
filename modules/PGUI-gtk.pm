# Graphic User Interface module
package PGUI-gtk;
print __PACKAGE__;

use Gtk2 -init; # requires GTK perl bindings

use FIO qw( config );

sub Gtkdie {
	my $win = shift;
	if ($win) { $win->destroy(); }
	my $text = shift;
	my $text = ( defined $text ? ": $text" : "" );
	print "Exit$text\n";
	PomalSQL::closeDB();
	Gtk2->main_quit;
	exit(shift or 0);
}
print ".";

sub Gtkwait {
	my $duration = shift or 1;
	my $start = time();
	my $end = ($start+$duration);
	while ($end > time()) {
		while (Gtk2->events_pending()) {
			Gtk2->main_iteration();
		}
		# 10ms sleep.
		# Not much, but prevents processor spin without making waiting dialogs unresponsive.
		select(undef,undef,undef,0.01);
	}
	return 0;
}
print ".";

sub createSplash {
	my $window = Gtk2::Window->new();
	$window->set_default_size(300,100);
	$window->set_gravity('south-west');
	$window->move(int((Gtk2::Gdk->screen_width()/2) - 150),int((Gtk2::Gdk->screen_height()/2) + 50));
	$window->set_decorated(0);
	$window->set_double_buffered(0);
	my $title = Gtk2::Label->new("POMAL");
	my $vb = Gtk2::VBox->new();
	my $progress = Gtk2::ProgressBar->new();
	my $splashdetail = Gtk2::Statusbar->new();
	$window->add($vb);
	$vb->pack_start($title,1,1,2);
	$vb->pack_end($splashdetail,0,0,2);
	$vb->pack_end($progress,0,0,2);
	$window->show_all();
	return $window,$splashdetail,$progress,$vb;
}
print ".";

my %windowset;
sub getGUI {
	unless (defined keys %windowset) { createMainWin(); }
	my $key = shift;
	if (defined $key) {
		if (exists $windowset{$key}) {
			return $windowset{$key};
		} elsif ($key eq "tables") {
			my $tables = {};
			foreach (qw/ ani man /) {
				foreach my $stat (qw/ wat ptw onh com drp /) {
#					print "Making table " . $_ . $stat . ".\n";
					$$tables{$_.$stat} = Gtk2::Table->new(1,6,0);
				}
			}
			$windowset{$key} = $tables;
			return $tables;
		} else {
			return undef;
		}
	}
	return \%windowset;
}
print ".";

sub createMainWin {
	my ($version,$w,$h) = @_;
	my $window = Gtk2::Window->new();
	$window->set_title((config('Custom','program') or "PersonalOfflineManga/AnimeList") . " v.$version");
	$window->signal_connect ('destroy',\&Gtkdie,"window closed"); # not saving position/size
	if (config('Main','savepos')) {
		unless ($w and $h) { $w = config('Main','width'); $h = config('Main','height'); }
		$window->set_default_size($w,$h);
		$window->move((config('Main','left') or 40),(config('Main','top') or 30));
	}
# This line does nothing apparent:
#	if (defined config('Font','body')) { applyFont($window,0); }
	my $vbox = Gtk2::VBox->new();
	$window->add($vbox);
	my $ag = Gtk2::AccelGroup->new(); # create the hotkey group
	my $mb = buildMenus($window,$ag); # build the menus
	$windowset{accel} = $ag; # store the hotkey group
	$vbox->pack_start($mb,0,0,2);

	#pack it all into the hash for main program use
	$windowset{mainWin} = $window;
	$windowset{status} = getStatus();
	$vbox->pack_end($windowset{status},0,0,2);
	$windowset{menubar} = $mb;
	$windowset{vbox} = $vbox;
	$window->show_all();
	return \%windowset;
}
print ".";

my $status = undef;
sub getStatus {
	unless(defined $status) {
		$status = Gtk2::Statusbar->new();
	}
	return $status;
}
print ".";

my $menus = undef;
sub buildMenus {
	unless(defined $menus) {
		my ($mainwin,$ag) = @_;

		$menus = Gtk2::MenuBar->new();
#		File >
		my ($itemF,$f) = itemize("_File",$menus,$ag);
#		File > Save (Only active if user chooses Flatfile DB)
##		my $itemFS = itemize("_Save",$f);
#		accelerate($itemFS,"<Control>S",$ag);
#		$itemFS->signal_connect("activate",\&FIO::saveData);
#		File > Import
		my $itemFI = itemize("_Import",$f);
		$itemFI->signal_connect("activate",\&importGUI);
#		File > Export
##		my $itemFE = itemize("_Export",$f);
#		File > Synchronize
##		my $itemFO = itemize("Synchr_onize",$f);
#		File > Preferences
		my $itemFP = itemize("_Preferences",$f);
		$itemFP->signal_connect("activate",\&callOptBox);
#		File > Quit
		my $itemFQ = itemize("_Quit",$f);
#		accelerate($itemFQ,"<Control>Q",$ag);
		$itemFQ->signal_connect("activate",\&storeWindowExit,$mainwin);
#		Help >
		my ($itemH,$h) = itemize("_Help",$menus,$ag);
#		Help > About
		my $itemHA = itemize("_About",$h);
		$itemHA->signal_connect("activate",\&aboutBox,$mainwin);

	}
	return $menus;
}
print ".";

sub itemize { # menu item, that is...
	my ($label,$parent,$group) = @_;
	if (0) { print "itemize(@_)\n"; }
	my $a = Gtk2::MenuItem->new($label);
	my $b = undef;
	$a->show();
	$parent->append($a);
	if (defined $group) {
		$b = Gtk2::Menu->new();
		$b->set_accel_group($group);
		$b->show();
		$a->set_submenu($b);
		return $a,$b;
	}
	return $a;
}
print ".";

### Still haven't found how to properly do this. Followed the instructions I found, but nothing works.
sub accelerate {
	if (0) { print "accelerate(@_)\n"; }
	my ($a,$hotkey,$group) = @_;
	my ($k,$m) = Gtk2::Accelerator->parse($hotkey);
#	print "Accel $hotkey: $k,$m\n";
	$a->add_accelerator("activate",$group,$k,$m,[qw/visible/]);
}
print ".";

sub storeWindowExit {
	my ($caller,$window) = @_;
#	print "Called by $caller, I am ";
	my $s = 'Main';
	if (config($s,'savepos')) {
		print "Storing window position. ";
		my ($w,$h) = $window->get_size();
		my ($x,$y) = $window->get_position();
		config($s,'width',$w);
		config($s,'height',$h);
		config($s,'top',$y);
		config($s,'left',$x);
		FIO::saveConf();
	} else {
#		print "Not storing window position. ";
	}
	Gtkdie(undef,"normally");
}
print ".";

sub loadDBwithSplashDetail {
	my ($splash,$text,$prog,$box) = createSplash();
	# do stuff using this window...
	my $pulse = 0;
	my $steps = 4;
	my $step = 0;
	my $base = "";
	$text->push(0,"Loading database config...");
	$prog->set_fraction(++$step/$steps);
	$splash->present();
	my $curstep = Gtk2::Label->new();
	unless (defined config('DB','type')) {
		$steps ++; # number of steps in type dialogue
		my $dbtype = undef;
		$text->push(0,"Getting settings from user...");
		$prog->set_fraction(++$step/$steps); # 0 (matches else)
		$curstep->set_text("Choose database type (or Quit)");
		$curstep->show();
		$box->pack_start($curstep,0,0,2);
		# ask user for database type
		my $hb = Gtk2::HBox->new();
		$hb->show();
		$box->pack_start($hb,0,0,2);
			# buttons for choices
		my $but_m = Gtk2::Button->new("MySQL");
		my $but_l = Gtk2::Button->new("SQLite");
		my $but_q = Gtk2::Button->new("Quit");
		$but_m->show();
		$hb->pack_start($but_m,0,0,2);
		$but_l->show();
		$hb->pack_start($but_l,0,0,2);
		$but_q->show();
		$hb->pack_start($but_q,0,0,2);
			# tooltips for buttons
		$but_m->set_tooltip_text("Use if you have a MySQL database.");
		$but_l->set_tooltip_text("Use if you can't use MySQL.");
		$but_q->set_tooltip_text("Abort loading the program (until you set up your database?)");
			# signals for buttons
		$but_m->signal_connect("clicked",\&setKill,[$hb,\$dbtype,'M']);
		$but_l->signal_connect("clicked",\&setKill,[$hb,\$dbtype,'L']);
		$but_q->signal_connect("clicked", sub { $splash->destroy();
					print "Exiting (abort).\n";
					exit(-3);
				});
			# while loop to wait for user response
		$splash->present();
		until (defined $dbtype) {
			if ($pulse) { $prog->pulse(); }
			Gtkwait(0.03);
		}
		$text->push(0,"Saving database type...");
		$prog->set_fraction(++$step/$steps);
		# push DB type back to config, as well as all other DB information, if applicable.
		config('DB','type',$dbtype);
		$base = $dbtype;
	} else {
		$prog->set_fraction(++$step/$steps);
		$base = config('DB','type');
		$splash->present();
	}
	unless (defined config('DB','host')) {
		$steps ++; # host
		# unless type is SQLite:
		unless ($base eq 'L') {
			$steps ++; # type dialogue
			$curstep->set_text("Enter database login info");
			$text->push(0,"Getting login credentials...");
			$prog->set_fraction(++$step/$steps); # 0
			my $stop = 1;
			my $login = Gtk2::VBox->new();
			$box->pack_start($login,0,0,3);
			my $submit = Gtk2::Button->new("Submit");
		# ask user for host
			my $hl = Gtk2::Label->new("Server address:");
			my $ehost = Gtk2::Entry->new();
			$ehost->set_text("127.0.0.1");
			$ehost->signal_connect("activate",sub { $submit->clicked(); }); # press Enter clicks button
		# ask user for SQL username, if needed by server (might not be, for localhost)
			my $euname = Gtk2::Entry->new();
			$euname->signal_connect("activate",sub { $submit->clicked(); }); # press Enter clicks button
		# ask user if username required
			my $uml = Gtk2::Label->new("Username required?");
			my $umy = Gtk2::RadioButton->new_with_label(undef,"Yes");
			my $umn = Gtk2::RadioButton->new_with_label_from_widget($umy,"No");
			$umn->set_active(1);
			$umy->signal_connect("toggled",\&setVis,[$euname,1]);
			$umn->signal_connect("toggled",\&setVis,[$euname,0]);
			my $umb = Gtk2::HBox->new();
			$umb->pack_start($umn,0,0,1);
			$umb->pack_start($umy,0,0,1);
			$umb->pack_start($euname,1,0,2);
			$umb->show_all();
		# ask user if password required
			my $pass = Gtk2::Label->new("I'll ask on connect");
			my $pml = Gtk2::Label->new("Password required?");
			my $pmy = Gtk2::RadioButton->new_with_label(undef,"Yes");
			my $pmn = Gtk2::RadioButton->new_with_label_from_widget($pmy,"No");
			$pmn->set_active(1);
			$pmy->signal_connect("toggled",\&setVis,[$pass,1]);
			$pmn->signal_connect("toggled",\&setVis,[$pass,0]);
			my $pmb = Gtk2::HBox->new();
			$pmb->pack_start($pmn,0,0,1);
			$pmb->pack_start($pmy,0,0,1);
			$pmb->pack_start($pass,1,0,2);
			$pmb->show_all();
			$submit->signal_connect("clicked",sub { $stop = 0; });
		# wait for user responses
			$login->pack_start($hl,0,0,1);
			$login->pack_start($ehost,1,0,4);
			$login->pack_start($uml,0,0,1);
			$login->pack_start($umb,1,0,4);
			$login->pack_start($pml,0,0,1);
			$login->pack_start($pmb,1,0,4);
			$login->pack_start($submit,1,0,1);
			$login->show_all();
			$euname->hide(); # hide unless needed
			$pass->hide();
			$splash->present();
			while ($stop) {
				if ($pulse) { $prog->pulse(); }
				Gtkwait(0.03);
			}
			$curstep->set_text("---");
			# save data from entry boxes...
			$text->push(0,"Saving server info...");
			$prog->set_fraction(++$step/$steps); # 1
			$splash->present();
			my ($uname,$host,$passwd) = (($umy->get_active() ? $euname->get_text() : undef),$ehost->get_text(),($pmy->get_active() ? 1 : 0));
			config('DB','host',$host); config('DB','user',$uname); config('DB','password',$passwd);
			# destroy login form
			$login->destroy();
		} else {
			$text->push(0,"Using file as database...");
			config('DB','host','localfile'); # to prevent going through this branch every time
			$prog->set_fraction(++$step/$steps); # 0a
			$splash->present();
		}
		FIO::saveConf();
	}
	my ($uname,$host,$pw) = (config('DB','user',undef),config('DB','host',undef),config('DB','password',0));
	# ask for password, if needed.
	my $passwd = ($pw ? undef : askPass($box,$uname,$host));
	$text->push(0,"Connecting to database...");
	$prog->set_fraction(++$step/$steps);
	$splash->present();
	my ($dbh,$error) = PomalSQL::getDB($base,$host,'pomal',$passwd,$uname);
	if ($error =~ m/Unknown database/) { # rudimentary detection of first run
		$steps++;
		$text->push(0,"Attempting to initialize database...");
		$prog->set_fraction(++$step/$steps);
		$splash->present();
		($dbh,$error) = PomalSQL::makeDB($base,$host,'pomal',$passwd,$uname);
	}
	unless (defined $dbh) { # error handling
		sayBox($splash,$error);
		$splash->destroy();
		print "Exiting (no DB).\n";
		exit(-2);
	}
	unless (PomalSQL::table_exists($dbh,'tags')) {
		$steps++;
		$prog->set_fraction(++$step/$steps);
		$text->push(0,"Attempting to initialize database tables...");
		$splash->present();
		PomalSQL::makeTables($dbh);
	}
	$text->push(0,"Done.");
	$prog->set_fraction(++$step/$steps);
	$splash->present();
	Gtkwait(0.01); # draw screen
	$splash->destroy();
	if (0) { print "Splash screen steps: $step/$steps\n"; }
	return $dbh;
}
print ".";

sub askPass {
	my ($parent,$u,$h) = @_;
	my $pw = undef;
	my $stop = 1;
	# make box and label and entry and button
	my $vb = Gtk2::VBox->new();
	my $lab = Gtk2::Label->new("Enter password for $u\@$h:");
	my $pass = Gtk2::Entry->new();
	my $but = Gtk2::Button->new("Submit");
	$but->signal_connect("clicked",sub { $stop = 0; });
	$pass->set_visibility(0); # entry must be set to make stars for safe password
	$pass->signal_connect("activate",sub { $but->clicked(); }); # press Enter clicks button
	# put label and entry and button in box, and box in parent
	$vb->pack_start($lab,0,0,3);
	$vb->pack_start($pass,0,0,3);
	$vb->pack_start($but,0,0,3);
	$parent->pack_start($vb,1,1,2);
	$vb->show_all();
	while ($stop) {
		Gtkwait(0.1);
	}
	$pw = $pass->get_text(); # read pw from entry
	$vb->destroy(); # destroy box
	return $pw;
}
print ".";

sub setKill {
	my ($caller,$dataset) = @_;
	my ($victim,$scalarref,$value) = @$dataset;
	$$scalarref = $value;
	$victim->destroy();
}
print ".";

sub setVis {
	my ($caller,$dataset) = @_;
	my ($target,$vis) = @$dataset;
	($vis ? $target->show() : $target->hide());
}
print ".";

sub dieWithErrorbox {
	my ($caller,$text) = @_;
	# display an error box. When user has pressed OK, kill caller and exit.
	sayBox($caller,$text);
	$caller->destroy();
	Gtkdie(undef,$text,-2);
}
print ".";

sub sayBox {
	my ($parent,$text) = @_;
	my $askbox = Gtk2::MessageDialog->new($parent,[qw/modal destroy-with-parent/],'question','ok',sprintf $text);
	$askbox->set_markup($text);
	my ($width,$height) = $askbox->get_size();
#	$askbox->move(int((Gtk2::Gdk->screen_width()/2) - ($width/2)),int((Gtk2::Gdk->screen_height()/2) - ($height/2))); # to prevent pop-shift of window
	$askbox->show_all();
#	$askbox->move(int((Gtk2::Gdk->screen_width()/2) - ($width/2)),int((Gtk2::Gdk->screen_height()/2) - ($height/2))); # in case it didn't work before display
	$askbox->set_position('center');
	$askbox->run();
	$askbox->destroy();
	return 0;
}
print ".";

sub menuRepop {
	my $dbh = getDB();
	my $gui = getGUI();
	populateMainWin($dbh,$gui,1);
}
print ".";

sub populateMainWin {
	my ($dbh,$gui,$refresh) = @_;
	$$gui{status}->push(0,($refresh ? "Reb" : "B") . "uilding UI...");
	if (defined $$gui{tabbar}) {
		unless ($refresh) { warn "populateMainWin called twice without refresh flag"; return; }
		$$gui{tabbar}->destroy(); # refresh
	} 
	# TODO: Refresh should check to see if there are existing objects (if conserving net traffic) and use those, if possible
	# TODO: Refresh should be able to refresh just one of the tabs, say 'man', if importing Manga...
	my $note = Gtk2::Notebook->new();
	$note->show();
	$$gui{vbox}->pack_start($note,1,1,2);
	$$gui{tabbar} = $note; # store for additional tabs
	if (defined config('UI','tabson')) { $note->set_tab_pos(config('UI','tabson')); } # set tab position based on config option
	foreach (qw[ ani man ]) {
		fillPage($dbh,$_,$gui);
	}
	$$gui{status}->push(0,"Ready.");
}
print ".";

sub buildTitleRows {
	my ($titletype,$target,$tlist,$rownum,@keys) = @_;
	my $rowshown = $rownum;
	my $updater;
	my $headcolor = "#CCCCFF";
	# each item in hash is a hash
	my @rows;
	my $needrows = scalar @keys * (config('UI','rulesep') ? 2 : 1) + $rownum;
	my ($w,$h) = $target->get_size();
	if ($h < $needrows) { $target->resize($w,$needrows); }
	my $bodyfont = 0;
	if (defined config('Font','body')) { $bodyfont = 1; }
#	if ($bodyfont) { applyFont($target,0); }
	foreach my $k (@keys) { # loop over list
		$rownum++; $rowshown++;
#		print "Building row for title $k...\n";
		my %record = %{$$tlist{$k}};
		unless (config('DB','conserve') eq 'net') {
			$updater = PomalSQL::getDB();
		} else {
			warn "Conserving net traffic is not yet supported";
		}
		if ($titletype eq 'head') {
			if (config('UI','linenos')) {
				my $nolabel = Gtk2::Label->new("#");
				if ($bodyfont) { applyFont($nolabel,0); }
				my $cb = Gtk2::EventBox->new();
				$cb->add($nolabel);
				$cb->show();
				$cb->modify_bg("normal",Gtk2::Gdk::Color->parse(config('UI','headerbg') or $headcolor));
				$target->attach($cb,0,1,0,1,qw( fill ),qw( fill ),0,0);
			}
			$rownum--; 
		} else {
			my $nolabel = Gtk2::Label->new((config('UI','linenos') ? "$rowshown" : ""));
			if ($bodyfont) { applyFont($nolabel,0); }
			$target->attach($nolabel,0,1,$rownum,$rownum+1,qw( fill ),qw( fill ),7,0);
		}
		my $title = Gtk2::Label->new($record{title}); # put in the title of the series
		$title->show();
		$title->set_alignment(0.0,0.1);
		$title->set_width_chars(35);
		$title->set_line_wrap(1);
		if ($bodyfont) { applyFont($title,0); }
		if ($titletype eq 'head') {
			my $cb = Gtk2::EventBox->new();
			$cb->add($title);
			$cb->show();
			$cb->modify_bg("normal",Gtk2::Gdk::Color->parse(config('UI','headerbg') or $headcolor));
			$target->attach($cb,1,2,0,1,qw( fill ),qw( fill ),0,0);
		} else {
			$target->attach($title,1,2,$rownum,$rownum+1,qw( fill ),qw( shrink),0,0);
		}
		my $rbox = Gtk2::HBox->new();
		$rbox->show();
		if ($titletype eq 'head') {
			my $cb = Gtk2::EventBox->new();
			$cb->add($rbox);
			$cb->show();
			$cb->modify_bg("normal",Gtk2::Gdk::Color->parse(config('UI','headerbg') or $headcolor));
			$target->attach($cb,2,3,0,1,qw( fill ),qw( fill ),0,0);
		} else {
			my $rew = Gtk2::Label->new(($record{status} == 3 ? " (Re" . ($titletype eq 'series' ? "watch" : "read" ) . "ing) " : "")); # put in the rewatching status
			$rew->show();
			if ($bodyfont) { applyFont($rew,0); }
			$rbox->pack_start($rew,1,1,1);
			unless ($record{status} == 4) { # No move button for completed page
				my $rbut = Gtk2::Button->new("m");
				$rbut->show();
				$rbox->pack_start($rbut,1,0,1);
				my $status = $record{status};
				$rbut->signal_connect('clicked',\&chooseStatus,[$rew,\$status,$k,$titletype]);
			} # but there might some day be a "Rewatch this show" button here
			$target->attach($rbox,2,3,$rownum,$rownum+1,qw( shrink ),qw( shrink),0,0);
		}
		if ($titletype eq 'head') {
			my $plabel = Gtk2::Label->new("Progress");
			$plabel->show();
			if ($bodyfont) { applyFont($plabel,0); }
			my $cb = Gtk2::EventBox->new();
			$cb->add($plabel);
			$cb->show();
			$cb->modify_bg("normal",Gtk2::Gdk::Color->parse(config('UI','headerbg') or $headcolor));
			$target->attach($cb,3,4,0,1,qw( fill ),qw( fill ),2,0);
		} else {
			my $updateform = ($titletype eq "series" ? ($record{status} == 3 ? 1 : 0 ) : ($record{status} == 3 ? 3 : 2 ) );
			my $pvbox = Gtk2::VBox->new();
			$pvbox->show();
			my $pchabox = Gtk2::HBox->new();
			$pchabox->show();
			$target->attach($pvbox,3,4,$rownum,$rownum+1,qw( shrink ),qw( shrink),2,0);
			$pvbox->pack_start($pchabox,0,0,0);
		# put in the number of watched/episodes (button) -- or chapters
			my $pprog = ($record{status} == 4 ? "" : ($titletype eq 'series' ? ($record{status} == 3 ? "$record{lastrewatched}" : "$record{lastwatched}" ) : ($record{status} == 3 ? "$record{lastreread}" : "$record{lastreadc}" )) . "/") . ($titletype eq 'series' ? "$record{episodes}" : "$record{chapters}" );
			my $pbut = Gtk2::Label->new($pprog);
			applyFont($pbut,2);
			my $pebut = Gtk2::EventBox->new();
			$pchabox->pack_start($pebut,1,1,0);
			$pebut->add($pbut);
		# link the button to a dialog asking for a new value
			$pebut->signal_connect("button_press_event",\&askPortion,[$pvbox,$updateform,$k,$updater]);
		# put in a label giving the % completed (using watch or rewatched episodes)
			my $rawperc = ($titletype eq 'series' ? ($record{status} == 3 ? $record{lastrewatched} : $record{lastwatched} ) : ($record{status} == 3 ? $record{lastreread} : $record{lastreadc} )) / (($titletype eq 'series' ? $record{episodes} : $record{chapters} ) or 100);
			my $pertxt = sprintf("%.2f%%",$rawperc * 100);
		# read config option and display percentage as either a label or a progress bar
			if (config('UI','graphicprogress')) {
				my $percb = Gtk2::ProgressBar->new();
#				$percb->set_usize(100,10);
### TODO: figure out how to resize this widget
				$percb->set_text($pertxt);
				applyFont($percb,2);
				$percb->set_fraction($rawperc);
				$percb->show();
				$pvbox->pack_end($percb,0,0,0);
			} else {
				my $percl = Gtk2::Label->new($pertxt);
#				$percl->set_usize(100,10);
				applyFont($percl,2);
				$percl->show();
				$pvbox->pack_end($percl,0,0,0);
			}
		# put in a button to increment the number of episodes or chapters (using watch or rewatched episodes)
			unless ($record{status} == 4) {
				my $incbut = Gtk2::Button->new("+");
				applyFont($incbut,2);
				$incbut->show();
				$pchabox->pack_start($incbut,0,0,0);
				$incbut->signal_connect("clicked",\&incrementPortion,[$pvbox,$updateform,$k,$updater]);
			}
		# if manga, put in the number of read/volumes (button)
			if ($titletype eq 'pub') {
				my $pvolbox = Gtk2::HBox->new();
				$pvolbox->show();
				$pvbox->pack_start($pvolbox,0,0,0);
				# put in the number of watched/episodes (button) -- or chapters
				my $vbut = Gtk2::Label->new("$record{lastreadv}/$record{volumes}");
				applyFont($vbut,2);
				my $vebut = Gtk2::EventBox->new();
				$pvolbox->pack_start($vebut,1,1,0);
				$vebut->add($vbut);
				# link the button to a dialog asking for a new value
				my $upform = ($record{status} == 3 ? 5 : 4 );
				$vebut->signal_connect("button_press_event",\&askPortion,[$pvbox,$upform,$k,$updater]);
				# put in a button to increment the number of volumes (using read or reread volumes)
				unless ($record{status} == 4) {
					my $incvbut = Gtk2::Button->new("+");
					applyFont($incvbut,2);
					$incvbut->show();
					$pvolbox->pack_start($incvbut,0,0,0);
					$incvbut->signal_connect("clicked",\&incrementPortion,[$pvbox,$upform,$k,$updater]);
				}
			}
		}
		if ($titletype eq 'head') {
			my $tags = Gtk2::Label->new("Tags");
			$tags->show();
			if ($bodyfont) { applyFont($tags,0); }
			my $cb = Gtk2::EventBox->new();
			$cb->add($tags);
			$cb->show();
			$cb->modify_bg("normal",Gtk2::Gdk::Color->parse(config('UI','headerbg') or $headcolor));
			$target->attach($cb,4,5,0,1,qw( fill ),qw( fill ),0,0);
		} else {
			my $tags = Gtk2::Button->new("Show/Edit tags"); # put in the tag list (button?)
# use $k for callback; it should contain the series/pub id #.
			$tags->show();
			$target->attach($tags,4,5,$rownum,$rownum+1,qw( shrink ),qw( shrink),1,0);
		}
		if ($titletype eq 'head') {
			my $score = Gtk2::Label->new($record{score});
			$score->show();
			if ($bodyfont) { applyFont($score,0); }
			my $cb = Gtk2::EventBox->new();
			$cb->add($score);
			$cb->show();
			$cb->modify_bg("normal",Gtk2::Gdk::Color->parse(config('UI','headerbg') or $headcolor));
			$target->attach($cb,5,6,0,1,qw( fill ),qw( fill ),2,0);
		} else {
			my $score = Gtk2::Button->new(sprintf("%.1f",$record{score} / 10)); # put in the score
			$score->show();
			$target->attach($score,5,6,$rownum,$rownum+1,qw( shrink ),qw( shrink),1,0);
			$score->signal_connect('clicked',\&scoreSlider,[$k,$titletype,$updater]);
		}
		# put in a button to edit the title/list its volumes/episodes
		# put in button(s) for moving to another status? TODO later
		$target->show_all();
##		if (config('DB','conserve') eq 'net') { my $obj = buildObjFromHash($titletype,%record); push(@rows,$obj); } # for conserving net traffic
		if ($titletype ne 'head' and config('UI','rulesep')) {
			my $rule = Gtk2::HSeparator->new();
			$rule->show();
			$rownum++;
			$target->attach($rule,1,5,$rownum,$rownum+1,qw( fill ),qw( shrink),7,1);
		}
	} # end loop
	return @rows;
}
print ".";

sub callOptBox {
	Options::mkOptBox(getGUI());
}
print ".";

sub fillPage {
	my ($dbh,$typ,$gui) = @_;
	unless (defined $$gui{tabbar}) { Gtkdie("fillPage couldn't find tab bar!"); }
	my $text = "???";
	my $rowtyp = "???";
	my $sortkey = 'title';
	my %exargs;
	for ($typ) {
		if (/ani/) { $text = (config('Custom',$typ) or "Anime"); $rowtyp = "series"; }
		elsif (/man/) { $text = (config('Custom',$typ) or "Manga"); $rowtyp = "pub"; }
		elsif (/mov/) { $text = (config('Custom',$typ) or "Movies"); $rowtyp = "series"; $exargs{max} = 1; }
		elsif (/sam/) { $text = (config('Custom',$typ) or "Books"); $rowtyp = "pub"; $exargs{max} = 1; }
		else { $text = "Unknown"; }
	}
	my $label = Gtk2::Label->new($text);
	applyFont($label,1);
	my %statuses = Common::getStatHash($typ);
	my %boxesbystat;
	my %labels;
	$$gui{status}->push(0,"Loading titles...");
	my $tref = getGUI('tables'); # doing this way instead of pulling from existing GUI because, if not present, this function will create them
	foreach (keys %statuses) {
		# %exargs allows limit by parameters (e.g., at least 2 episodes (not a movie), at most 1 episode (movie))
		# $exargs{maxparts} = 1
		# getTitlesByStatus will put Watching (1) and Rewatching (3) together unless passed "rew" as type.
		my $h = getTitlesByStatus($dbh,$rowtyp,$_,%exargs);
		my @keys = indexOrder($h,$sortkey);
		# make a label
		$labels{$_} = Gtk2::Label->new($statuses{$_});
		$labels{$_}->set_alignment(0.05,0.5);
		applyFont($labels{$_},1);
		$labels{$_}->show();
#		print "Looking for " . $typ . $_ . "...";
		my $table = $$tref{$typ.$_};
		$table->show();
		my $tlist = { 'h' => {
			title => "Title",
			status => 0,
			score => "Score",
			sid => "?"
		}};
		buildTitleRows("head",$table,$tlist,0,'h');
		# fill the box with titles
		buildTitleRows($rowtyp,$table,$h,0,@keys);
		# compile statistics from @a
		# put in a label/box of labels with statistics (how many titles, total episodes watched, mean score, etc.)
		$boxesbystat{$_} = $table; # put box into %boxesbystat
	}
	unless (config('UI','statustabs') or 0) {
		$$gui{status}->push(0,"Placing titles in box...");
		my $box = Gtk2::VBox->new();
		$box->show();
		my $scroll = Gtk2::ScrolledWindow->new();
		$scroll->show();
		$$gui{tabbar}->append_page($scroll,$label);
		$scroll->add_with_viewport($box);
		foreach (Common::getStatOrder()) { # specific order
			my $section = Gtk2::Frame->new();
			$section->show();
			$section->set_label_widget($labels{$_});
			$section->add($boxesbystat{$_}); # place titlebystatus box in box
			$box->pack_start($section,1,1,2);
		}
	} else {
		$$gui{status}->push(0,"Placing titles in tabs...");
		my $snote = Gtk2::Notebook->new(); # make statuses tab notebook
		$snote->show();
		if (defined config('UI','tabson')) { $snote->set_tab_pos(config('UI','tabson')); } # set tab position based on config option
		foreach (Common::getStatOrder()) { # specific order
			my $newscroll = Gtk2::ScrolledWindow->new();
			$newscroll->show();
			$snote->append_page($newscroll,$labels{$_}); # make tab for this status
			$newscroll->add_with_viewport($boxesbystat{$_}); # place titlebystatus box in newscroll
		}
		$$gui{tabbar}->append_page($snote,$label);
	}
}
print ".";

sub applyFont {
	my ($self,$index) = @_;
	my $key = qw( body label progress special )[$index] or 'body';
	my $font = config('Font',$key);
	if (defined $font) { $self->modify_font(Gtk2::Pango::FontDescription->from_string($font)); }
}
print ".";

sub importGUI {
	my ($caller) = @_;
	my $dbh = PomalSQL::getDB();
	my $gui = getGUI();
	use Import;
	my $error = Import::importXML($dbh,$gui);
	unless($error) {
		populateMainWin($dbh,$gui,1);
		$$gui{status}->push(0,"Ready.");
	}
}
print ".";

my $counter = 0;
sub getTitlesByStatus {
	my ($dbh,$rowtype,$status,%exargs) = @_;
	my %stas = Common::getStatIndex();
	my %rows;
	my @parms;
	my $st = "SELECT " . ($rowtype eq 'series' ? "sid,episodes,sname" : "pid,chapters,volumes,lastreadv,pname") . " AS title,status,score,";
	$st = $st . ($rowtype eq 'series' ? "lastrewatched,lastwatched" : "lastreread,lastreadc") . " FROM ";
	$st = $st . $dbh->quote_identifier($rowtype) . " WHERE status=?" . ($status eq 'wat' ? " OR status=?" : "");
	push(@parms,$stas{$status});
	if ($status eq 'wat') { push(@parms,$stas{rew}); }
	my $key = ($rowtype eq 'series' ? 'sid' : 'pid');
#	print "$st (@parms)=>";
	my $href = PomalSQL::doQuery(3,$dbh,$st,@parms,$key);
	return $href;
}
print ".";

=item indexOrder()
	Expects a reference to a hash that contains hashes of data as from fetchall_hashref.
	This function will return an array of keys ordered by whichever internal hash key you provide.
	@array from indexOrder($hashref,$]second-level key by which to sort first-level keys[)
=cut
sub indexOrder {
	my ($hr,$orderkey) = @_;
	my %hok;
	foreach (keys %$hr) {
		my $val = $_;
		my $key = qq( $$hr{$_}{$orderkey} );
		$hok{$key} = $val;
	}
	my @keys;
	foreach (sort keys %hok){
		push(@keys,$hok{$_});
	}
	return @keys;
}
print ".";

sub incrementPortion {
	my ($caller,$args) = @_;
	my ($target,$uptype,$titleid,$updater) = @$args;
	if (0) { print "incrementPortion(@$args)\n"; }
	$caller->set_sensitive(0); # grey out caller
	my ($value,$max) = getPortions($updater,$uptype,$titleid);
	unless (defined $max) {
		sayBox(getGUI(mainWin),"Error: Could not retrieve count max.");
		$caller->set_sensitive(1); # un-grey caller
		return;
	}
	unless ($value >= $max) { $value++; } else { return; }
	my $result = updatePortion($uptype,$titleid,$value,$updater); # call updatePortion
	if ($result == 0) { warn "Oops!";
	} else {
		setProgress($target,$uptype,$value,$max);
	}
	if (defined $value and $value == $max) { # ask to set complete if portions == total
		warn "Not asking to move to Completed, because it hasn't been coded! Smack the coder";
	} else {
		$caller->set_sensitive(1); # un-grey caller
	}
}
print ".";

sub setProgress {
	my ($target,$uptype,$value,$max) = @_;
	# update the widgets that display the portion count
	my ($txtar,$nutar) = unpackProgBox($target,($uptype > 3 ? 1 : 0));
	my $pprog = $value . "/" . $max;
	$txtar->set_text($pprog);
	unless ($uptype > 3) {
		my $rawperc = $value / ($max or 100);
		if (ref($nutar) eq "Gtk2::ProgressBar") { $nutar->set_fraction($rawperc); }
		$nutar->set_text(sprintf("%.2f%%",$rawperc * 100));
	}
}
print ".";

sub updatePortion {
	my ($uptype,$titleid,$value,$uph) = @_;
	if (config('DB','conserve') eq 'net') { # updating objects
		my $sobj = $uph; # get object
		# check if REF is for an Anime or Manga object
		# use uptype for this?
		# increment portion count
		warn "This is only a dream. I haven't really updated your objects, because this part hasn't been coded. Sorry. Smack the coder";
	} else {
		my $dbh = $uph;
		unless (defined $dbh) {
			$dbh = PomalSQL::getDB(); # attempt to pull existing DBH
		}
		unless (defined $dbh) { # if that failed, I have to die.
			my $win = getGUI(mainWin);
			dieWithErrorbox($win,"updatePortion was not passed a database handler!");
		}
		my @criteria = ( "lastwatched", "lastrewatched", "lastreadc", "lastrereadc", "lastreadv", "lastrereadv" );
		my $data = {};
		$$data{$criteria[$uptype]} = $value;
		$$data{($uptype < 2 ? "sid" : "pid" )} = $titleid;
		my ($error,$st,@parms) = PomalSQL::prepareFromHash($data,($uptype < 2 ? "series" : "pub" ),1);
		unless ($error) {
			my $res = PomalSQL::doQuery(2,$dbh,$st,@parms); # update SQL table
			unless ($res == 1) { sayBox(getGUI(mainWin),"Error: " . $dbh->errstr); return 0; } # rudimentary error message for now...
		} else {
			sayBox(getGUI(mainWin),"Error: $st"); return 0;
		}
	}
	return $value;
}
print ".";

sub askPortion {
	# for when user clicks on display of portions completed
	my ($caller,$caller2,$args) = @_;
	my ($target,$uptype,$titleid,$updater) = @$args;
	if (0) { print "askPortion(@$args)\n"; }
	$caller->set_sensitive(0); # grey out caller
	my ($value,$max) = getPortions($updater,$uptype,$titleid);
	unless (defined $max) {
		sayBox(getGUI(mainWin),"Error: Could not retrieve count max.");
		$caller->set_sensitive(1); # un-grey caller
		return;
	}
	my $response = PGUI::askBox(getGUI(mainWin),"Enter new value",($uptype < 2 ? "Episodes" : ($uptype < 4 ? "Chapters" : "Volumes" )),( nospace => 1, default => $value, panel => 1, position => 'mouse'));
	unless ($response =~ m/^[0-9]+$/) { # don't store bad input
		if (defined $response) { sayBox(getGUI(mainWin),"'$response' does not appear to be a valid number."); } # only carp if user entered a number; blank could mean Esc/cancel
		$caller->set_sensitive(1); # un-grey caller
		return;
	}
	unless ($value > $max or $value < 0) { $value = $response; } else { sayBox(getGUI(mainWin),"'$response' is not between 0 and $max."); }
	my $result = updatePortion($uptype,$titleid,$value,$updater); # call updatePortion
	if ($result == 0) { warn "Oops!";
	} else {
		setProgress($target,$uptype,$value,$max);
	}
	if (defined $value and $value == $max) { # ask to set complete if portions == total
		warn "Not asking to move to Completed, because it hasn't been coded! Smack the coder";
	} else {
		$caller->set_sensitive(1); # un-grey caller
	}
}
print ".";

sub getPortions {
	my ($updater,$uptype,$titleid) = @_;
	if (config('DB','conserve') eq 'net') { # updating objects
		my $sobj = $updater; # get object
		# check if REF is for an Anime or Manga object
		# use uptype for this?
		# increment portion count
		warn "This is only a dream. I haven't really updated your objects, because this part hasn't been coded. Sorry. Smack the coder";
	} else {
		my $dbh = $updater;
		unless (defined $dbh) {
			$dbh = PomalSQL::getDB(); # attempt to pull existing DBH
		}
		unless (defined $dbh) { # if that failed, I have to die.
			my $win = getGUI(mainWin);
			dieWithErrorbox($win,"getPortions was not passed a database handler!");
		}
		my $st = "SELECT episodes,lastwatched,lastrewatched FROM series WHERE sid=?";
		if ($uptype > 1) { $st = "SELECT chapters,lastreadc,lastreread FROM pub WHERE pid=?"; }
		if ($uptype > 3) { $st = "SELECT volumes,lastreadv FROM pub WHERE pid=?"; }
		if (0) { print "$st <= $titleid\n"; }
		my $res = PomalSQL::doQuery(5,$dbh,$st,$titleid);
		unless (defined $res) { return; } # no response: return
		$value = @$res[($uptype % 2 ? 2 : 1 )];
		$max = @$res[0];
		if (0) { print "Count: ($value/$max)\n"; }
	}
	return $value,$max;
}
print ".";

sub chooseStatus {
	my ($caller,$args) = @_;
	my ($target,$statref,$xid,$t) = @$args;
	$caller->set_sensitive(0); # grey button
	my %exargs = (
		chosen => Common::revGet($$statref,undef,Common::getStatIndex()),
		panel => 1,
		position => 'mouse',
	);
	my @keyord = Common::getStatOrder();
	my %statuses = Common::getStatHash(($t eq 'series' ? "ani" : "man"));
	$exargs{choices} = \%statuses;
	$exargs{choiceorder} = \@keyord;
	my $key = askBox(getGUI(mainWin),"^.^","Move to which status?",%exargs);
	my %vals = Common::getStatIndex();
	my $data = { ($t eq 'series' ? 'sid' : 'pid') => $xid };
	if (defined $key and $key ne "") {
		# TODO: if key == 4, ask if sure, and whether to set seen to max
		$$data{status} = $vals{$key};
		my ($error,$cmd,@parms) = PomalSQL::prepareFromHash($data,$t,1);
		if ($error) {
			saybox(getGUI(mainWin),"Error #$error: $parms[0]");
		} else {
			# TODO: conservation option
			my $dbh = PomalSQL::getDB();
			my $success = PomalSQL::doQuery(2,$dbh,$cmd,@parms); # update SQL
			if ($success == 1) {
				if (config('UI','moveredraw')) { # if config option says to,
					populateMainWin($dbh,getGUI(),1); # refresh pages
				} else { # otherwise, change the label that is normally used for (rewatching) to indicate title has been moved
					$target->set_text("(moved to $statuses{$key})");
					$$statref = $vals{$key};
				}
			} else {
				sayBox(getGUI(mainWin),"Could not update status in SQL: " . $dbh->errstr);
			}
		}
	}
	$caller->set_sensitive(1); # un-grey button
	return 0; # end chooseStatus
}
print ".";

sub scoreSlider {
	# for use when user clicks a score button
	my ($caller,$args) = @_;
	my ($titleid,$table,$dbh) = @$args;
	$caller->set_sensitive(0); # grey out the button
	my $value = $caller->get_label();
	my $keepbox = 1;
	my $valueset = 0;
	my $box = Gtk2::VBox->new();
	$box->show();
	my $scorepop = mkPopup($box);
	my $slide = Gtk2::HScale->new();
	$slide->set_range(0,(config('UI','starscale') ? 5 : 10));
	$slide->set_increments((config('UI','intscore') ? 1 : (config('UI','starscale') ? 0.5 : 0.1)),1); # display a volume control from 0.0 to 10.0
	$slide->set_digits(1);
	$slide->set_size_request(400,-1);
	$slide->set_value_pos('right');
	$slide->set_value($value);
	foreach ((config('UI','starscale') ? (1,2,3,4,5) : (1,2,3,4,5,6,7,8,9,10))) {
		$slide->add_mark($_,'top',sprintf("%s",$_));
	}
	$slide->show();
	$box->pack_start($slide,1,1,1);
	
	my $buttons = Gtk2::HBox->new();
	$buttons->show();
	$box->pack_end($buttons,0,0,1);
	# display a button for confirm, and one for cancel
	my $but = Gtk2::Button->new("Set");
	$but->show();
	$but->signal_connect('clicked',sub { $value = $slide->get_value(); $keepbox = 0; $valueset = 1; }); # if confirmed, read slider for value
	$buttons->pack_end($but,0,0,1);
	my $oops = Gtk2::Button->new("Cancel");
	$oops->show();
	$oops->signal_connect('clicked',sub { $keepbox = 0; });
	$buttons->pack_end($oops,0,0,1);
	while ($keepbox) {
		Gtkwait(0.25);
	}
	if ($valueset) {
		if (config('UI','intscore')) { $value = Common::nround(0,$value); }
		my $data = { score => $value * 10 };
		$$data{($table eq "series" ? 'sid' : 'pid')} = $titleid;
		# TODO: update object instead of SQL if option is set
	# update SQL
		my ($error,$cmd,@parms) = PomalSQL::prepareFromHash($data,$table,1);
		if ($error) {
			saybox(getGUI(mainWin),"Error #$error: $parms[0]");
		} else {
	# update button text with new score value
			my $success = PomalSQL::doQuery(2,$dbh,$cmd,@parms);
			if ($success == 1) {
				$caller->set_label(sprintf("%.1f",$value));
			} else {
				sayBox(getGUI(mainWin),"Could not update score in SQL: " . $dbh->errstr);
			}
		}
	}
	$scorepop->destroy(); # destroy slider window
	$caller->set_sensitive(1); # un-grey button
}
print ".";

sub unpackProgBox {
		my ($pbox,$getvols) = @_;
		my $countwidget,$percwidget,$pluswidget;
		my @kids = $pbox->get_children();
		if (scalar @kids == 3) { # manga progress?
			my $index = ($getvols ? 1 : 0);
			my @gkids = $kids[$index]->get_children();
			unless (defined $gkids[0] and ref($gkids[0]) eq "Gtk2::EventBox") {
				warn "Box improperly constructed! Found " . (ref($gkids[0]) or "undef") . " where Button expected";
				return;
			}
			unless (defined $gkids[1] and ref($gkids[1]) eq "Gtk2::Button") {
				warn "Box improperly constructed (nonfatal)! Found " . (ref($gkids[1]) or "undef") . " where Button expected";
			} else {
				$pluswidget = $gkids[1];
			}
			unless (defined $kids[2] and (ref($kids[2]) eq "Gtk2::Label" or ref($kids[2]) eq "Gtk2::ProgressBar")) {
				warn "Box improperly constructed! Found " . (ref($kids[2]) or "undef") . " where Label or ProgressBar expected";
				return;
			}
			$countwidget = $gkids[0]->get_child(); $percwidget = $kids[2];
		} elsif (scalar @kids == 2) { # anime progress?
			my @gkids = $kids[0]->get_children();
			unless (defined $gkids[0] and ref($gkids[0]) eq "Gtk2::EventBox") {
				warn "Box improperly constructed! Found " . (ref($gkids[0]) or "undef") . " where Button expected";
				return;
			}
			unless (defined $gkids[1] and ref($gkids[1]) eq "Gtk2::Button") {
				warn "Box improperly constructed (nonfatal)! Found " . (ref($gkids[1]) or "undef") . " where Button expected";
			} else {
				$pluswidget = $gkids[1];
			}
			unless (defined $kids[1] and (ref($kids[1]) eq "Gtk2::Label" or ref($kids[1]) eq "Gtk2::ProgressBar")) {
				warn "Box improperly constructed! Found " . (ref($kids[1]) or "undef") . " where Label or ProgressBar expected";
				return;
			}
			$countwidget = $gkids[0]->get_child(); $percwidget = $kids[1];
		} else {
			warn "Oops!" . scalar @kids . " children present in box";
		}
		return $countwidget,$percwidget,$pluswidget;
}
print ".";

sub askBox {
	my ($parent,$text,$label,%exargs) = @_;
	unless (defined $parent) { $parent = getGUI(mainWin); }
	my $askbox = Gtk2::Dialog->new((sprintf $text or "Input"),$parent,[qw/modal destroy-with-parent/],'gtk-cancel' => 'cancel');
	if ($exargs{panel}) { $askbox->set_decorated(0); } # no decoration
	$askbox->set_position($exargs{position} or 'center-always');
	my $vbox = $askbox->vbox;
	my $entry = Gtk2::Entry->new();
	unless ($exargs{choices}) {
		$askbox->add_button('gtk-ok' => 'ok');
		my $row = Gtk2::HBox->new();
		my $answer = $exargs{default} or "";
		$entry->set_text($answer);
		$entry->signal_connect("activate",sub { $askbox->response('ok'); });
		$row->pack_start($entry,1,1,1);
		$row->pack_start(Gtk2::Label->new($label),0,0,5);
		$entry->grab_focus();
		$vbox->pack_end($row,1,1,0);
	} else {
		my %choices = %{ $exargs{choices} };
		my @order = @{ $exarg{choiceorder} };
		unless (scalar @order) { @order = sort keys %choices; };
		$vbox->pack_start(Gtk2::Label->new($label),1,0,5);
		foreach (@order) {
			my $b = Gtk2::Button->new("$choices{$_}");
			$b->show();
			if ($_ eq $exargs{chosen}) {
				$b->set_sensitive(0);
			} else {
				my $r = $_;
				$b->signal_connect('clicked',sub { $entry->set_text("$r"); $askbox->response('ok'); });
			}
			$vbox->pack_start($b,0,0,1);
		}
	}
	my ($width,$height) = $askbox->get_size();
	$askbox->show_all();
	if ('ok' eq $askbox->run()) {
		$answer = $entry->get_text();
		if ($exargs{nospace}) { $answer =~ s/' '/'-'/g; } # Spaces not allowed.
	} else {
#		print "Cancelled";
		$answer = undef;
	}
	$askbox->destroy();
	return $answer;
}
print ".";

sub mkPopup {
	my ($widget) = @_;
	my $pop = Gtk2::Window->new();
	$pop->set_default_size(20,20);
	$pop->set_decorated(0);
	$pop->set_gravity('south-east');
	$pop->set_position('mouse');
	if (defined $widget) { $pop->add($widget); }
	$pop->present();
#	$pop->set_position('mouse');
	return $pop;
}
print ".";

sub selColor {
	my ($caller,$target,$title) = @_;
	unless (defined $title) { $title = "Choose a color"; }
	unless (ref($target) =~ m/Entry/) { warn "Bad target sent to selColor"; return; }
	my $a = Gtk2::Gdk::Color->parse($target->get_text());
	my $d = Gtk2::ColorSelectionDialog->new($title);
	my $c = $d->colorsel;
	$c->set_current_color($a);
	$rsp = $d->run();
	if ($rsp eq 'ok') {
	$cas = $c->get_current_color()->to_string();
	my @a = split(undef,$cas);
	$b = uc sprintf("#%s%s%s%s%s%s",$a[1],$a[2],$a[5],$a[6],$a[9],$a[10]);
	$target->set_text($b);
	setBack(undef,[$target,'normal',$b]);
	}
  $d->destroy();
  return;
}
print ".";

sub setBack {
	my ($caller,$args) = @_;
	my ($target,$state,$color) = @$args;
	unless (defined $color) {
		if (ref($target) =~ m/Entry/) {
			$color = $target->get_text();
		}
		unless (defined $color) {
			$color = "#FFFFFF";
		}
	}
	if (config("Debug","vlevel") > 1) { printf("%s called setBack with %s",$caller,$color); }
	$target->modify_base($state,Gtk2::Gdk::Color->parse($color)); # change background
}
print ".";

sub aboutBox {
	sayBox(@_[1],"Welcome to POMAL, an offline anime/manga tracking program.\nI hope you enjoy this program.\nEverything should be self-explanatory, but if I get feedback otherwise, I'll put some time into making a tutorial and a more informative About box.\n--over2SD");
}
print ".";

print " OK; ";
1;
