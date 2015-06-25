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

sub passTabByCode {
	my ($code1,$code2) = shift;
	my $tab = getTabByCode($code1);
	print "Tab: $tab \n";
	my $tabbar = PGK::getGUI('tabbar');
	my @list = $tabbar->widgets_from_page($tab);
	foreach (@list) {
		print "\n$_ - " . ($_->name or "unnamed") . ": " . ($_->text or "no text") . "\n";
	}
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
			my $pchabox = $pvbox->insert( HBox => name => 'partbox', backColor => $backcolor);
		# put in the number of watched/episodes (button) -- or chapters
			my $pprog = ($record{status} == 4 ? "" : ($titletype eq 'series' ? ($record{status} == 3 ? "$record{lastrewatched}" : "$record{lastwatched}" ) : ($record{status} == 3 ? "$record{lastreread}" : "$record{lastreadc}" )) . "/") . ($titletype eq 'series' ? "$record{episodes}" : "$record{chapters}" );
			my $pbut = $pchabox->insert( Label =>
				name => 'partlabel',
				text => $pprog,
				pack => { expand => 1, fill => 'both', },
					# link the button to a dialog asking for a new value
				onClick => sub { askPortion($pvbox,$updateform,$k,$updater,$record{title},($record{status} == 3));},
			);
			applyFont('button',$pbut);
			# put in a label giving the % completed (using watch or rewatched episodes)
			my $rawperc = ($titletype eq 'series' ? ($record{status} == 3 ? $record{lastrewatched} : $record{lastwatched} ) : ($record{status} == 3 ? $record{lastreread} : $record{lastreadc} )) / (($titletype eq 'series' ? $record{episodes} : $record{chapters} ) or 100) * 100;
			# read config option and display percentage as either a label or a progress bar
			if (config('UI','graphicprogress')) {
				my $percb = $pvbox->insert( Gauge => name => 'partbar', size => [100,24], value => $rawperc, pack => { expand => 0, fill => 'none', },);
				applyFont('progress',$percb);
			} else {
				my $pertxt = sprintf("%.2f%%",$rawperc);
				my $percl = $pvbox->insert( Label => name => 'parttxt', text => $pertxt);
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
	$box->insert( Label => text => "Add a$tabstr title", font => applyFont('bighead'), autoheight => 1, pack => { fill => 'x', expand => 1,}, autoHeight => 1, alignment => ta::Center, );
# status TINYINT DEFAULT 0,
	my $titlestat = $box->insert( XButtons => name => "status", pack => {fill=>'none',expand=>0});
	$titlestat->arrange('left');
	my @presets = (0,Sui::getStatHash($tab),'rew',"Rewatching");
	$titlestat-> build("Status:",@presets);
	my $row0 = $box->insert( HBox => name => 'row0');
	$row0->insert( Label => text => "Title", sizeMin => [150,20], pack => { fill => 'x', expand => 0 },);
	$row0->insert( Label => text => "Episodes", sizeMin => [100,20]);
	$row0->insert( Label => text => "Watched", sizeMin => [100,20]);
	my $row1 = $box->insert( HBox => name => 'row1');
	my $name = $row1->insert( InputLine => text => "", name => 'sname', sizeMin => [150,20], hint => "The title of the anime", pack => { fill => 'x', expand => 0 },);
	my $eps = $row1->insert( SpinEdit => value => 0, name => 'episodes', min => 0, max => $partmax, step => 1, pageStep => 10, sizeMin => [100,20]);
# rename to lastrewatched if (completed or) rewatching
	my $lastep = $row1->insert( SpinEdit => value => 0, name => 'lastwatched', min => 0, max => $partmax, step => 1, pageStep => 10, sizeMin => [100,20]);
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
# seentimes should be enabled only if rewatching or completed.
# seentimes INT UNSIGNED DEFAULT 0,
	my $seentimes = $row5->insert( SpinEdit => name => 'seentimes', value => 0, min => 0, max => 100, step => 1, pageStep => 5, sizeMin => [100,20], enabled => 0, );
	$titlestat->onChange(sub { unless ($titlestat->value eq 'com' or $titlestat->value eq 'rew') { $seentimes->enabled(0); $seentimes->value(0); } else { $seentimes->enabled(1); } });
# content INT(35) UNSIGNED,
	#my $content;
# rating TINYINT UNSIGNED,
	#my $rating;
# note VARCHAR(1000),
	my $tags = $row5->insert( InputLine => name => 'tags', text => '', sizeMin => [250,20]);
# stype VARCHAR(30)
	my $stype = $row5->insert( InputLine => text => 'TV', sizeMin => [50,20]); # TV, ONA, etc.
	my $row6 = $box->insert( HBox => name => 'row6');
	$row6->insert( Label => text => "Notes", sizeMin => [500,20]);
	my $row7 = $box->insert( HBox => name => 'row7');
	my $note = $row7->insert( InputLine => name => 'notes', text => '', sizeMin => [500,20]);

	my $buttons = $box->insert( HBox => name => 'buttons', pack => { fill => 'x', expand => 1, });
	$buttons->insert( Button => text => "Cancel", onClick => sub { $box->empty(); $box->send_to_back(); $$gui{tabbar}->show(); $$gui{status}->text("Title addition cancelled."); });
	$buttons->insert( Button => text => "Add", onClick => sub {
		return unless ($name->text ne '');
		$_[0]->enabled(0);
		my %data; # hashify
		if ($titlestat->value eq 'com') {
			$lastep->value = $eps->value;
		}
		foreach ($name, $started, $ended, $score, $stype, $note, $tags) {
			$data{$_->name} = $_->text;
		}
		foreach ($eps, $seentimes, ) {
			$data{$_->name} = $_->value;
		}
		if ($titlestat->value eq 'rew') {
			$data{lastrewatched} = $lastep->value;
			$data{lastwatched} = $eps->value;
		}
		$data{ended} = '0000-00-00' if ($data{ended} eq $data{started});
		$data{score} = int($data{score}) * 10;
		my %stats = Sui::getStatIndex();
		$data{status} = $stats{$titlestat->value};
		$data{sid} = -1;
		my $tabid = passTabByCode($tab,$titlestat->value);
print "Tab: $tabid\n";
		
die "\n";
		my $ttype = ($tab eq 'man' ? 'pub' : 'series');
		my ($found,$realid) = Sui::getRealID($dbh,$$gui{questionparent},'usr',$ttype,\%data);
		$data{sid} = $realid;
		my ($error,$cmd,@parms) = FlexSQL::prepareFromHash(\%data,$ttype,1,{idneeded => 1}); # prepare
		if ($error) { print "e: $error c: $cmd p: " . join(",",@parms) . "\n"; }
		$error = FlexSQL::doQuery(2,$dbh,$cmd,@parms); # submit
		$error = Sui::addTags($dbh,substr($ttype,0,1),$data{sid},$data{tags});
		$$gui{tabbar}->show();
		# display
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
	my $result = updatePortion($ttype,$titleid,$value,$updater); # call updatePortion
	if ($result == 0) { warn "Oops!";
	} else {
		setProgress($target,$volume,$value,$max);
	}
	editPortion($title,$titleid,$value, ($volume ? 'volume' : ($ttype > 1 ? 'chapter' : 'episode')),$volno);
	if (defined $value and $value == $max) { # ask to set complete if portions == total
		warn "Not asking to move to Completed, because it hasn't been coded! Smack the coder";
	} else {
		$caller->enabled(1);
	}
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
	my ($uptype,$titleid,$value,$uph) = @_;
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
		my ($error,$st,@parms) = FlexSQL::prepareFromHash($data,($uptype < 2 ? "series" : "pub" ),1);
		unless ($error) {
			my $res = FlexSQL::doQuery(2,$dbh,$st,@parms); # update SQL table
			unless ($res == 1) { sayBox(getGUI('mainWin'),"Error: " . $dbh->errstr); return 0; } # rudimentary error message for now...
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
	my ($dets,$dorate) = (FIO::config('UI','askdetails'),FIO::config('UI','rateparts'));
	return unless ($dets or $dorate); # not doing anything unless there's something to do.
	my $gui = getGUI();
	my $qbox = $$gui{questionparent};
	my $tabs = $$gui{tabbar};
	$tabs->hide();
	$qbox->empty();
	$qbox->insert( Label => text => "$displaytitle has been updated with $part ${ptype}s completed.", font => applyFont('body'), autoheight => 1, pack => { fill => 'x', expand => 1,}, autoHeight => 1, alignment => ta::Center, );
	my $values = {};
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
				$parent->show();
				$target->send_to_back();
			});
			return 2;
		} else {
			$parent->show();
			$target->send_to_back();
			return 0;
		}
	}
	if ($dets) { # If askdetails, show form for details
		$qbox->insert( Label => text => "You can enter any details about this $ptype you would like to store:");
		my $tibox = PGK::labelBox($qbox,"Title of $ptype",'h',boxex=>0); # show episode details form
		$tibox->insert( InputLine => text => ($$defaults{title} or ''), onChange => sub { $$values{title} = $_[0]->text; });
#		my $cbox = PGK::labelBox($qbox,"Objectionable content",'h',boxex=>0);
		my $seen = ($ptype eq 'episode' ? "watched" : "read");
		my $date = PGK::insertDateWidget($qbox,$$gui{mainwin},{label => "First $seen", default => ($$defaults{date} or Common::today()),boxex=>0, });
		$$values{date} = $date->text;
		$date->onClick( sub { $$values{date} = $date->text; });
#		my $rbox = PGK::labelBox($qbox,"Appropriate for age",'h',boxex=>0);
#		$rbox->insert( SpinEdit => value => ($$defaults{rating} or 0), min => 0, max => 100, step => 1, pageStep => 5, onChange => sub { $$values{rating} = $_[0]->value; }, );
	}
	if ($dorate) { # If rateparts, show buttons to rate
		my $score = $qbox-> insert( XButtons => name => 'score' ); # show rating buttons
		$score->arrange("left"); # line up buttons horizontally
		my @presets = ("0","Don't Rate","1","1","2",'2','3','3','4','4','5','5');
#		push(@presets,'6','6','7','7','8','8','9','9','10','10') unless FIO::config('UI','starscore');
		my $current = (int($$defaults{score} or 0));
		$score-> build("Score for $ptype:",$current,@presets); # turn key:value pairs into exclusive buttons
		$score->onChange( sub { $$values{score} = $score->value(); } );
	}
	$qbox->insert( Label => text => ' ', pack => { fill => 'both', expand => 1 });
	my $butbox = $qbox->insert( HBox => name => 'buttons');
	$butbox->insert( Button => text => 'Set Details', onClick => sub { portionExecute($dbh,$title,$part,$ptype,$values,$qbox,$tabs,$vol); }, );
	$butbox->insert( Button => text => 'Skip Setting Details', onClick => sub {
		$tabs->show();
		$qbox->empty();
		$qbox->send_to_back();
	} );
}
print ".";

sub scoreTitle {
# scoreTitle($k,$titletype,$record{score},$_[0],$updater); },
	my ($title,$ttype,$caller,$dbh) = @_;
	my ($dets,$dorate) = (FIO::config('UI','askdetails'),FIO::config('UI','rateparts'));
	my $gui = getGUI();
	my $qbox = $$gui{questionparent};
	my $tabs = $$gui{tabbar};
	$tabs->hide();
	$qbox->empty();
	my $st = {
		'series' => "SELECT sid,sname,episodes,score FROM series WHERE sid=?",
		'pub' => "SELECT pid,pname,chapters,score FROM pub WHERE pid=?",
	};
	my $key = {
		'series' => 'sid',
		'pub' => 'pid',
	};
	$st = $$st{$ttype} or die "Bad table name"; # no sympathy for bad tables!
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
	while ($i <= ((FIO::config('UI','starscore') or 0) ? 50 : 100)) {
		push(@ticks,{ value => $i, text => sprintf("%d",$i/10), });
		$i += 10;
	}
	my $score = $qbox-> insert( ($$parms{circ} ? 'CircularSlider' : 'Slider') =>
		value => ($$parms{value} or 0),
		min => 0,
		max => ((FIO::config('UI','starscore') or 0) ? 50 : 100),
		step => 10,
		pageStep => 30,
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
		$tabs->show();
		$qbox->send_to_back();
	});
	$buttons->insert( SpeedButton => text => "Cancel", onClick => sub {
		$qbox->empty();
		$tabs->show();
		$qbox->send_to_back();
	});
	unless (FIO::config('UI','autoscore')) {
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
			foreach (@$res) {
#				printf("%03d: $$_[1] (%s)\n",$$_[0],($$_[2] or "?"));
				my ($k,$n,$inc) = (sprintf("%03d",$$_[0]),($$_[2] or ""),$$_[1]);
				my $val = 0;
				if (FIO::config('UI','noanimate')) {
					$val = $inc * $frames;
				}
				$suggested += $$_[1];
				$scores++;
				my $this = $barbox->insert( Gauge => vertical => 1, value => $val, name => "$inc", hint => "$k ($n)", size => [($tdata{max} > 12 ? ($tdata{max} > 24 ? ($tdata{max} > 36 ? 7 : 14) : 21) : 28),100],);
				push(@$bars,$this);
				pulseBars($bars,$frames);
			}
		}
		while (@$bars) {
			pulseBars($bars,$frames);
		}
		$suggested /= $scores if ($scores);
		$suggested *= 2 unless (FIO::config('UI','starscore'));
		$suggested *= ((($tdata{max} or 0) or $scores) / $scores) if (FIO::config('UI','extendscore') and $scores);
		$suggested *= (10/(FIO::config('Main','wowfactor') or 8.45)); # This is a ratio, so no need to adjust for 5-star scoring;
		$suggested = 50 if ($suggested > 50 and FIO::config('UI','starscore'));
		$suggested = 100 if ($suggested > 100);
		$suggtxt->text(sprintf("Based on your rated $tdata{ptype}, $tdata{title} deserves a score of %.1f",$suggested));
		if ($score->value == 0) {
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
		$_->text('');
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
	$tabs->hide();
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

print " OK; ";

1;
