# module(s) for importing XML/CSV/etc. data from other sources, particularly anime tracking Web sites
# As such, this module will contain packages that refer to sites whose names, etc., do not belong to this project.
# These sites' names, etc., belong to their respective owners and are used her only for clarity and reference.
# No affiliation is implied or asserted between these sites and this project.

package Import;
print __PACKAGE__;

use FIO;
sub config { return FIO::config(@_); }
use External qw( getTags );
print ".";

sub importXML {
	my ($dbh,$gui) = @_;
	my $filetoopen = FIO::getFileName(undef,$$gui{mainWin},$gui,"Choose a file to import",'open',"Import","*.xml*");
	my $res;
	if (defined $filetoopen) {
		PGUI::Gtkwait(1.5); # let the dialog box close before dominating the processor...
		for ($filetoopen) {
			if (/animelist/ or /mangalist/) { $res = Import::fromMALgz($filetoopen,$dbh,$gui); }
		}
		if ($res == 0) {
			$$gui{status}->push(0,"Import complete.");
		} else {
			$$gui{status}->push(0,"Import failed.");
		}
	} else {
		$res = -1;
	}
	return $res; # 0 success
}
print ".";

sub fromMALgz {
	my ($fn,$dbh,$gui,$returndata) = @_;
	my $ufn = $fn; # for if it's not compressed
	if ($fn =~ m/\.gz$/) {
		$ufn =~ s/\.gz//; # if it is compressed, drop compression extension
		print "\nAttempting to unzip $fn\n";
		$$gui{status}->push(0,"Attempting to unzip $fn");
		FIO::gz_decom($fn,$ufn,$gui) or return -1;
	}
	return fromMAL($ufn,$dbh,$gui,$returndata);
}
print ".";

sub fromMAL {
	$|++;
	use XML::LibXML::Reader;
	my ($fn,$dbh,$gui,$returndata) = @_;
	my $xml = XML::LibXML::Reader->new(location => $fn)
		or return "Cannot read $fn!";
	unless (defined $dbh) { return "No database connections supplied!"; }
	$$gui{status}->push(0,"Attempting to import $fn to database...");
	my $storecount = 0; my $upcount = 0;
	my @list;
	my $termcolor = config('Debug','termcolors') or 0;
	use Common qw( getColorsbyName );
	my $infcol = ($termcolor ? Common::getColorsbyName("green") : "");
	my $basecol = ($termcolor ? Common::getColorsbyName("base") : "");
	my $anicol = ($termcolor ? Common::getColorsbyName("cyan") : "");
	my $mancol = ($termcolor ? Common::getColorsbyName("ltblue") : "");
	my %info;
	my $i = 0;
	my $loop = $xml->read();
	# these two hashes determine the hash key under which each XML tag will be stored:
	my %anitags = External::getTags('MALa');
	my %mantags = External::getTags('MALm');
	while ($loop == 1) {
		if ($xml->nodeType() == 8) { print "\nComment in XML: " . $xml->value() . "\n"; $loop = $xml->next(); next; } # print comments and skip processing
		if ($xml->nodeType() == 13 or $xml->nodeType() == 14 or $xml->name() eq "myanimelist") { $i--; $loop = $xml->read(); next; } # skip whitespace (and root node)
		for ($xml->name()) {
			if(/^myinfo$/) {
				print "Info ";
				my $node = $xml->copyCurrentNode(1);
				my @infonodes = $node->getChildrenByTagName("*");
				my $glean = config('Main','gleanXML');
				if ($termcolor) { print $infcol; }
				foreach (@infonodes) {
					print ".";
					$info{$_->nodeName()} = $_->textContent();
					unless ($glean) { next; } # skip storing info in config
					print "Storing info.\n";
					config('MAL',$_->nodeName(),$_->textContent());
				}
				if ($termcolor) { print $basecol; }
				if ($glean) { FIO::saveConf(); } # save INI
				$loop = $xml->next();
				print "\n";
			} elsif (/^anime$/) {
				my $node = $xml->copyCurrentNode(1);
				my ($updated,$error) = storeMAL($gui,$dbh,'series',$node,$termcolor,$anicol,\%info,%anitags);
				unless ($error) { $storecount++; $upcount += $updated; } # increase count of titles successfully stored (inserted or updated)
				if ($returndata) { push(@list,$res); }
				$loop = $xml->next();
				print " ";
			} elsif (/^manga$/) {
				my $node = $xml->copyCurrentNode(1);
				my ($updated,$error) = storeMAL($gui,$dbh,'pub',$node,$termcolor,$mancol,\%info,%mantags);
				unless ($error) { $storecount++; $upcount += $updated; } # increase count of titles successfully stored (inserted or updated)
				if ($returndata) { push(@list,$res); }
				$loop = $xml->next();
				print " ";
			} else {
				printf "\n%s %d %d <%s> %d\n", ($xml->value or "", $xml->depth,$xml->nodeType,$xml->name,$xml->isEmptyElement);
			}
		}
		$loop = $xml->read();
	}
	$|--;
	$$gui{status}->push(0,"Successfully imported $storecount titles to database ($upcount updated)...");
	PGUI::sayBox(PGUI::getGUI(mainWin),"Successfully imported $storecount titles to database ($upcount updated)...");
	if ($returndata) { return @list; } else { return $loop; }
}
print ".";

sub storeMAL {
	my ($gui,$dbh,$table,$node,$termcolor,$thiscol,$info,%tags) = @_;
	my $basecol = ($termcolor ? Common::getColorsbyName("base") : "");
	my %data;
	print "\n" . ++$$info{$tags{foundkey}} . "/$$info{$tags{totkey}} " . ($table eq 'series' ? "A" : "M");
	$$gui{status}->push(0,"Attempting to import $$info{$tags{foundkey}}/$$info{$tags{totkey}} anime to database...");
	if ($termcolor) { print $thiscol; }
	foreach (keys %tags) {
		$child = @{ $node->getChildrenByTagName($tags{$_}) or [] }[0];
		if (defined $child and $child->textContent() ne "") { print "."; $data{$_} = $child->textContent(); }
	}
	if ($termcolor) { print $basecol; }
	foreach (qw( started ended )) { # remove blank dates (if losing an existing date is actually desired, that should be done manually, or with a new function to be coded later)
		if ("0000-00-00" eq $data{$_}) { delete $data{$_}; }
	}
	if (defined $data{status}) { # convert status to numeric value for consistency
		$data{status} = Common::findIn($data{status},@{$tags{statuslist}});
		if (0) { print "Stat: $data{status} "; }
	}
	if ($returndata) {
		return \%data;
	} else {
		unless (defined $dbh) {
			$dbh = PomalSQL::getDB(); # attempt to pull existing DBH
		}
		unless (defined $dbh) { # if that failed, I have to die.
			my $win = getGUI(mainWin);
			dieWithErrorbox($win,"storeMAL was not passed a database handler!");
		}
		# prepare statement, parms
		my $safetable = $dbh->quote_identifier($table);
		my $safeid = $dbh->quote_identifier($tags{idkey});
		my $found = PomalSQL::doQuery(0,$dbh,"SELECT COUNT(*) FROM $safetable WHERE $safeid=?",$data{$tags{idkey}}); # check to see if sid already present in DB
		if($found) {
			# config controls if user wants to update name and max episodes...
			my $clobber = (config('Main','importdiffnames') or "never");
			if ($clobber eq "ask") { #  ...or be asked before doing it
				warn "Ask to clobber not yet implemented. Assuming no.\n";
				$clobber = "never";
			}
			if ($clobber eq "never") {
				delete $data{$tags{namekey}}; 
				delete $data{$tags{partkey}}; 
			}
		}
		$data{score} *= 10; # move from 10-point to 100-point scale
		my ($error,$cmd,@parms) = PomalSQL::prepareFromHash(\%data,$table,$found);
		if (0) { print "e: $error c: $cmd p: " . join(",",@parms) . "\n"; }
		# Insert/update row
		$error = PomalSQL::doQuery(2,$dbh,$cmd,@parms);
		# process tags and add them to the DB
		$error = PomalSQL::addTags($dbh,substr($table,0,1),$data{$tags{idkey}},$data{$tags{tagkey}});
		return $found,$error;
	}
}
print ".";

print " OK; ";
1;
