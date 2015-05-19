# Module for SQL database interactions (other DBs may be added later)
package FlexSQL;
print __PACKAGE__;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(getDB closeDB);

use FIO qw( config );
use Sui;

my $DBNAME = Sui::passData('dbname');
my $DBHOST = Sui::passData('dbhost');

# DB wrappers that call SQL(ite) functions, depending on which the user has chosen to use for a backend.
my $dbh;
Common::registerErrors('FlexSQL::getDB',"[E] Cannot connect: %s","[E] DBI error from connect: %s","[E] Bad/no DB type passed to getDB! (%s)");
Common::registerZero('FlexSQL::getDB',"[I] Database connection established.");
sub getDB {
	if (defined $dbh) { return $dbh; }
	my ($dbtype) = shift;
	if ($dbtype eq "0") { return undef; } # flag for not creating DB if not available
	unless (defined $dbtype) { $dbtype = FIO::config('DB','type'); } # try to save
	use DBI;
	if ($dbtype eq "L") { # for people without access to a SQL server
		my $host = shift || "$DBNAME.dbl";
		$dbh = DBI->connect( "dbi:SQLite:$host" ) || return undef,1,$DBI::errstr;
#		$dbh->do("SET NAMES 'utf8mb4'");
#		print "SQLite DB connected.\n";
	} elsif ($dbtype eq "M") {
		my $host = shift || "$DBHOST";
		my $base = shift || "$DBNAME";
		my $password = shift || '';
		my $username = shift || whoAmI();
		# connect to the database
		my $flags = { mysql_enable_utf8mb4 => 1 };
		if ($password ne '') {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username,$password,$flags) ||
				return undef,2,$DBI::errstr;
		} else {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username,undef,$flags) ||
				return undef,2,$DBI::errstr;
		}
		$dbh->do("SET NAMES 'UTF8MB4'");
	} else { #bad/no DB type
		return undef,3,($dbtype or "undef");
	}
	return $dbh,"";
}
print ".";

Common::registerZero('FlexSQL::closeDB',"[I] Database closed.");
=item closeDB HANDLE
Closes the database. If not given a HANDLE, gets the DB HANDLE from
getDB using a flag preventing creating just for closing.
=cut
sub closeDB {
	my $dbh = shift or getDB(0);
	if (defined $dbh) { $dbh->disconnect or die "[E] Disconnect from DB failed!\n"; }
	Common::errorOut('FlexSQL::closeDB',0,fatal => 0);
}
print ".";

sub whoAmI {
	if (($^O ne "darwin") && ($^O =~ m/[Ww]in/)) {
		print "Asking for Windows login...\n";
		my $canusewin32 = eval { require Win32; };
		return Win32::LoginName() if $canusewin32;
		return $ENV{USERNAME} || $ENV{LOGNAME} || $ENV{USER} || "player1";
	};
	return $ENV{LOGNAME} || $ENV{USER} || getpwuid($<); # try to get username by various means if not passed it.
}
print ".";

# functions for creating database
sub makeDB {
	my ($dbtype) = shift; # same prep work as regular connection...
	my $host = shift || ($dbtype eq 'L' ? "$DBNAME.dbl" : "$DBHOST");
	my $base = shift || "$DBNAME";
	my $password = shift || '';
	my $username = shift || whoAmI();
	use DBI;
	my $dbh;
	print "Creating database...";
	if ($dbtype eq "L") { # for people without access to a SQL server
		$dbh = DBI->connect( "dbi:SQLite:$host" ) || return undef,"Cannot connect: $DBI::errstr";
		my $newbase = $dbh->quote_identifier($base); # just in case...
		unless ($dbh->func("createdb", $newbase, 'admin')) { return undef,$DBI::errstr; }
	} elsif ($dbtype eq "M") {
		# connect to the database
		my $flags = { mysql_enable_utf8mb4 => 1 };
		if ($password ne '') {
			$dbh = DBI->connect("DBI:mysql::$host",$username, $password,$flags) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		} else {
			$dbh = DBI->connect("DBI:mysql::$host",$username,undef,$flags) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		}
		my $newbase = $dbh->quote_identifier($base); # just in case...
		unless(doQuery(2,$dbh,"CREATE DATABASE $newbase")) { return undef,$DBI::errstr; }
	}	
	print "Database created.";
	$dbh->disconnect();
	if ($dbtype eq "L") { # for people without access to a SQL server
		$dbh = DBI->connect( "dbi:SQLite:$host" ) || return undef,"Cannot connect: $DBI::errstr";
	} elsif ($dbtype eq "M") {
		# connect to the database
		my $flags = { mysql_enable_utf8mb4 => 1 };
		if ($password ne '') {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username,$password,$flags) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		} else {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username,undef,$flags) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		}
	}
	return $dbh,"OK";
}
print ".";

sub makeTables { # used for first run
	my ($dbh) = shift; # same prep work as regular connection...
	print "Creating tables...";
	open(TABDEF, "<$DBNAME.msq"); # open table definition file
	my @cmds = <TABDEF>;
	print "Importing " . scalar @cmds . " lines.";
	foreach my $i (0 .. $#cmds) {
		my $st = $cmds[$i];
		if ('SQLite' eq $dbh->{Driver}->{Name}) {
			next if ($st =~ m/^USE/); # SQLite doesn't (properly) support USE? WTH
			$st =~ s/ UNSIGNED//g; # ...or unsigned?
			$st =~ s/INT\(\d+\) PRIMARY KEY/INTEGER PRIMARY KEY/; #...or short integer keys?
			$st =~ s/ AUTO_INCREMENT/ AUTOINCREMENT/g; #...or auto_increment?
		}
		my $error = doQuery(2,$dbh,$st);
#		print $i + 1 . ($error ? ": $st\n" : "" );
		print ".";
		if($error) { return undef,$error; }
	}
	return $dbh,"OK";
}
print ".";

# functions for accessing database
sub doQuery {
	my ($qtype,$dbh,$statement,@parms) = @_;
	my $realq;
#	print "Received '$statement' ",join(',',@parms),"\n";
	unless (defined $dbh) {
		Pdie("Baka! Send me a database, if you want data.");
	}
	my $safeq = $dbh->prepare($statement) or print "\nCould not prepare $statement" . Common::lineNo() . "\n";
	if ($qtype == -1) { unless (defined $safeq) { return 0; } else { return 1; }} # prepare only
	unless (defined $safeq) { warn "Statement could not be prepared! Aborting statement!\n"; return undef; }
	if($qtype == 0){ # expect a scalar
		$realq = $safeq->execute(@parms);
		unless ("$realq" eq "1") {
#			print " result: $realq - ".$dbh->errstr;
			return "";
		}
		$realq = $safeq->fetchrow_arrayref();
		$realq = @{ $realq }[0];
	} elsif ($qtype == 1){
		$safeq->execute(@parms);
		$realq = $safeq->fetchall_arrayref({ Slice => {} });
	} elsif ($qtype == 2) {
		$realq = $safeq->execute(@parms); # just execute and return the result or the error
		if($realq =~ m/^[0-9]+$/) {
			return $realq; 
		} else {
			return $dbh->errstr;
		}
	} elsif ($qtype == 3){
		unless (@parms) {
			warn "Required field not supplied for doQuery(3). Give field name to act as hash keys in final parameter.\n";
			return ();
		}
		my $key = pop(@parms);
		$safeq->execute(@parms);
		$realq = $safeq->fetchall_hashref($key);
	} elsif ($qtype == 4){ # returns arrayref containing arrayref for each row
		$safeq->execute(@parms);
		$realq = $safeq->fetchall_arrayref();
	} elsif ($qtype == 5){
		$safeq->execute(@parms);
		$realq = $safeq->fetchrow_arrayref();
	} elsif ($qtype == 6){ # returns a single row in a hashref; use with a primary key!
		$safeq->execute(@parms);
		$realq = $safeq->fetchrow_hashref();
	} else {
		warn "Invalid query type";
	}
	return $realq;
}
print ".";

sub table_exists {
	my ($dbh,$table) = @_;
	my @table_list = $dbh->tables();
	my $pattern = '^`.+?`\.`(.+)`';
	if ('SQLite' eq $dbh->{Driver}->{Name}) {
		$pattern = '^"main"\."(.+)"$';
	}
	foreach (0..$#table_list) {
		$table_list[$_] =~ m/$pattern/;
		return 1 if ($1 eq $table);
	}
	return 0;
#	my $st = qq(SHOW TABLES LIKE ?;);
#	if ('SQLite' eq $dbh->{Driver}->{Name}) { $st = qq(SELECT tid FROM $table LIMIT 0); return doQuery(-1,$dbh,$st); }
#	if ('SQLite' eq $dbh->{Driver}->{Name}) { $st = qq(SHOW TABLES); }#return doQuery(-1,$dbh,$st); }
#	if ('SQLite' eq $dbh->{Driver}->{Name}) { $st = qq(PRAGMA table_info($table)); }
#	my $result = doQuery(0,$dbh,$st,$table);
#	my $result = doQuery(0,$dbh,$st);
#	return (length($result) == 0) ? 0 : 1;
}
print ".";

sub prepareFromHash {
	my ($href,$table,$update,$extra) = @_;
	my %tablekeys = %{ Sui::passData('tablekeys') };
	my ($upcolor,$incolor,$basecolor) = ("","","");
	if ((FIO::config('Debug','termcolors') or 0)) {
		use Common qw( getColorsbyName );
		$upcolor = Common::getColorsbyName("yellow");
		$incolor = Common::getColorsbyName("purple");
		$basecolor = Common::getColorsbyName("base");
	}
	my %ids = %{ Sui::passData('tableids') };
	my $idcol = $ids{$table} or return 1,"ERROR","Bad table name passed to prepareFromHash";
	my %vals = %$href;
	my @parms;
	my $cmd = "bogus"; # start by assuming table name is bogus vv
	foreach (keys %ids) { $cmd = $_ if $_ eq $table; } # ^^ If this is a valid table name worthy of being passed to SQL engine, it must be in the list we use to find IDs.
	if ($cmd eq "bogus") { return 1,"ERROR","Bogus table name passed to prepareFromHash"; }
	my @keys = @{$tablekeys{$table}};
	unless ($update) {
		my $valstxt = "VALUES (";
		$cmd = "INSERT INTO $cmd (";
		my @cols;
		push(@parms,$vals{$idcol});
		push(@cols,$idcol);
		print "$incolor";
		foreach (keys %vals) {
			unless (Common::findIn($_,@keys) < 0) {
				push(@cols,$_); # columns
				push(@parms,$vals{$_}); # parms
				print ".";
			}
		}
		print "$basecolor";
		unless(@parms) { return 2,"ERROR","No parameters were matched with column names."; }
		$cmd = "$cmd" . join(",",@cols);
		if(@cols) { $valstxt = "$valstxt?" . (",?" x $#cols) . ")"; }
		$cmd = "$cmd) $valstxt";
	} else {
		$cmd = "UPDATE $cmd SET ";
		print "$upcolor";
		foreach (keys %vals) {
			unless (Common::findIn($_,@keys) < 0) {
				$cmd = "$cmd$_=?, "; # columns
				push(@parms,$vals{$_}); # parms
				print ".";
			}
		}
		print "$basecolor";
		unless(@parms) { return 2,"ERROR","No parameters were matched with column names."; }
		$cmd = substr($cmd,0,length($cmd)-2); # trim final ", "
		$cmd = "$cmd WHERE $idcol=?";
		push(@parms,$vals{$idcol});
	}
	return 0,$cmd,@parms; # Normal completion
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
		if (config('ImEx','filterinput')) { $t = Common::disambig($t); } # if so configured, check tag against ambiguity table
		my $st = "SELECT tid FROM tag WHERE text=?";
		my $result = doQuery(0,$dbh,$st,$t); # check to see if the tag exists in the tag table
		unless ($result =~ m/^[0-9]+$/) { # if it doesn't, add it
#			print "Found tag: $result\n";
			my $cmd = "INSERT INTO tag (text) VALUES (?)";
			$result = doQuery(2,$dbh,$cmd,$t);
			unless ($result == 1) { warn "Unexpected result: $result " . $dbh->errstr; (config('Main','fatalerr') ? PGUI::Gtkdie(PGUI::getGUI(mainWin),"Error in tag parser: $result") : next ); }
			$result = doQuery(0,$dbh,$st,$t);
			if (not defined $result or $result eq "") { warn "Unexpected result ($result) after inserting tag: " . $dbh->errstr; (config('Main','fatalerr') ? PGUI::Gtkdie(PGUI::getGUI(mainWin),"Error in tag tie: $result") : next ); }
		}
		my $id = $result; # assign its ID to a variable
		$st = "SELECT tid FROM tags WHERE xid=? AND titletype=?";
		my @parms = ($sid,$key);
		$result = doQuery(4,$dbh,$st,@parms);
		my $found = 0;
		foreach (@$result) {
			my @a = @$_;
			if ($a[0] == $id) { $found = 1; }
		}
		unless ($found) {
			my $cmd = "INSERT INTO tags (tid,xid,titletype) VALUES (?,?,?)"; # add a line in the tags table linking this tag with the series id in $sid and the key indicating the title type
			unshift @parms, $id;
			$result = doQuery(2,$dbh,$cmd,@parms);
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

print " OK; ";
1;
