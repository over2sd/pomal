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
			pub => ['pname','volumes','chapters','lastreadc','lastreadv','started','ended','score','content','rating','lastreread','readtimes','status','note']
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
print "OK; ";
1;
