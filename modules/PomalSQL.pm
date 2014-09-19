# Module for MySQL database interactions (other DBs may be added later)
package PomalSQL;
print __PACKAGE__;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(getDB closeDB);

# DB wrappers that call SQL(ite) functions, depending on which the user has chosen to use for a backend.
my $dbh;
sub getDB {
	if (defined $dbh) { return $dbh; }
	my ($dbtype) = shift;
	use DBI;
	if ($dbtype eq "L") { # for people without access to a SQL server
		$dbh = DBI->connect( "dbi:SQLite:pomal.dbl" ) || return undef,"Cannot connect: $DBI::errstr";
	} elsif ($dbtype eq "M") {
		my $host = shift || 'localhost';
		my $base = shift || 'pomal';
		my $password = shift || '';
		my $username = shift || whoAmI();
		# connect to the database
		if ($password ne '') {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username, $password) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		} else {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		}
	} else { #bad/no DB type
		return undef,"Bad/no DB type passed to getDB! (" . ($dbtype or "undef") . ")";
	}
	return $dbh,"";
}
print ".";

sub closeDB {
	my $dbh = shift;
	$dbh->disconnect;
	print "Database closed.";
}
print ".";

sub whoAmI {
	return $ENV{LOGNAME} || $ENV{USER} || getpwuid($<); # try to get username by various means if not passed it.
}
print ".";

# functions for creating database
sub makeDB {
	my ($dbtype) = shift; # same prep work as regular connection...
	my $host = shift || 'localhost';
	my $base = shift || 'pomal';
	my $password = shift || '';
	my $username = shift || whoAmI();
	use DBI;
	my $dbh;
	print "Creating database...";
	if ($dbtype eq "L") { # for people without access to a SQL server
		$dbh = DBI->connect( "dbi:SQLite:pomal.dbl" ) || return undef,"Cannot connect: $DBI::errstr";
		my $newbase = $dbh->quote_identifier($base); # just in case...
		unless ($dbh->func("createdb", $newbase, 'admin')) { return undef,$DBI::errstr; }
	} elsif ($dbtype eq "M") {
		# connect to the database
		if ($password ne '') {
			$dbh = DBI->connect("DBI:mysql::$host",$username, $password) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		} else {
			$dbh = DBI->connect("DBI:mysql::$host",$username) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		}
		my $newbase = $dbh->quote_identifier($base); # just in case...
		unless(doQuery(2,$dbh,"CREATE DATABASE $newbase")) { return undef,$DBI::errstr; }
	}	
	print "Database created.";
	$dbh->disconnect();
	if ($dbtype eq "L") { # for people without access to a SQL server
		$dbh = DBI->connect( "dbi:SQLite:pomal.dbl" ) || return undef,"Cannot connect: $DBI::errstr";
	} elsif ($dbtype eq "M") {
		# connect to the database
		if ($password ne '') {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username, $password) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		} else {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		}
	}
	return $dbh,"OK";
}
print ".";

sub makeTables { # used for first run
	my ($dbh) = shift; # same prep work as regular connection...
	print "Creating tables...";
	open(TABDEF, "<pomal.msq"); # open table definition file
	my @cmds = <TABDEF>;
	print "Importing " . scalar @cmds . " lines.";
	foreach my $i (0 .. $#cmds) {
		my $st = $cmds[$i];
		if ('SQLite' eq $dbh->{Driver}->{Name}) {
			$st =~ s/ UNSIGNED//g; # SQLite doesn't (properly) support unsigned?
			$st =~ s/ AUTO_INCREMENT//g; #...or auto_increment?
		}
		my $error = doQuery(2,$dbh,$st);
#		print $i + 1 . ($error ? ": $st\n" : "" );
		print ".";
		if($error) { return undef,$error; }
	}
	my $st = qq(INSERT INTO series (sid,sname,lastwatched) VALUES(?,?,?););
	return $dbh,"OK";
}
print ".";

# functions for accessing database
sub doQuery {
	my ($qtype,$dbh,$statement,@parms) = @_;
	my $realq;
	print "Received '$statement' ",join(',',@parms),"\n";
	my $safeq = $dbh->prepare($statement);
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
			print "Required field not supplied for doQuery(3). Give field name to act as hash keys in final parameter.\n";
			return ();
		}
		my $key = pop(@parms);
		$safeq->execute(@parms);
		$realq = $safeq->fetchall_hashref($key);
	} elsif ($qtype == 4){
		$safeq->execute(@parms);
		$realq = $safeq->fetchall_arrayref();
	} elsif ($qtype == 5){
		$safeq->execute(@parms);
		$realq = $safeq->fetchrow_arrayref();
	} else {
		print "Invalid query type";
	}
	return $realq;
}
print ".";

sub table_exists {
	my ($dbh,$table) = @_;
	my $st = qq(SHOW TABLES LIKE ?;);
	if ('SQLite' eq $dbh->{Driver}->{Name}) { $st = qq(SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ?;); }
	my $result = doQuery(0,$dbh,$st,$table);
	return (length($result) == 0) ? 0 : 1;
}
print ".";

sub prepareFromHash {
	my ($href,$table,$update) = @_;
	my %tablekeys = (
		series => ['sname','episodes','lastwatched','started','ended','score','content','rating','lastrewatched','seentimes','status','note','stype'],
		pub => ['pname','volumes','chapters','lastread','started','ended','score','content','rating','lastreread','readtimes','status','note']
		# episode, volume, chapter?
	);
	my ($upcolor,$incolor,$basecolor) = ("","","");
	if ((FIO::config('Debug','termcolors') or 0)) {
		use Common qw( getColorsbyName );
		$upcolor = Common::getColorsbyName("yellow");
		$incolor = Common::getColorsbyName("purple");
		$basecolor = Common::getColorsbyName("base");
	}
	my %ids = ( series => "sid", pub => "pid");
	my $idcol = $ids{$table} or return 1,"ERROR","Bad table name passed to prepareFromHash";
	my %vals = %$href;
	my @parms;
	my $cmd = ($table eq "series" ? "series" : "pub");
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
		$cmd = "$cmd WHERE $idcol=$vals{$idcol}";
	}
	return 0,$cmd,@parms; # Normal completion
}
print ".";

sub addTags {
	my ($dbh,$key,$sid,@taglist) = @_;
	warn "This is only a dream. addTags is not really parsing your input. Sorry.";
	# see if taglist is a real array or just csv
	# if csv, split it into a real array
	# foreach tag
		# if so configured, check tag against ambiguity table
		# check to see if the tag exists in the tag table
		# if it doesn't, add it
		# assign its ID to a variable
		# add a line in the tags table linking this tag with the series id in $sid and the key indicating the title type
	# return happiness
}
print ".";

print " OK; ";
1;
