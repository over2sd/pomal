# module for exporting database to XML/CSV/XHTML,etc. for archive or transmission purposes
package Export;
print __PACKAGE__;

use FIO qw( config );
use External qw( getTags );
print ".";

sub exportParts {
	my ($dbh,$gui,$whole) = @_;
	my $sb = PGK::getStatus();
#	my $filetowrite = FIO::getFileName(undef,$$gui{mainWin},$gui,"Choose an export filename",'save',"Export",[['XML data file (*.xml)' => '*.xml'],]);
	my $filetowrite = "export.xml";
	my %parts = ( 'series' => 'episode', 'pub' => 'chapter');
	my %keys = ('series' => 'sid', 'pub' => 'pid');
	my $k = ($keys{$whole} or undef);
	my $table = ($parts{$whole} or undef);
	my %ts = ('series' => 'e', 'pub' => 'c' );
	my $t = ($ts{$whole} or undef);
	unless (defined $table and defined $k and defined $t) {
		warn "exportParts must be passed a valid table name! (Received $whole)";
		$sb->text("Export failed!");
		return -1;
	}
	unless (defined $filetowrite) {
		warn "exportParts must have a valid filename to write to! (Received $filetowrite)";
		$sb->text("Export failed! (bad filename)");
		return -1;
	} else {
		print "Preparing to write $filetowrite...";
		$sb->text("Preparing to export...");
	}
	my $st = "SELECT $k FROM $table GROUP BY $k;";
	$dbh = FlexSQL::getDB() unless defined $dbh;
	my $res = FlexSQL::doQuery(7,$dbh,$st); # get an array of unique title IDs.
	unless ($res) {
		print "No part records with valid whole IDs were found. Aborting operation.\n";
		return -2;
	}
	require XML::LibXML;
	my $xmld = XML::LibXML::Document->new();
	my $root = $xmld->createElement('parts');
	$xmld->setDocumentElement($root);
	my $date = $xmld->createElement('export_date');
	$date->appendChild(XML::LibXML::Text->new(Common::today()));
	$root->appendChild($date);
	# get name of title
	my $cmd = sprintf("SELECT %s FROM %s WHERE $k=?;",($whole eq 'series' ? 'sname' : 'pname'),$whole);
	my $cmd2 = sprintf("SELECT %s FROM %s WHERE $k=?;",'score',$whole);
	foreach (@$res) {
		my $name = FlexSQL::doQuery(0,$dbh,$cmd,$_);
		$sb->text("Preparing $_:");
		print " $_:";
		next unless (defined $name and $name ne "");
		my $title = $xmld->createElement($whole);
		$root->appendChild($title);
		my $xname = $xmld->createElement('name');
		$xname->appendChild(XML::LibXML::Text->new($name));
		$title->appendChild($xname);
		my $score = FlexSQL::doQuery(0,$dbh,$cmd2,$_);
		next unless (defined $score and $score != 0);
		my $xscore = $xmld->createElement('score');
		$xscore->appendChild(XML::LibXML::Text->new($score));
		$title->appendChild($xscore);
		my ($a,$b,$c,$d) = ("${t}id","${t}name","first" . ($t eq 'e' ? 'watch' : 'read'),($t eq 'e' ? 'sid' : 'pid'));
		$st = "SELECT * FROM ext$d WHERE $d=?;";
		my $eres = FlexSQL::doQuery(6,$dbh,$st,$_);
		my %external = %$eres;
		foreach (keys %external) {
			next if ($_ eq $d); # skip because it's not needed by exported data
			next unless (defined $external{$_} and $external{$_} ne "");# skip because it's empty
			my $elem = $xmld->createElement($_);
			$elem->appendChild(XML::LibXML::Text->new($external{$_}));
			$title->appendChild($elem);
		}
		getParts($dbh,$xmld,$title,$sb,$table,$k,$a,$b,$c,$_);
		if ($table eq 'chapter') {
			getParts($dbh,$xmld,$title,$sb,'volume',$k,'vid','vname',$c,$_);
		}
	}
	print "writing.";
	open(my $o, '>', $filetowrite) or die "Could not open $filetowrite";
	print {$o} $xmld->toString(1);
	close $o;
	$sb->text("Export complete.");
	return 0;
}
print ".";

sub getParts { # do not call from anywhere that hasn't already done data sanitization of these variables.
	my ($dbh,$doc,$title,$sb,$table,$wholeidfield,$idfield,$namefield,$datefield,$wholeid) = @_;
# TODO: add volume field to chapter table? only if users demand it.
#	my $st = sprintf("SELECT %s%s,%s,rating,content,score,%s FROM $table WHERE $wholeidfield=?;",($table eq 'chapter' ? 'volume' : ''),$idfield,$datefield,$namefield);
	my $st = sprintf("SELECT %s,%s,rating,content,score,%s FROM $table WHERE $wholeidfield=?;",$idfield,$datefield,$namefield);
	my $res = FlexSQL::doQuery(3,$dbh,$st,$wholeid,$idfield);
	foreach my $row (values %$res) {
		my $xpar = $doc->createElement($table);
		$title->appendChild($xpar);
		foreach (keys %$row) {
			next unless (defined $$row{$_} and $$row{$_} ne ""); # skip if empty
			my $bit = $doc->createElement($_);
			$xpar->appendChild($bit);
			$bit->appendChild(XML::LibXML::Text->new($$row{$_}));
		}
		$sb->text($sb->text() . ".");
		print ".";
	}
	return 0;
}
print ".";

print " OK; ";
1;
