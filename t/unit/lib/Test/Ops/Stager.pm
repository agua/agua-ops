use MooseX::Declare;
use Method::Signatures::Simple;

class Test::Ops::Stager with (Test::Common, Ops::Stager, Util::Logger) {

use FindBin qw($Bin);
use Ops::Main;

has 'conf'			=> ( 
	is => 'rw', 
	isa => 'Conf::Yaml', 
	lazy => 1, 
	builder => "setConf" 
);

method setConf {
	my $conf 	= Conf::Yaml->new({
		backup		=>	1,
		log		=>	$self->log(),
		printlog	=>	$self->printlog()
	});
	
	$self->conf($conf);
}

method setUp () {
	#### SET LOG FILE
	my $logfile			=	"$Bin/outputs/incrementversion.log";
	$self->logfile($logfile);

	##### CREATE LOCAL REPOSITORY IN inputs DIRECTORY
	my $inputdir 	= 	"$Bin/inputs";
	my $repository	=	"testrepo";
	$self->setUpRepo($inputdir, $repository);
}

method cleanUp {
	#### REMOVE inputs REPOSITORY
	my $inputdir 		= 	"$Bin/inputs";
	my $repository		=	"testrepo";
	$self->setUpRepo($inputdir, $repository);
	`rm -fr $inputdir/$repository`;
	
	#### REMOVE outputs REPOSITORY
	my $outputdir 		= 	"$Bin/outputs";
	$self->setUpRepo($outputdir, $repository);
	`rm -fr $outputdir/$repository`;
}

method testRunStager {
	# #### SET UP REPO
	# $self->setUp();

	#### COPY OPSDIR AFRESH
	my $inputsdir	= "$Bin/inputs/testrepo";
	my $outputsdir	= "$Bin/outputs/testrepo";
	$self->setUpDirs($inputsdir, $outputsdir);

	#### SET LOG FILE
	my $logfile		=	"$Bin/outputs/runstager.log";
	$self->logfile($logfile);

	##### SET ARGUMENTS
	my $mode		=	"1-2";
	my $message		=	"TEST MULTILINE COMMIT MESSAGE - FIRST LINE
<EMPTY LINE>
<EMPTY LINE>
SECOND LINE
THIRD LINE
";
	
	my $version		=	"1.4.0";
	my $versiontype	=	undef;
	my $versionformat=	"semver";
	my $package		=	"biorepository";
	my $stagefile	=	"$Bin/inputs/stager.pm";
	my $branch		=	"master";
	my $outputdir	=	"$outputsdir/tmp";
	$self->logDebug("stagefile", $stagefile);	
	
	my $object = Ops::Main->new({
		conf					=>	$self->conf(),
		logfile     	=>   $logfile,
		log     			=>   $self->log(),
		printlog   		=>   $self->printlog(),

		version     	=>  $version,
		versiontype   =>  $versiontype,
		versionformat =>  $versionformat,
		branch        =>  $branch,
		package     	=>  $package,
		outputdir     =>  $outputdir
	});

	$object->stageRepo($stagefile, $mode, $message);	

	##### CLEAN UP
	# $self->cleanUp();
}

method setUpRepo ($repodir, $repository) {
	#### CLEAN OUT LOCAL REPO
	my $sourcedir = "$repodir/$repository";
	`rm -fr $sourcedir/* $sourcedir/.git` if -d $sourcedir;
	`mkdir -p $sourcedir` if not -d $sourcedir;

  #### CHANGE TO REPO DIR 
  $self->changeToRepo($sourcedir);
  
  #### INITIALISE REPO
  $self->initRepo($sourcedir);

  #### POPULATE REPO WITH FILES AND TAGS    
	my $versions = [	
		"1.0.0-alpha",
		"1.0.0-alpha.1",
		"1.0.0-beta.2",
		"1.0.0-beta.11",
		"1.0.0-rc.2",
		"1.0.0-rc.2+build.5",
		"1.0.0",
		"1.0.0+0.3.7",
		"1.3.7+build",
		"1.3.7+build.2.b8f12d7",
		"1.3.7+build.11.e0f985a"
	];

	for ( my $i = 0; $i < @$versions; $i++ ) {
    $self->toFile("$sourcedir/$$versions[$i]", $$versions[$i]);
    $self->addToRepo($sourcedir);
    $self->commitToRepo("Version $$versions[$i]");
    $self->addLocalTag($$versions[$i], "TAG $$versions[$i]");
  }
}

method cleanUp () {
	#### REMOVE inputs REPOSITORY
	my $inputdir 		= 	"$Bin/inputs";
	my $repository		=	"testrepo";
	$self->setUpRepo($inputdir, $repository);
	`rm -fr $inputdir/$repository`;
	
	#### REMOVE outputs REPOSITORY
	my $outputdir 		= 	"$Bin/outputs";
	$self->setUpRepo($outputdir, $repository);
	`rm -fr $outputdir/$repository`;
}


}