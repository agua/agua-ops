package Ops::Stager;
use Moose::Role;
use Method::Signatures::Simple;

# #### EXTERNAL
# use JSON;

#### INTERNAL
use Conf::Yaml;

=head2

PACKAGE		Ops::Stager

PURPOSE

	A TOOL TO SIMPLIFY THE TASK OF STAGING FROM
	
	DEVEL --> PRODUCTION REPOSITORIES

	-   SIMPLE COMMAND TO STAGE ANY REPO
	
	-   ALLOW MULTILINE COMMIT MESSAGE

	-   stage.pm DOES FILE MANIPULATIONS, RENAMING, ETC.

	-   stage.conf (Agua::Conf FORMAT) STORES STAGE INFO

EXAMPLES
	
./stage.pl \
--stagefile /repos/private/syoung/biorepodev/stage.pm \
--mode 1-2 \
--message "First line
(EMPTY LINE)
(EMPTY LINE)
Second line
Third line"

=cut


# String
has 'mode'			=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
has 'stagefile'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
has 'versiontype'	=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'targetrepo'	=> ( isa => 'Str|Undef', is => 'rw', required	=> 	0	);
has 'sourcerepo'	=> ( isa => 'Str|Undef', is => 'rw', required	=> 	0	);
has 'targetbranch'=> ( isa => 'Str|Undef', is => 'rw', required	=> 	0	);
has 'sourcebranch'=> ( isa => 'Str|Undef', is => 'rw', required	=> 	0	);
has 'outputdir'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
has 'releasename'	=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
has 'versionfile'	=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);

# Object
has 'stageconf'		=> 	=> (
	is =>	'rw',
	isa => 'Conf::Yaml'
);

use FindBin qw($Bin);
use lib "$Bin/../..";

#### TRANSFER FILES BETWEEN REPO STAGES 
method stageRepo ($stagefile, $mode, $message) {
	$self->stagefile($stagefile);
	$self->mode($mode);
	$self->message($message);
	
	$self->logDebug("stagefile", $stagefile);
	$self->logDebug("mode", $mode);
	$self->logDebug("message", $message);

	#### SET UP STAGER
	$self->logDebug("DOING setUpStager");
	$self->setUpStager($stagefile, $mode);

	#### RUN STAGER
	my $version;
	my ($start,$stop)	=	$mode	=~ /^(\d+)\-(\d+)$/;
	while ( ($stop - $start) >= 1) {
		my $end	=	$start + 1;
		
		$self->logDebug("DOING runStager($start-$end, $message)");	
		$version	=	$self->runStager("$start-$end", $message);
		$start++;
	}
	
	return $version;
}

#### SET UP STAGER
method setUpStager ($stagefile, $mode) {

	my ($opsdir, $reponame) =	$stagefile =~ /^(.+?)\/([^\/]+).pm$/;
	$self->logDebug("opsdir", $opsdir);
	$self->logDebug("reponame", $reponame);
	
	#### LOAD OPS MODULE IF PRESENT
	$self->logDebug("self->opsmodloaded()", $self->opsmodloaded());
	$self->loadOpsModule($opsdir, $reponame) if not $self->opsmodloaded();

	#### LOAD OPS INFO IF PRESENT
	$self->loadOpsInfo($opsdir, $reponame) if not defined $self->opsinfo();

	#### LOAD OPS CONFIG IF PRESENT
	$self->loadOpsConfig($opsdir, $reponame) if not defined $self->opsinfo();

	#### PROCESS CONFIG DEFAULTS
	$self->parseStagerDefaults();	
}

method loadOpsConfig ($opsdir, $package) {
	$self->logDebug("opsdir", $opsdir);
	$self->logDebug("package", $package);
	my $configfile 	= 	"$opsdir/" . lc($package) . ".yml";
	$self->logDebug("configfile", $configfile);

	my $stageconf = Conf::Yaml->new({
		inputfile	=>	$configfile,
		log 			=>	$self->log(),
		printlog	=>	$self->printlog()
	});
	$self->stageconf($stageconf);
	$self->logDebug("stageconf", $stageconf);

	return $stageconf;
}

method parseStagerDefaults {
	my $keys = $self->stageconf()->getKeys("defaults");
	$self->logNote("keys", $keys);
	
	foreach my $key ( @$keys ) {
		my $value = $self->stageconf()->getKey("defaults", $key);
		my $slot = lc($key);
		$self->logNote("Doing self->$slot($value)");
		$self->$slot($value) if $self->can($slot);
	}
	#$self->logNote("self", $self);
}

method setRepoLocations ($mode) {
	$self->logDebug("mode", $mode);
	
	my ($source, $target) = $mode =~ /^(\d+)-(\d+)$/;
	$self->logDebug("source", $source);
	$self->logDebug("target", $target);
	
	my $sourcerepo = $self->stageconf()->getKey("stage:$source:repodir");
	my $targetrepo = $self->stageconf()->getKey("stage:$target:repodir");
	my $sourcebranch = $self->stageconf()->getKey("stage:$source:branch");
	my $targetbranch = $self->stageconf()->getKey("stage:$target:branch");
	$self->logDebug("sourcerepo", $sourcerepo);
	$self->logDebug("targetrepo", $targetrepo);
	$self->logDebug("sourcebranch", $sourcebranch);
	$self->logDebug("targetbranch", $targetbranch);

	$self->sourcerepo($sourcerepo) if not defined $self->sourcerepo();
	$self->targetrepo($targetrepo) if not defined $self->targetrepo();
	$self->sourcebranch($sourcebranch) if not defined $self->sourcebranch();
	$self->targetbranch($targetbranch) if not defined $self->targetbranch();

	return ( $sourcerepo, $targetrepo, $sourcebranch, $targetbranch );
}

method checkStagerInputs {
	$self->logNote("");

	my 	$mode 		= $self->mode();
	my 	$message 	= $self->message();
	my 	$stagefile 	= $self->stagefile();
	my 	$sourcerepo = $self->sourcerepo();
	my  $targetrepo = $self->targetrepo();
	my  $version	= $self->version();
	my  $versiontype= $self->versiontype();
	my  $package 	= $self->package();
	my  $outputdir 	= $self->outputdir();
	my  $releasename= $self->releasename();

	$self->logError("mode not defined") and exit if not defined $mode;
	$self->logError("message not defined") and exit if not defined $message;
	$self->logError("stagefile not defined") and exit if not defined $stagefile;

	$self->logError("targetrepo not defined") and exit if not defined $targetrepo;
	$self->logError("sourcerepo not defined") and exit if not defined $sourcerepo;
	$self->logError("package not defined") and exit if not defined $package;

	$self->logNote("neither version nor versiontype are defined") and exit if not defined $version and not defined $versiontype;
	$self->logNote("both version and versiontype are defined") and exit if defined $version and defined $versiontype;
	$self->logNote("versiontype must be 'major', 'minor', 'patch' or 'build'") and exit if defined $versiontype and not $versiontype =~ /^(major|minor|patch|release|build)$/;
	$self->logNote("releasename must be 'alpha', 'beta', or 'rc'") and exit if defined $releasename and not $releasename =~ /^(alpha|beta|rc)$/;
	
	$self->logNote("mode", $mode);
	$self->logNote("message", $message);
	$self->logNote("stagefile", $stagefile);
	$self->logNote("sourcerepo", $sourcerepo);
	$self->logNote("targetrepo", $targetrepo);
	$self->logNote("versiontype", $versiontype);
	$self->logNote("package", $package);
	$self->logNote("outputdir", $outputdir);
	$self->logNote("releasename", $releasename);
}

#### RUN STAGER
method runStager ($mode, $message) {
	$self->logDebug("mode", $mode);
	$self->logDebug("message", $message);

	$mode			=	$self->mode() if not defined $mode;
	$message 	=	$self->message() if not defined $message;

	#### SET SOURCE AND TARGET REPO LOCATIONS
	$self->setRepoLocations($mode);

	#### CHECK INPUTS
	$self->checkStagerInputs();

	my $stagefile	=	$self->stagefile();
	my ($basedir) = $stagefile =~ /^(.+?)\/[^\/]+$/;
	$self->logDebug("basedir", $basedir);
	$self->logDebug("mode", $mode);
	$self->logDebug("stagefile", $stagefile);
	$self->logDebug("message", $message);

	my $sourcerepo	=	$self->sourcerepo();
	my $targetrepo	=	$self->targetrepo();
	my $outputdir	=	$self->outputdir();
	my $package		=	$self->package();
	my $version		=	$self->version();
	my $versiontype	=	$self->versiontype();
	my $branch		=	$self->branch();

	#### COLLAPSE PATHS
	$sourcerepo = $self->sourcerepo($self->util()->collapsePath($sourcerepo));
	$targetrepo = $self->targetrepo($self->util()->collapsePath($targetrepo));

	#### CHECKOUT SOURCE BRANCH
	$self->checkoutBranch($sourcerepo, $branch);
	
	#### CREATE SOURCE VERSION AND COMMIT
	$self->preSourceVersion($mode, $sourcerepo, $message) if $self->can('preSourceVersion');
	($version) = $self->sourceVersion($sourcerepo, $message, $version, $versiontype);
	$self->logDebug("version", $version);
	$self->version($version);

	chdir($basedir);
	my $pwd = $self->getPwd();
	$self->logDebug("pwd", $pwd);

	#### COMMIT SOURCE
	$self->preSourceCommit($mode, $sourcerepo, $version, $message) if $self->can('preSourceCommit');
	$self->sourceCommit($sourcerepo, "[$version] $message", $package);
	
	#### ADD SOURCE TAG
	$self->preSourceTag($mode, $sourcerepo, $version, $message) if $self->can('preSourceTag');
	$self->sourceTag($sourcerepo, $version, $message);
	
	#### CREATE TARGET VERSION
	$self->preTargetVersion($mode, $targetrepo, $package) if $self->can('preTargetVersion');	
	$self->targetVersion($targetrepo, $message, $package);
	
	chdir($basedir);
	$pwd = $self->getPwd();
	$self->logDebug("pwd", $pwd);

	##### EXPORT SOURCE TO TARGET
	$self->preSourceToTarget($mode, $sourcerepo, $version, $message) if $self->can('preSourceToTarget');
	$self->sourceToTarget($package, $sourcerepo, $targetrepo, $branch);
	
	chdir($basedir);
	$pwd = $self->getPwd();
	$self->logDebug("pwd", $pwd);

exit;

	#### COMMIT TARGET
	$self->preTargetCommit($mode, $targetrepo, $package) if $self->can('preTargetCommit');	
	$self->targetCommit($targetrepo, "[$version] $message", $package);

	#### ADD TARGET TAG
	$self->preTargetTag($mode, $targetrepo, $version, $message) if $self->can('preTargetTag');
	$self->targetTag($targetrepo, $version, $message);

	$self->logDebug("Completed");
}


method sourceTag ($sourcerepo, $version, $message) {
	
	return $self->addTagToRepo($sourcerepo, $version, $message);
}

method targetTag ($targetrepo, $version, $message) {
	
	return $self->addTagToRepo($targetrepo, $version, $message);
}

method addTagToRepo ($repodir, $version, $message) {
#### ADD LOCAL TAG

	#### CHANGE TO REPO
	$self->changeToRepo($repodir);

	#### ADD TAG
	$self->addLocalTag($version, $message);

	#### CHANGE TO REPO
	$self->changeToRepo($repodir);

}

method sourceVersion ($sourcerepo, $message, $version, $versiontype) {
#### CREATE VERSION AND RELEASE
	my $versionformat	=	$self->versionformat();	
	my $branch			=	$self->branch();
	my $releasename		=	$self->releasename();
	my $versionfile		=	"VERSION";	

	$version = $self->createVersion($sourcerepo, $message, $version, $versiontype, $versionformat, $versionfile, $branch, $releasename);
	print "version:  $version\n";
	$self->logError("version is not defined") and exit if not defined $version;
	

	return $version;
}

method archiveSource ($package, $sourcerepo, $outputdir) {
	my $versionfile		=	"$sourcerepo/VERSION";
	$self->logDebug("versionfile", $versionfile);
	$self->archiveRepo($package, $sourcerepo, $outputdir, $versionfile);
}
	
method archiveRepo ($package, $repodir, $outputdir, $versionfile) {
	$self->logDebug("repodir", $repodir);
	$versionfile = "$repodir/VERSION" if not defined $versionfile;

	open(FILE, $versionfile) or die "Can't open versionfile: $versionfile\n";
	my $version = <FILE>;
	close(FILE) or die "Can't close versionfile: $versionfile\n";
	
	#### 1. GET THE COMMIT COUNT
	print "archive.pl   repodir is a file\n" and exit if -f $repodir;
	chdir($repodir) or die "Can't chdir to repodir: $repodir\n";
	
	#### 2. GET THE SHORT SHA KEY AS THE BUILD ID
	chdir($repodir) or die "Can't chdir to repodir: $repodir\n";
	my $buildid = `git rev-parse --short HEAD`;
	$buildid =~ s/\s+//g;
	
	#### 3. CREATE THE RELEASE DIR AND VERSION SUBDIR
	print "archive.pl   outputdir is a file\n" and exit if -f $outputdir;
	`mkdir -p $outputdir` if not -d $outputdir;
	print "archive.pl    Can't create outputdir: $outputdir\n" and exit if not -d $outputdir;

	#### 4. CREATE PACKAGE
	my $repofile = "$outputdir/$package.$version-$buildid.tar.gz";
	$self->logDebug("repofile", $repofile);
	my $archive = "git archive --format=tar --prefix=$package/ HEAD | gzip > $repofile";
	print "$archive\n";
	print `$archive`;

	return $repofile;
}

method expandArchive ($package, $targetrepo, $repofile) {
#### EXPAND ARCHIVE AND COPY TO PRODUCTION REPO
	$self->logDebug("package", $package);
	$self->logDebug("targetrepo", $targetrepo);
	$self->logDebug("repofile", $repofile);
	
	my $commands = [
		"cd /tmp; rm -fr /tmp/$package",
		"#### Doing tar xvfz $repofile",
		"cd /tmp; tar xvfz $repofile &> /dev/null",
		"rm -fr $repofile"
	];
	$self->logDebug("commands", $commands);

	foreach my $command ( @$commands ) {
		$self->runCommand($command);
	}
}

method targetUpdate ($targetrepo, $package) {
#### COPY EXPANDED ARCHIVE TO TARGET REPO AND COMMIT CHANGES
	$self->logDebug("targetrepo", $targetrepo);
	$self->logDebug("package", $package);
	
	my $commands = [
		"rm -fr $targetrepo/*"
		,
		"cp -pr /tmp/$package/* $targetrepo"
	];
	$self->logDebug("commands", $commands);
	foreach my $command ( @$commands ) {
		$self->runCommand($command);
	}
}

method targetCommit ($targetrepo, $message) {
	$self->logDebug("targetrepo", $targetrepo);
	$self->logDebug("message", $message);
	
	return $self->commitRepo($targetrepo, $message);
}

method sourceCommit ($sourcerepo, $message) {
	$self->logDebug("sourcerepo", $sourcerepo);
	# $self->logDebug("message", $message);
	
	return $self->commitRepo($sourcerepo, $message);
}

method commitRepo ($repodir, $message) {
#### COMMIT CHANGES
	$self->logDebug("repodir", $repodir);
	# $self->logDebug("message", $message);
	my $pwd = `pwd`;
	chomp($pwd);
	$self->logDebug("pwd", $pwd);

	chdir($repodir);
	my $command = "if [ ! -d .git ]; then git init; fi; git add .";
	$self->logDebug("command", $command);
	$self->runCommand($command);
	
	my $logfile = $self->logfile();
	$self->logDebug("logfile", $logfile);
	$command = "cd $repodir; git commit -a -m \"$message\" --cleanup=verbatim";
	$self->logDebug("command", $command);
	$self->runCommand($command);	
}

method targetVersion ($targetrepo, $message) {
#### 3. CREATE NEW PRODUCTION VERSION AND PUSH
	my $version			=	$self->version();
	my $versiontype		=	$self->versiontype();
	my $versionformat	=	$self->versionformat();	
	my $branch			=	$self->branch();
	my $releasename		=	$self->releasename();
	my $versionfile		=	"$targetrepo/VERSION";	

	my $output = $self->createVersion($targetrepo, $message, $version, $versiontype, $versionformat, $versionfile, $branch, $releasename);
}

method createVersion ($repodir, $message, $version, $versiontype, $versionformat, $versionfile, $branch, $releasename) {
#### CREATE/INCREMENT VERSION FILE AND ADD GIT TAG OF VERSION IN REPOSITORY

	$self->logDebug("repodir", $repodir);
	$self->logDebug("message", $message);
	$self->logDebug("version", $version);
	$self->logDebug("versiontype", $versiontype);
	$self->logDebug("versionfile", $versionfile);
	$self->logDebug("versionformat", $versionformat);
	$self->logDebug("branch", $branch);

	#### SET VERSION IF DEFINED
	if ( defined $version ) {
		my ($result, $error) = $self->setVersion($versionformat, $repodir, $versionfile, $branch, $version, $message);
		$self->logDebug("result", $result);
		$self->logDebug("error", $error);
		#print "\n\n$error\n\n" and exit if not $result;
		$self->logDebug("\nCreated new version: $version\n\n");
	}
	#### OTHERWISE, INCREMENT VERSION
	else {
		$version = $self->incrementVersion($versionformat, $versiontype, $repodir, $versionfile, $releasename, $message, $branch);
		$self->logDebug("Created new version", $version);
	}
	
	return $version
}

method sourceToTarget ($package, $sourcerepo, $targetrepo, $branch) {
	$self->logDebug("");
	
	#### CHECKOUT TARGET BRANCH
	$self->checkoutBranch($targetrepo, $branch);
	$self->logDebug("AFTER checkoutBranch($targetrepo, $branch)");

	#### CHECKOUT SOURCE BRANCH
	$self->checkoutBranch($sourcerepo, $branch);
	$self->logDebug("AFTER checkoutBranch($sourcerepo, $branch)");

	#### DELETE FILES FROM TARGET (EXCEPT .git DIR)
	my $command = "rm -fr $targetrepo/*";
	$self->logDebug("command", $command);
	$self->runCommand($command);

	my $pwd = $self->getPwd();
	chdir("$pwd/$sourcerepo");

	$command = "git archive --format=tar HEAD | tar -x -C $targetrepo";
	$self->logDebug("command", $command);
	$self->runCommand($command);

	chdir($pwd);
}

method getPwd {
	my $pwd = `pwd`;
	chomp($pwd);
	$self->logDebug("Returning pwd", $pwd);

	return $pwd;
}

method collapsePath ($string) {
	return if not defined $string;
	
	while ($string =~ s/\/[^\/^\.]+\/\.\.//g ) { }
	
	return $string;
}

method printToFile ($file, $text) {
	$self->logDebug("file", $file);

	$self->createParentDir($file);
	
	#### PRINT TO FILE
	open(OUT, ">$file") or $self->logCaller() and $self->logCritical("Can't open file: $file") and exit;
	print OUT $text;
	close(OUT) or $self->logCaller() and $self->logCritical("Can't close file: $file") and exit;	
}

method createParentDir ($file) {
	#### CREATE DIR IF NOT PRESENT
	my ($directory) = $file =~ /^(.+?)\/[^\/]+$/;
	$self->logDebug("directory", $directory);
	return if not defined $directory;
	
	`mkdir -p $directory` if $directory and not -d $directory;
	
	return -d $directory;
}





1;

