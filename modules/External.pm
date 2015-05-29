# module for dealing with external storage (not SQL DB), specifically, list tracking Web sites
# As such, this module will contain packages that refer to sites whose names, etc., do not belong to this project.
# These sites' names, etc., belong to their respective owners and are used her only for clarity and reference.
# No affiliation is implied or asserted between these sites and this project.



####### General Functions #######
package External;
print __PACKAGE__;

print ".";

sub getTags {
	my ($table) = @_;
	for ($table) {
		if (/MALa/) { return (
					foundkey => 'user_anime_found',
					totkey => 'user_total_anime',
					marker => "A",
					idkey => 'sid',
					namekey => 'sname',
					partkey => 'episodes',
					tagkey => 's_tags',
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
					statuslist => ['Plan to Watch','Watching','On-Hold','Rewatching','Completed','Dropped'],
					note => "my_comments",
					seentimes => "my_times_watched",
					_reval => "my_rewatch_value",
					_downep => "my_downloaded_eps",
					s_tags => "my_tags", # may need to be processed by a different algorithm
					s_rewa => "my_rewatching",
					lastwatched => "my_watched_episodes",
					lastrewatched => "my_rewatching_ep",
					_uoi => "update_on_import",
					idtable => "extsid",
				);
			} elsif (/MALm/) { return (
					foundkey => 'user_manga_found',
					totkey => 'user_total_manga',
					marker => "M",
					idkey => 'pid',
					namekey => 'pname',
					partkey => 'chapters',
					tagkey => 'p_tags',
					pid => "manga_mangadb_id",
					pname => "manga_title",
					volumes => "manga_volumes",
					chapters => "manga_chapters",
					_myid => "my_id",
					lastreadv => "my_read_volumes",
					lastreadc => "my_read_chapters",
					started => "my_start_date",
					ended => "my_finish_date",
					_scangroup => "my_scanlation_group",
					score => "my_score",
					_storage => "my_storage",
					status => "my_status",
					statuslist => ['Plan to Read','Reading','On-Hold','Rereading','Completed','Dropped'],
					note => "my_comments",
					readtimes => "my_times_read",
					_reval => "my_reread_value",
					_uoi => "update_on_import",
					idtable => "extpid",
				);
			}
	}
	return ();
}
print ".";

sub getFileFilters {
	return [
			['MAL title list (*.xml,*.xml.gz)' => '*.xml;*.xml.gz'],
			['Uncompressed MAL title list (*.xml)' => '*.xml'],
			['Compressed MAL title list (*.xml.gz)' => '*.xml.gz'],
			['Hummingbird title list (*.json)' => '*.json'],
			['Comma Separated Values (*.csv)' => '*.csv'],
		];
};

print " OK; ";
1;
