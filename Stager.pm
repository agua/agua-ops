use MooseX::Declare;
use Method::Signatures::Simple;

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

class Ops::Stager with Util::Logger {

#### INTERNAL
use Conf::Yaml;
use Ops::Repo;
use Ops::Info;

# String
has 'mode'			  => ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
has 'branch'			=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
has 'package'			=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
has 'message'			=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
has 'stagefile'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
has 'version'	    => ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'versiontype'	=> ( isa => 'Str|Undef', is => 'rw', required	=>	0 );
has 'versionfile'	=> ( isa => 'Str|Undef', is => 'rw', default	=>	"VERSION"	);
has 'versionformat'=> ( isa => 'Str', is  => 'rw', default	=>	'semver'	);
has 'outputdir'		=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
has 'releasename'	=> ( isa => 'Str|Undef', is => 'rw', required	=>	0	);
has 'opsmodloaded'=> ( isa => 'Bool|Undef', is => 'rw', default	=>	0	);

# Object
has 'stageconf'		=> (
	is =>	'rw',
	isa => 'Conf::Yaml'
);

has 'opsinfo'	=> ( 
	isa => 'Ops::Info',
	is => 'rw',
	required	=> 0
);

use FindBin qw($Bin);
use lib "$Bin/../..";

### TRANSFER FILES BETWEEN REPO STAGES 
method stageRepo ($stagefile, $mode, $message) {
	$self->stagefile($stagefile);
	$self->mode($mode);
	$self->message($message);
	
	$self->logDebug("stagefile", $stagefile);
	$self->logDebug("mode", $mode);
	$self->logDebug("message", $message);
	
	#### CHECK INPUTS
	$self->logDebug("DOING checkStagerInputs");
	$self->checkStagerInputs();

	#### SET UP STAGER
	$self->logDebug("DOING setUpStager");
	$self->setUpStager($stagefile, $mode);

	#### RUN STAGER
	my ($sourcerepo, $targetrepo);
	my ($start,$stop)	=	$mode	=~ /^(\d+)\-(\d+)$/;
	while ( ($stop - $start) >= 1) {
		my $end	=	$start + 1;		
		($sourcerepo, $targetrepo)	=	$self->runStager( $stagefile, "$start-$end", $message );
		$start++;
	}
	
	return ($sourcerepo, $targetrepo);
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
}

method getRepoInfo ( $mode, $stagefile ) {
	$self->logDebug("mode", $mode);
	
	my ($source, $target) = $mode =~ /^(\d+)-(\d+)$/;
	$self->logDebug("source", $source);
	$self->logDebug("target", $target);
	
	my $sourceinfo = {
		reponame 	=> $self->stageconf()->getKey("stage:$source:reponame"),
		basedir 	=> $self->stageconf()->getKey("stage:$source:basedir"),
		branch 		=> $self->stageconf()->getKey("stage:$source:branch")
	};
	my $targetinfo = {
		reponame 	=> $self->stageconf()->getKey("stage:$target:reponame"),
		basedir 	=> $self->stageconf()->getKey("stage:$target:basedir"),
		branch 		=> $self->stageconf()->getKey("stage:$target:branch")
	};

	my ($stagebase) = $stagefile =~ /^(.+?)\/[^\/]+$/;
	$self->logDebug("stagebase", $stagebase);
	if ( $sourceinfo->{basedir} !~ /^\// ) {
		$sourceinfo->{basedir} = "$stagebase/" . $sourceinfo->{basedir};
	}
	if ( $targetinfo->{basedir} !~ /^\// ) {
		$targetinfo->{basedir} = "$stagebase/" . $targetinfo->{basedir};
	}

	return ( $sourceinfo, $targetinfo );
}

method checkStagerInputs {
	$self->logNote("");

	my 	$mode 			= $self->mode();
	my 	$message 		= $self->message();
	my 	$stagefile 	= $self->stagefile();
	my  $version		= $self->version();
	my  $versiontype= $self->versiontype();
	my  $package 		= $self->package();
	my  $outputdir 	= $self->outputdir();
	my  $releasename= $self->releasename();

	$self->logError("mode not defined") and exit if not defined $mode;
	$self->logError("message not defined") and exit if not defined $message;
	$self->logError("stagefile not defined") and exit if not defined $stagefile;
	$self->logError("package not defined") and exit if not defined $package;
	$self->logNote("neither version nor versiontype are defined") and exit if not defined $version and not defined $versiontype;
	$self->logNote("both version and versiontype are defined") and exit if defined $version and defined $versiontype;
	$self->logNote("versiontype must be 'major', 'minor', 'patch' or 'build'") and exit if defined $versiontype and not $versiontype =~ /^(major|minor|patch|release|build)$/;
	$self->logNote("releasename must be 'alpha', 'beta', or 'rc'") and exit if defined $releasename and not $releasename =~ /^(alpha|beta|rc)$/;
}

#### RUN STAGER
method runStager ( $stagefile, $mode, $message ) {
	$self->logDebug("mode", $mode);
	# $self->logDebug("message", $message);

	#### SET SOURCE AND TARGET REPO
	my ( $sourceinfo, $targetinfo ) = $self->getRepoInfo( $mode, $stagefile );

	#### ADD LOG 
	$sourceinfo->{log} = $self->log();
	$targetinfo->{log} = $self->log();
	$sourceinfo->{printlog} = $self->printlog();
	$targetinfo->{printlog} = $self->printlog();

 	my $sourcerepo = Ops::Repo->new($sourceinfo);
 	my $targetrepo = Ops::Repo->new($targetinfo);
 	$self->logDebug("sourcerepo", $sourcerepo);
 	$self->logDebug("targetrepo", $targetrepo);

	#### CHECKOUT SOURCE BRANCH
	$sourcerepo->checkoutBranch($sourcerepo->branch());

	#### RUN *.pm MODULE FILE METHOD IF PRESENT
	$self->preSourceVersion($mode, $sourcerepo, $message) if $self->can('preSourceVersion');

	#### CREATE SOURCE VERSION AND COMMIT
	my $versionformat	=	$self->versionformat();	
	my $releasename		=	$self->releasename();
	my $versionfile		=	$sourcerepo->basedir() . "/VERSION";	
	my $sourcereponame=	$sourcerepo->reponame();
	my $sourcebranch	=	$sourcerepo->branch();
	my $targetreponame=	$targetrepo->reponame();
	my $outputdir	=	$self->outputdir();
	my $package		=	$self->package();
	my $version		=	$self->version();
	my $versiontype	=	$self->versiontype();

	#### CREATE VERSION FILE
	$version = $sourcerepo->createVersionFile(
		$sourcereponame, 
		$message, 
		$version, 
		$versiontype, 
		$versionformat, 
		$versionfile, 
		$sourcebranch, 
		$releasename
	);
	$self->logError("version is not defined") and exit if not defined $version;
	$self->logDebug("version", $version);
	$self->version($version);

	#### RUN pre-METHOD IF PRESENT IN *.pm MODULE FILE
	$self->preSourceCommit($mode, $sourcerepo, $version, $message) if $self->can('preSourceCommit');

	#### COMMIT SOURCE
	$sourcerepo->commitToRepo("[$version] $message");
	
	#### RUN pre-METHOD IF PRESENT IN *.pm MODULE FILE
	$self->preSourceTag($mode, $sourcerepo, $version, $message) if $self->can('preSourceTag');

	#### ADD SOURCE TAG
	$sourcerepo->addLocalTag($version, $message);
	
	#### RUN pre-METHOD IF PRESENT IN *.pm MODULE FILE
	$self->preSourceToTarget($mode, $sourcerepo, $version, $message) if $self->can('preSourceToTarget');

	##### EXPORT SOURCE TO TARGET
	$self->sourceToTarget($sourcerepo, $targetrepo);


	#### RUN pre-METHOD IF PRESENT IN *.pm MODULE FILE
	$self->preTargetCommit($mode, $targetrepo, $package) if $self->can('preTargetCommit');	

	#### COMMIT TARGET
 	$targetrepo->commitToRepo("[$version] $message");

	#### RUN pre-METHOD IF PRESENT IN *.pm MODULE FILE
	$self->preTargetTag($mode, $targetrepo, $version, $message) if $self->can('preTargetTag');

	#### ADD TARGET TAG
 	$targetrepo->addLocalTag($version, $message);
	
 	$self->logDebug("Completed");

 	return ($sourcerepo, $targetrepo);
}

method sourceToTarget ( $sourcerepo, $targetrepo ) {
	$self->logDebug("");
	
	#### CHECKOUT SOURCE BRANCH
	$sourcerepo->checkoutBranch( $sourcerepo->branch() );
	$self->logDebug("AFTER sourcerepo->checkoutBranch(branch)");

	#### CREATE TARGET REPO IF NOT EXISTS
	my $targetdir = $targetrepo->basedir();
	if ( not -d $targetdir ) {
		$targetrepo->createBasedir();
	}
	if ( not $targetrepo->isGitRepo() ) {
		$targetrepo->initRepo();
	}

	#### CHECKOUT TARGET BRANCH
	$self->logDebug("xxxxxxxxxxxxxxxxxxxxxxxxxxxxx DOING TARGET BRANCH");
	$targetrepo->createBranch( $targetrepo->branch() );
	$targetrepo->checkoutBranch( $targetrepo->branch() );
	$self->logDebug("AFTER targetrepo->checkoutBranch( $targetrepo->branch() )");

	#### DELETE FILES FROM TARGET (EXCEPT .git DIR)
	my $command = "rm -fr $targetdir/*";
	$self->logDebug("command", $command);
	$targetrepo->runCommand($command);

	$command = "git archive --format=tar HEAD | tar -x -C $targetdir";
	$self->logDebug("command", $command);
	$sourcerepo->runCommand($command);

	#### ADD CHANGES TO TARGET REPO
	$targetrepo->addToRepo();
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

method loadOpsModule ($opsdir, $repository) {
	$self->logDebug("opsdir", $opsdir);
	$self->logDebug("repository", $repository);

	return if not defined $opsdir;
	
	my $modulename = lc($repository);
	$modulename =~ s/[\-]+//g;
	# $self->logDebug("modulename", $modulename);

	my $pmfile 	= 	"$opsdir/$modulename.pm";
	# $self->logDebug("pmfile: $pmfile");
	
	if ( -f $pmfile ) {
		$self->logDebug("Found modulefile: $pmfile");
		# $self->logDebug("Doing require $modulename");
		unshift @INC, $opsdir;
		my ($olddir) = `pwd` =~ /^(\S+)/;
		$self->logDebug("olddir", $olddir);
		chdir($opsdir);
		eval "require $modulename";
		
		Moose::Util::apply_all_roles($self, $modulename);
	}
	else {
		$self->logDebug("\nCan't find modulefile: $pmfile\n");
		print "Deploy::setOps    Can't find pmfile: $pmfile\n";
		exit;
	}
	$self->opsmodloaded(1);
}

method loadOpsInfo ($opsdir, $package) {
	$self->logDebug("opsdir", $opsdir);
	$self->logDebug("package", $package);
	return if not defined $opsdir or not $opsdir;
	
	return if not defined $opsdir or not $opsdir;

	#### REMOVE -
	$package =~ s/[\-]+//g;
	$self->logDebug("package", $package);

	my $opsfile 	= 	"$opsdir/" . lc($package) . ".ops";
	$self->logDebug("opsfile: $opsfile");
	
	if ( -f $opsfile ) {
		$self->logDebug("Parsing opsfile");
		my $opsinfo = $self->setOpsInfo($opsfile);
		$self->logDebug("opsinfo", $opsinfo);
		$self->opsinfo($opsinfo);
		
		#### LOAD VALUES FROM INFO FILE
		$self->package($opsinfo->package()) if not defined $self->package();
		$self->repository($opsinfo->repository()) if not defined $self->repository();
		$self->version($opsinfo->version()) if not defined $self->version();

		#### SET PARAMS
		my $params = $self->opsfields();
		foreach my $param ( @$params ) {
			$self->logDebug("param", $param);
			$self->logDebug("self->$param()", $self->$param());
			if ( $self->can($param)
				and (not defined $self->$param()
					or  $self->$param() eq "" )
				and $self->opsinfo()->can($param)
				and defined $self->opsinfo()->$param() ) {
				$self->logDebug("Setting self->$param using opsinfo->$param", $self->opsinfo()->$param());
				$self->$param($self->opsinfo()->$param())
			}
		}
	}
	else {
		$self->logDebug("Can't find opsfile", $opsfile);		
	}
}

method getPwd {
	my $pwd = `pwd`;
	$pwd =~ s/\s+$//;

	return $pwd;
}

#### DEPRECATE

method archiveSource ($package, $sourcereponame, $outputdir) {
	my $versionfile		=	"$sourcereponame/VERSION";
	$self->logDebug("versionfile", $versionfile);
	$self->archiveRepo($package, $sourcereponame, $outputdir, $versionfile);
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

method expandArchive ($package, $targetreponame, $repofile) {
#### EXPAND ARCHIVE AND COPY TO PRODUCTION REPO
	$self->logDebug("package", $package);
	$self->logDebug("targetreponame", $targetreponame);
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


}
