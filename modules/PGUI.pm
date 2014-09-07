# Graphic User Interface module
package PGUI;
print __PACKAGE__;

use Gtk2 -init; # requires GTK perl bindings

use FIO;

sub config { return FIO::config(@_); }

sub Gtkdie {
	print "I am slain.\n";
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
	# look at config and try to connect to the database.
	# if the database doesn't exist, try to create it.
	# or if user has chosen to use flatfile, import the XML.
	$window->show_all();
	return $window,$splashdetail,$progress,$vb;
}

sub createMainWin {
	my ($w,$h) = @_;
	my %windowset;
	my $window = Gtk2::Window->new();
	$window->set_title("PersonalOfflineManga/AnimeList");
	$window->signal_connect (destroy => \&Gtkdie ); # not saving position/size
	if (config('Main','savepos')) {
		unless ($w and $h) { $w = config('Main','width'); $h = config('Main','height'); }
		$window->set_default_size($w,$h);
		$window->move((config('Main','left') or 40),(config('Main','top') or 30));
	}
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
	return %windowset;
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
		my $itemFS = itemize("_Save",$f);
#		accelerate($itemFS,"<Control>S",$ag);
#		$itemFS->signal_connect("activate",\&FIO::saveData);
#		File > Import
		my $itemFI = itemize("_Import",$f);
#		File > Export
		my $itemFE = itemize("_Export",$f);
#		File > Synchronize
		my $itemFO = itemize("Synchr_onize",$f);
#		File > Preferences
		my $itemFP = itemize("_Preferences",$f);
#		File > Quit
		my $itemFQ = itemize("_Quit",$f);
#		accelerate($itemFQ,"<Control>Q",$ag);
		$itemFQ->signal_connect("activate",\&storeWindowExit,$mainwin);
#		Help >
		my ($itemH,$h) = itemize("_Help",$menus,$ag);
#		Help > About
		my $itemHA = itemize("_About",$h);

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
	my $s = 'Main';
	if (config($s,'savepos')) {
		print "Storing window position.";
		my ($w,$h) = $window->get_size();
		my ($x,$y) = $window->get_position();
		config($s,'width',$w);
		config($s,'height',$h);
		config($s,'top',$y);
		config($s,'left',$x);
		FIO::saveConf();
	} else {
		print "Not storing window position.";
	}
	Gtkdie();
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
			Gtkwait(1);
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
				Gtkwait(1);
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
		print "Exiting.\n";
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
	$splash->destroy();
	print "Splash screen steps: $step/$steps\n";
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
		Gtkwait(1);
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
	Gtkdie(-2);
}
print ".";

sub sayBox {
	my ($parent,$text) = @_;
	my $askbox = Gtk2::MessageDialog->new($parent,[qw/modal destroy-with-parent/],'question','ok',sprintf $text);
#	$askbox->set_markup($text);
	my ($width,$height) = $askbox->get_size();
	$askbox->move(int((Gtk2::Gdk->screen_width()/2) - ($width/2)),int((Gtk2::Gdk->screen_height()/2) - ($height/2))); # to prevent pop-shift of window
	$askbox->show_all();
	$askbox->move(int((Gtk2::Gdk->screen_width()/2) - ($width/2)),int((Gtk2::Gdk->screen_height()/2) - ($height/2))); # in case it didn't work before display
	$askbox->run();
	$askbox->destroy();
	return 0;
}
print ".";

sub populateMainWin {
	my ($dbh,%gui) = @_;
	$gui{status}->push(0,"Building UI...");
	my $note = Gtk2::Notebook->new();
	$note->show();
	$gui{vbox}->pack_start($note,1,1,2);
	# set tab position based on config option
	my $alabel = Gtk2::Label->new("Anime");
	my $ascroll = Gtk2::ScrolledWindow->new();
	$ascroll->show();
	$note->append_page($ascroll,$alabel);
###start section -- may break this out into its own function and call it once for anime, once for manga, once for movies, if so configured...
	my %statuses = (wat=>"Watching",onh=>"On-hold",ptw=>"Plan to Watch",com=>"Completed",drp=>"Dropped"); # could be given i18n
	my %boxesbystat;
	my %labels;
	$gui{status}->push(0,"Loading titles...");
	foreach (keys %statuses) {
		# %exargs allows limit by parameters (e.g., at least 2 episodes (not a movie), at most 1 episode (movie))
		# getByStatus will put Watching (1) and Rewatching (3) together unless passed "rew" as type.
		# pull list of titles from DB @a = getByStatus($dbh,"series" or "pub",$_,%exargs);
		# make a label
		$labels{$_} = Gtk2::Label->new($statuses{$_});
		$labels{$_}->show();
		# make a box
		# fill the box with titles
		# $exargs{secondvalue} = 
		# buildTitleRows("series" or "pub",$status,$box,@a)
		# put box into %boxesbystat
	}
#	unless (config('Options','statustabs',0)) {
		$gui{status}->push(0,"Placing titles in box...");
		my $abox = Gtk2::VBox->new();
		$abox->show();
		$ascroll->add_with_viewport($abox);
		foreach (qw( wat onh ptw com drp )) {
			$abox->pack_start($labels{$_},0,0,1);
			# place titlebystatus box in $abox
		}
#	} else {
#		$gui{status}->push(0,"Placing titles in tabs...");
		# make statuses tab notebook
#		my $newnote = Gtk2::Notebook->new();
#		$newnote->show();
		# set tab position by config option
#		warn "Not coded! TODO: code a loop that makes a tab for each status and puts it in a second notebook ";
#		foreach (qw( wat onh ptw com drp )) {
			# make tab for this status
#			my $newscroll = Gtk2::ScrolledWindow->new();
#			$newscroll->show();
#			$newnote->append_page($newscroll,$labels{$_});
			# place titlebystatus box in newscroll
#		}
#	}
### end section

	# do the same thing for manga as was done for anime
	my $mlabel = Gtk2::Label->new("Manga");
	my $mscroll = Gtk2::ScrolledWindow->new();
	$mscroll->show();
	$note->append_page($mscroll,$mlabel);
### repeat section	
	$gui{status}->push(0,"Ready.");
}
print ".";

sub buildTitleRows {
	my ($titletype,$status,$parent,@tlist)
	# each item in list is an arrayref
# loop over list
	# make an HBox
	# put in the title of the series
	# put in the rewatching status
	# if manga, put in the number of read/volumes (button)
	# link the button to a dialog asking for a new value
	# if manga, put in a button to increment the number of volumes
	# put in the number of watched/episodes (button) -- or chapters
	# link the button to a dialog asking for a new value
	# put in a label giving the % completed (using watch or rewatched episodes)
	# put in a button to increment the number of episodes or chapters (using watch or rewatched episodes)
	# put in the tag list
	# put in the score
	# put in a button to edit the title/list its volumes/episodes
	# put in button(s) for moving to another status? TODO later
# end loop
	# put in a label/box of labels with statistics (how many titles, total episodes watched, mean score, etc.)
	# return list of objects?
}
print ".";

print " OK; ";
1;
