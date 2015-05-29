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
# print "[I] Connecting to $base\@$host as $username with " . ($password eq '' ? "no" : "a") . " password given.\n";
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
	my ($dbh,$widget) = @_;
	print "Creating tables...";
	open(TABDEF, "<$DBNAME.msq"); # open table definition file
	my @cmds = <TABDEF>;
	my $tot = scalar @cmds;
	print "\n[I] Importing $tot lines.";
	foreach my $i (0 .. $#cmds) {
		my $st = $cmds[$i];
#print $i + 1 . "$st\n";
		if ('SQLite' eq $dbh->{Driver}->{Name}) {
			next if ($st =~ m/^USE/); # SQLite doesn't (properly) support USE? WTH
			$st =~ s/ UNSIGNED//g; # ...or unsigned?
			$st =~ s/INT\(\d+\) PRIMARY KEY/INTEGER PRIMARY KEY/; #...or short integer keys?
			$st =~ s/ AUTO_INCREMENT/ AUTOINCREMENT/g; #...or auto_increment?
		}
		my $error = doQuery(2,$dbh,$st);
		$widget->text("Making tables... table " . $i + 1 . "/$tot" . ($error ? ": $st\n" : "" )) if defined $widget;
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
	print "Received '$statement' ",join(',',@parms),"\n" if (FIO::config('Debug','v') > 5);
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
		if ($$extra{idneeded}) { # for storing non autoincrement IDs
			push(@parms,$vals{$idcol});
			push(@cols,$idcol);
		}
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
		shift @keys if $$extras{rem1stcol}; # some updates do not use the first key
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

sub getNewID {
	my ($dbh,$table,$placeholder1,$placeholder2) = @_;
	unless (defined $placeholder1 and defined $placeholder2) { return 2,"ERROR","No placeholder values given to newID!"; }
	my %tablekeys = %{ Sui::passData('tablekeys') };
	my %ids = %{ Sui::passData('tableids') };
	return 1,"ERROR","Invalid and reserved table name 'undef' could not be used." if $table eq 'undef'; # Very funny, smarty pants DBA. Use a real name for your table.
	$table = 'undef' unless defined $table;
	$table =~ s/`//g; # in case user passed "safe" table name.
	my $cmd = "bogus"; # start by assuming table name is bogus vv
	foreach (keys %ids) { $cmd = $_ if $_ eq $table; } # ^^ If this is a valid table name worthy of being passed to SQL engine, it must be in the list we use to find IDs.
	if ($cmd eq "bogus") { return 1,"ERROR","Bogus table name $table passed to getNewID"; }
	my $idcol = $ids{$table}; # we just made sure this would work.
	my @keys = @{$tablekeys{$table}};
	$cmd = "INSERT INTO $table ($keys[0],$keys[1]) VALUES (?,?);";
	my @parms = ($placeholder1,$placeholder2);
	$error = doQuery(2,$dbh,$cmd,@parms);
	if ($error == 1) { # successfully added 1 row
		$cmd = "SELECT $idcol FROM $table WHERE $keys[0]=? AND $keys[1]=?";
		return FlexSQL::doQuery(0,$dbh,$cmd,@parms);
	} else {
die "An unhandled error $error occurred during getNewID.\n"; # Replace with actual error handling.
	}
}
print ".";

print " OK; ";
1;
