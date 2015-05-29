package Sui; # Self - Program-specific data storage
print __PACKAGE__;

=head1 Sui

Keeps common modules as clean as possible by storing program-specific
data needed by those common-module functions in a separate file.

=head2 passData STRING

Passes the data identified by STRING to the caller.
Returns some data block, usually an arrayref or hashref, but possibly
anything. Calling programs should be carefully written to expect what
they're asking for.

=cut

my %data = (
	dbname => 'pomal',
	dbhost => 'localhost',
	tablekeys => {
#		series_extra => ['alttitle',], #		pub_extra => ['alttitle',] #		episode => [], #		volume => [], #		chapter => [],
			series => ['sname','episodes','lastwatched','started','ended','score','content','rating','lastrewatched','seentimes','status','note','stype'],
			pub => ['pname','volumes','chapters','lastreadc','lastreadv','started','ended','score','content','rating','lastreread','readtimes','status','note'],
			extsid => ['mal','hum'],
			extpid => ['mal','hum'],
			# episode, volume, chapter?
		},
	tableids => { series => "sid", pub => "pid", extsid => "sid", extpid => "pid", },
	objectionablecontent => [ 'nudity','violence','language','sex','brutality','blasphemy','horror','nihilism','theology','occult','superpowers','rape','fanservice','drugs','hentai','gambling','war','discrimination'],
	disambiguations => {
		tag => ["tag_(context1)","tag_(context2)"],
		othertag => ["othertag_(context1)","othertag_(context2)"]
	},
);

sub passData {
	my $key = shift;
	for ($key) {
		if (/^opts$/) {
			return getOpts();
		} elsif (/^twidths$/) {
			return getTableWidths();
		} else {
			return $data{$key} or undef;
		}
	}
}
print ".";

sub getTitlesByStatus {
	my ($dbh,$rowtype,$status,%exargs) = @_;
	my %stas = getStatIndex();
	my %rows;
	my @parms;
	my $st = "SELECT " . ($rowtype eq 'series' ? "sid,episodes,sname" : "pid,chapters,volumes,lastreadv,pname") . " AS title,status,score,";
	$st = $st . ($rowtype eq 'series' ? "lastrewatched,lastwatched" : "lastreread,lastreadc") . " FROM ";
	$st = $st . $dbh->quote_identifier($rowtype) . " WHERE status=?" . ($status eq 'wat' ? " OR status=?" : "");
##		TODO here: max for movies/stand-alone manga
	$st = $st . " LIMIT ? " if exists $exargs{limit};
	push(@parms,$stas{$status});
	if ($status eq 'wat') { push(@parms,$stas{rew}); }
	push(@parms,$exargs{limit}) if exists $exargs{limit};
	my $key = ($rowtype eq 'series' ? 'sid' : 'pid');
#	print "$st (@parms)=>";
	my $href = FlexSQL::doQuery(3,$dbh,$st,@parms,$key);
	return $href;
}
print ".";

# Status hashes
sub getStatHash { my $typ = shift; return (wat=>($typ eq 'man' ? "Read" : "Watch") . "ing",onh=>"On-hold",ptw=>"Plan to " . ($typ eq 'man' ? "Read" : "Watch"),com=>"Completed",drp=>"Dropped"); } # could be given i18n
sub getStatOrder { return qw( wat onh ptw com drp ); }
sub getStatIndex { return ( ptw => 0, wat => 1, onh => 2, rew => 3, com => 4, drp => 5 ); }
print ".";

sub getOpts {
	# First hash key (when sorted) MUST be a label containing a key that corresponds to the INI Section for the options that follow it!
	# EACH Section needs a label conaining the Section name in the INI file where it resides.
	my %opts = (
		'000' => ['l',"General",'Main'],
		'001' => ['c',"Save window positions",'savepos'],
##		'002' => ['x',"Foreground color: ",'fgcol',"#00000"],
##		'003' => ['x',"Background color: ",'bgcol',"#CCCCCC"],
		'004' => ['c',"Errors are fatal",'fatalerr'],

		'005' => ['l',"Import/Export",'ImEx'],
		'008' => ['c',"Use Disambiguation/Filter list",'filterinput'],
		'006' => ['c',"Store tracking site credentials gleaned from imported XML",'gleanfromXML'],
##		'007' => ['s',"Update existing series names/epcounts from imported XML?",'importdiffnames',0,"never","ask","always"],

		'010' => ['l',"Database",'DB'],
		'011' => ['r',"Database type:",'type',0,'M','MySQL','L','SQLite'],
		'012' => ['t',"Server address:",'host'],
		'013' => ['t',"Login name (if required):",'user'],
		'014' => ['c',"Server requires password",'password'],
##		'01a' => ['c',"Update episode record with date on first change of episode"],
##		'019' => ['r',"Conservation priority",'conserve',0,'mem',"Memory",'net',"Network traffic (requires synchronization)"],
##		'015' => ['c',"Maintain extended information table",'exinfo'],
##		'01b' => ['r',"Use ID from:",'idauthority',0,'a',"AnimeDB",'m',"MAL",'h',"Hummingbird",'l',"Local (order of addition)"],

		'030' => ['l',"User Interface",'UI'],
##		'032' => ['c',"Shown episode is next unseen (not last seen)",'shownext'],
		'034' => ['c',"Notebook with tab for each status",'statustabs'],
##		'036' => ['c',"Put movies on a separate tab",'moviesapart'],
		'038' => ['s',"Notebook tab position: ",'tabson',1,"left","top","right","bottom"],
##		'039' => ['c',"Show suggestions tab",'suggtab'],
##		'03a' => ['c',"Show recent activity tab",'recenttab'],
##		'03b' => ['c',"Recent tab active on startup",'activerecent'],
		'03c' => ['c',"Show progress bar for each title's progress",'graphicprogress'],
		'03d' => ['x',"Header background color code: ",'headerbg',"#CCCCFF"],
		'03e' => ['c',"5-star scoring",'starscore'],
		'03f' => ['c',"Limit scores to discrete points",'intscore'],
		'040' => ['c',"Show count in section tables",'linenos'],
		'041' => ['c',"Refresh pages when title is moved",'moveredraw'],
##		'042' => ['c',"Move to active when changing parts seen",'incmove'],
		'043' => ['x',"Background for list tables",'listbg',"#EEF"],

		'050' => ['l',"Fonts",'Font'],
		'054' => ['f',"Tab font/size: ",'label'],
		'051' => ['f',"General font/size: ",'body'],
		'055' => ['f',"Special font/size: ",'special'], # for lack of a better term
		'052' => ['f',"Progress font/size: ",'progress'],
		'053' => ['f',"Progress Button font/size: ",'progbut'],
		'054' => ['f',"Major heading font/size: ",'bighead'],

		'070' => ['l',"Custom Text",'Custom'],
		'072' => ['t',"Anime:",'ani'],
		'073' => ['t',"Manga:",'man'],
		'071' => ['t',"POMAL:",'program'],
##		'074' => ['t',"Movies:",'mov'],
##		'075' => ['t',"Stand-alone Manga:",'sam'],
		'076' => ['t',"Options dialog",'options'],

		'077' => ['l',"Table",'Table'],
		'078' => ['c',"Statistics summary",'statsummary'],
		'079' => ['c',"Stats include median score",'withmedian'],
		'07f' => ['g',"Column Widths",'label'],
		'080' => ['n',"Row #s",'t1c0',21,0,800,1,10],
		'081' => ['n',"Rewatch/Move",'t1c1',140,0,800,1,10],
		'082' => ['n',"Progress",'t1c2',105,0,800,1,10],
		'083' => ['n',"Score",'t1c3',51,0,800,1,10],
#		'084' => ['n',"Tags",'t1c4',60,0,800,1,10],
#		'085' => ['n',"Column 5",'t1c5',0,0,800,1,10],
#		'086' => ['n',"View",'t1c6',60,0,800,1,10],
		'08a' => ['g',"Rows:",'label'],
		'08b' => ['n',"Height",'t1rowheight',60,0,600,1,10],

		'ff0' => ['l',"Debug Options",'Debug'],
		'ff1' => ['c',"Colored terminal output",'termcolors'],
	);
	return %opts;
}
print ".";

sub getRealID {
	my ($dbh,$target,$column,$table,$data) = @_;
	my $safetable = $dbh->quote_identifier($table);
	my $ids = passData('tableids');
	my @keys = @{ passData('tablekeys')->{$table} or [] };
	my $idkey = $$ids{$table};
	my $safeid = $dbh->quote_identifier($idkey);
	$column = $dbh->quote_identifier($column);
	$$data{extid} = $$data{$idkey};
	unless (defined $$data{extid}) {
		die "[E] getRealID couldn't find external ID#!\n";
	}
	my $idtable = 'bogus';
	$idtable = 'extsid' if $table eq 'series';
	$idtable = 'extpid' if $table eq 'pub';
	die "Bad table $table passed to getRealID! at " . lineNo() . "\n" if $table eq 'bogus';
	my $idtable = $dbh->quote_identifier($idtable);
	if (FlexSQL::doQuery(0,$dbh,"SELECT COUNT(*) FROM $idtable WHERE $column=?",$$data{extid})) { # check to see if sid already present in DB
		my $idnum = FlexSQL::doQuery(0,$dbh,"SELECT sid FROM $idtable WHERE $column=?",$$data{extid});
		print "[I] Found existing ID#$idnum..." if FIO::config('Debug','v') > 4;
		return (1,$idnum);
	} else {
# TODO: Before creating a new row, check for name to see if it was imported from another tracking site
# $data{$name} =~ m/([Tt]he )?([A-Za-z\w]+)/;
# $likename = $2;
# print "($1) '$2' ";
# $target->insert( Label => text => "Is one of the following shows the same as $data{$name}?" );
# yesnoXB($target);
		my $idnum = FlexSQL::getNewID($dbh,$safetable,$$data{$keys[0]},$$data{$keys[1]});
		my $err = FlexSQL::doQuery(2,$dbh,"INSERT INTO $idtable ($safeid,$column) VALUES (?,?)",$idnum,$$data{extid});
		die "Error: $err" if $error;
		print "[I] Gave new ID#$idnum to MAL title#$$data{extid}. " if FIO::config('Debug','v') > 4;
		return (0,$idnum);
	}
		#	my ($found,$realid) = Sui::getRealID($dbh,$table,\%data);
}
print ".";

sub addTags {
	my ($dbh,$key,$sid,@taglist) = @_;
	my $error = -1;
	unless (length "@taglist") { return 0; } # if no tags, no error
	unless (scalar @taglist > 1) { # see if taglist is a real array or just csv
		@taglist = split(/,/,"@taglist"); # if csv, split it into a real array
	}
	foreach my $t (@taglist) { # foreach tag
		$t =~ s/^\s+//; # trim leading space
		$t =~ s/\s+$//; # trim trailing space
		if (FIO::config('ImEx','filterinput')) { $t = Common::disambig($t); } # if so configured, check tag against ambiguity table
		my $st = "SELECT tid FROM tag WHERE text=?";
		my $result = FlexSQL::doQuery(0,$dbh,$st,$t); # check to see if the tag exists in the tag table
		unless ($result =~ m/^[0-9]+$/) { # if it doesn't, add it
#			print "Found tag: $result\n";
			my $cmd = "INSERT INTO tag (text) VALUES (?)";
			$result = FlexSQL::doQuery(2,$dbh,$cmd,$t);
			unless ($result == 1) { warn "Unexpected result: $result " . $dbh->errstr; (config('Main','fatalerr') ? PGUI::Gtkdie(PGUI::getGUI(mainWin),"Error in tag parser: $result") : next ); }
			$result = FlexSQL::doQuery(0,$dbh,$st,$t);
			if (not defined $result or $result eq "") { warn "Unexpected result ($result) after inserting tag: " . $dbh->errstr; (config('Main','fatalerr') ? PGUI::Gtkdie(PGUI::getGUI(mainWin),"Error in tag tie: $result") : next ); }
		}
		my $id = $result; # assign its ID to a variable
		$st = "SELECT tid FROM tags WHERE xid=? AND titletype=?";
		my @parms = ($sid,$key);
		$result = FlexSQL::doQuery(4,$dbh,$st,@parms);
		my $found = 0;
		foreach (@$result) {
			my @a = @$_;
			if ($a[0] == $id) { $found = 1; }
		}
		unless ($found) {
			my $cmd = "INSERT INTO tags (tid,xid,titletype) VALUES (?,?,?)"; # add a line in the tags table linking this tag with the series id in $sid and the key indicating the title type
			unshift @parms, $id;
			$result = FlexSQL::doQuery(2,$dbh,$cmd,@parms);
			# TODO: Error handling here
			$error = ($result == 1 ? 0 : 1); # prepare return result
			if (0) { print "Result of inserting tag '$t' ($id) for property $key:$sid is '$result'\n"; }
		} else {
			if (0) { print "Tag '$t' ($id) already associated with $key:$sid. Skipping.\n"; }
			else { print "="; }
			$error = 0;
		}
	}
	return $error; # return happiness
}
print ".";

sub getTableWidths {
	my @list = ((FIO::config('Table','t1c0') or 20));
	push(@list,(FIO::config('Table','t1c1') or 140));
	push(@list,(FIO::config('Table','t1c2') or 100));
	push(@list,(FIO::config('Table','t1c3') or 53));
	push(@list,(FIO::config('Table','t1c4') or 0));
	push(@list,(FIO::config('Table','t1c5') or 0));
	push(@list,(FIO::config('Table','t1c6') or 0));
	return @list;
}
print ".";

print "OK; ";
1;
