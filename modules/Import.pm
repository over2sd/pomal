# module(s) for importing XML/CSV/etc. data from other sources
package Import;
print __PACKAGE__;

use FIO;
sub config { return FIO::config(@_); }
print ".";

sub fromMAL {
	$|++;
	use XML::LibXML::Reader;
	my ($fn,$dbh,$returndata) = @_;
	my $xml = XML::LibXML::Reader->new(location => $fn)
		or return "Cannot read $fn!";
	unless (defined $dbh) { return "No database connections supplied!"; }
	my @list;
	my @statuslist = ('Plan to Watch','Watching','On-Hold','Rewatching','Completed','Dropped');
	my $termcolor = config('Debug','termcolors') or 0;
	use Common qw( getColorsbyName );
	my $infcol = ($termcolor ? Common::getColorsbyName("green") : "");
	my $basecol = ($termcolor ? Common::getColorsbyName("base") : "");
	my $anicol = ($termcolor ? Common::getColorsbyName("cyan") : "");
	my $mancol = ($termcolor ? Common::getColorsbyName("ltblue") : "");
	my %info;
	my $i = 0;
	my $loop = $xml->read();
	while ($loop == 1 and $i++ < 16) {
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
				my $table = 'series';
				my $node = $xml->copyCurrentNode(1);
				my %tags = (
					sid => "series_animedb_id",
					sname => "series_title",
					stype => "series_type",
					episodes => "series_episodes",
					_myid => "my_id",
					started => "my_start_date",
					ended => "my_finish_date",
					_fansub => "my_fansub_group",
					_rated => "my_rated", # no idea what this is
					score => "my_score",
					_dvd => "my_dvd",
					_store => "my_storage",
					status => "my_status",
					note => "my_comments",
					seentimes => "my_times_watched",
					_reval => "my_rewatch_value",
					_downep => "my_downloaded_eps",
					s_tags => "my_tags", # may need to be processed by a different algorithm
					s_rewa => "my_rewatching",
					lastwatched => "my_watched_episodes",
					lastrewatched => "my_rewatching_ep",
					_uoi => "update_on_import"
				);
				my %data;
				print ++$info{user_anime_found} . "/$info{user_total_anime} A";
				if ($termcolor) { print $anicol; }
				foreach (keys %tags) {
					$child = @{ $node->getChildrenByTagName($tags{$_}) or [] }[0];
					if (defined $child and $child->textContent() ne "") { print "."; $data{$_} = $child->textContent(); }
				}
				if ($termcolor) { print $basecol; }
				push(@list,$data{s_rewa});
				foreach (qw( started ended )) { # remove blank dates (if losing an existing date is actually desired, that should be done manually, or with a new function to be coded later)
					if ("0000-00-00" eq $data{$_}) { delete $data{$_}; }
				}
				if (defined $data{status}) { # convert status to numeric value for consistency
					$data{status} = Common::findIn($data{status},@statuslist);
				}
				if ($returndata) {
					push(@list,$data);
				} else {
				# prepare statement, parms
					my $safetable = $dbh->quote_identifier($table);
					my $found = PomalSQL::doQuery(0,$dbh,"SELECT COUNT(*) FROM $safetable WHERE sid=?",$data{sid}); # check to see if sid already present in DB
					if($found) {
						# config controls if user wants to update name and max episodes...
						my $clobber = (config('Main','importdiffnames') or "never");
						if ($clobber eq "ask") { #  ...or be asked before doing it
							warn "Ask to clobber not yet implemented. Assuming no.\n";
							$clobber = "never";
						}
						if ($clobber eq "never") {
							delete $data{sname}; 
							delete $data{episodes}; 
						}
					}
					my ($error,$cmd,@parms) = PomalSQL::prepareFromHash(\%data,$table,$found);
#					print "e: $error c: $cmd p: " . join(",",@parms) . "\n";
					# Insert/update row
					$error = PomalSQL::doQuery(2,$dbh,$cmd,@parms);
					# process tags and add them to the DB
#					$error = PomalSQL::addTags($dbh,'s',$sid,$data{s_tags});
					print " >$data{s_tags}< ";
				}
				$loop = $xml->next();
				print " ";
			} elsif (/^manga$/) {
				if ($termcolor) { print $mancol; }
				print "Manga tag!\n";
				if ($termcolor) { print $basecol; }
			} else {
				printf "\n%s %d %d <%s> %d\n", ($xml->value or "", $xml->depth,$xml->nodeType,$xml->name,$xml->isEmptyElement);
			}
		}
		$loop = $xml->read();
	}
	$|--;
	if ($returndata) { return @list; } else { return $loop; }
}
print ".";

print " OK; ";
1;
