use MooseX::Declare;
use Method::Signatures::Simple;

class Test::Ops::Version with (Test::Common, Test::Ops::Common) extends Ops::Main {

use Data::Dumper;
use Test::More;
use DBase::Factory;
use Ops::Main;
use Engine::Instance;
use Conf::Yaml;
use FindBin qw($Bin);

# Int
has 'log'		=>  ( isa => 'Int', is => 'rw', default => 2 );  
has 'printlog'		=>  ( isa => 'Int', is => 'rw', default => 5 );

# String
has 'logfile'       => ( isa => 'Str|Undef', is => 'rw' );

method setUp () {
	#### SET LOG FILE
	my $logfile			=	"$Bin/outputs/incrementversion.log";
	$self->logfile($logfile);

	##### CREATE LOCAL REPOSITORY IN inputs DIRECTORY
	my $inputdir 	= 	"$Bin/inputs";
	my $repository	=	"testrepo";
	$self->setUpRepo($inputdir, $repository);
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


#### UNIT
method testHigherSemVer () {
	ok($self->higherSemVer("0.7.2", "0.6.0") == 1, "compare 0.7.2 and 0.6.0");
	ok($self->higherSemVer("0.6.0", "0.6.1") == -1, "compare 0.6.0 and 0.6.1");
	ok($self->higherSemVer("0.6.0", "0.6.0+build.1") == -1, "compare 0.6.0 and 0.6.0+build.1");
	ok($self->higherSemVer("0.6.0", "0.6.0-alpha.1") == 1, "compare 0.6.0 and 0.6.0-alpha.1");
}

method testVersionSort {
	diag("Test versionSort");
	$self->versionSort_build();
	$self->versionSort_versions1();
	$self->versionSort_versions2();
	$self->versionSort_versions3();
	$self->versionSort_build_permutations();
	$self->versionSort_build_vs_release();
	$self->versionSort_composite_permutations();
	$self->versionSort_alpha_vs_build();
}

method versionSort_build {
	my $versions = [
		"0.8.0-alpha.1+build2",
		"0.8.0-alpha.1+build.7",
		"0.8.0-beta.1+build.10",
		"0.8.0-beta.1+build.11",
		"0.8.0-beta.1+build.12",
		"0.7.6+build3",
		"0.7.6+build1",
		"0.7.5+build5"
	];

	my $correct = [
		"0.7.5+build5",
		"0.7.6+build1",
		"0.7.6+build3",
		"0.8.0-alpha.1+build2",
		"0.8.0-alpha.1+build.7",
		"0.8.0-beta.1+build.10",
		"0.8.0-beta.1+build.11",
		"0.8.0-beta.1+build.12"
	];
	my $output = $self->sortVersions($versions);
	#$self->logDebug("output", $output);
	#$self->logDebug("correct", $correct);
	ok($self->arraysHaveSameOrder($output, $correct), "versionSort    versions 1: @$versions");
}

method versionSort_versions1 {
	my $versions = [ "1.0.0", "0.8.0", "0.9.1", "0.11.0" ];
	my $correct = ["0.8.0","0.9.1","0.11.0","1.0.0"];
	my $output = $self->sortVersions($versions);
	#$self->logDebug("output", $output);
	#$self->logDebug("correct", $correct);
	ok($self->arraysHaveSameOrder($output, $correct), "versionSort    versions 1: @$versions");
}

method versionSort_versions2 {
	my $versions = [ "1.0.0", "0.8.0", "0.9.1", "0.11.0", "12.0.0", "2.0.0" ];
	my $correct = ["0.8.0","0.9.1","0.11.0","1.0.0","2.0.0","12.0.0"];
	my $output = $self->sortVersions($versions);
	#$self->logDebug("output", $output);
	ok($self->arraysHaveSameOrder($output, $correct), "versionSort    versions 2: @$versions");
}

method versionSort_versions3 {
	my $versions = [
		"2.0.0",
		"1.0.0+build1",
		'1.3.7+build.1',
		'1.3.7+build.11.e0f985a',
		'1.3.7+build.2.b8f12d7',
		"1.0.0"
	];

	my $correct = [
		"1.0.0",
		"1.0.0+build1",
		'1.3.7+build.1',
		'1.3.7+build.2.b8f12d7',
		'1.3.7+build.11.e0f985a',
		"2.0.0"
	];

	my $output = $self->sortVersions($versions);
	#$self->logDebug("output", $output);
	#$self->logDebug("correct", $correct);
	ok($self->arraysHaveSameOrder($output, $correct), "versionSort    versions 3: @$versions");
}

method versionSort_build_permutations {
#### BUILDS: 3 DIFFERENT ORDER PERMUTATIONS:
	#### 1
	my $versions = [ "0.8.0+build11", "0.8.0+build1", "0.8.0+build2" ];
	my $correct = ["0.8.0+build1","0.8.0+build2","0.8.0+build11"];
	my $output = $self->sortVersions($versions);
	#$self->logDebug("output", $output);
	ok($self->arraysHaveSameOrder($output, $correct), "versionSort    build permutations: @$output");
	
	#### 2
	$versions = ["0.8.0+build1", "0.8.0+build2",  "0.8.0+build11" ];
	$correct = ["0.8.0+build1","0.8.0+build2","0.8.0+build11"];
	$output = $self->sortVersions($versions);
	#$self->logDebug("output", $output);
	ok($self->arraysHaveSameOrder($output, $correct), "versionSort    build permutations: @$output");
	
	#### 3
	$versions = [ "0.8.0+build1", "0.8.0+build11", "0.8.0+build2" ];
	$correct = ["0.8.0+build1","0.8.0+build2","0.8.0+build11"];
	$output = $self->sortVersions($versions);
	#$self->logDebug("output", $output);
	ok($self->arraysHaveSameOrder($output, $correct), "versionSort    build permutations: @$output");
}

method versionSort_build_vs_release {
	#### BUILD VERSUS RELEASE
	my $versions = [ "0.8.0-rc2", "0.8.0+build11" ];
	my $correct = ["0.8.0-rc2", "0.8.0+build11"];
	my $output = $self->sortVersions($versions);
	#$self->logDebug("output", $output);
	ok($self->arraysHaveSameOrder($output, $correct), "versionSort    build vs release: @$output");
}

method versionSort_alpha_vs_build {
	#### BUILD VERSUS RELEASE
	my $versions = [ "0.8.0-beta.1+build.1", "0.8.0-beta.1", "0.8.0-alpha.1+build.1", "0.8.0-alpha.1" ];
	my $correct = [ "0.8.0-alpha.1", "0.8.0-alpha.1+build.1", "0.8.0-beta.1", "0.8.0-beta.1+build.1" ];
	my $output = $self->sortVersions($versions);
	ok($self->arraysHaveSameOrder($output, $correct), "versionSort    build vs release: @$output");
}

method versionSort_composite_permutations {
	#### COMPOSITE: MIXTURE OF VERSIONS, RELEASES AND BUILDS IN 3 PERMUTATIONS
	my $versions = [ "1.0.0", "0.8.0", "0.9.1", "0.11.0", "12.0.0", "2.0.0", "0.8.0-alpha", "0.8.0-alpha.1", "0.8.0-beta", "0.8.0-rc2", "0.8.0+build11", "0.8.0+build1" ];
	 my $correct = ["0.8.0-alpha","0.8.0-alpha.1","0.8.0-beta","0.8.0-rc2", "0.8.0","0.8.0+build1","0.8.0+build11", "0.9.1","0.11.0","1.0.0","2.0.0","12.0.0"];
	my $output = $self->sortVersions($versions);
	#$self->logDebug("output", $output);
	ok($self->arraysHaveSameOrder($output, $correct), "versionSort    composite permutations: @$output");
	
	$versions = [ "2.0.0",  "0.8.0+build11", "0.8.0+build1", "0.8.0-alpha", "0.8.0-alpha.1", "0.8.0-beta", "0.8.0-rc2", "1.0.0", "0.8.0", "0.9.1", "0.11.0", "12.0.0" ];
	$correct = ["0.8.0-alpha","0.8.0-alpha.1","0.8.0-beta","0.8.0-rc2","0.8.0","0.8.0+build1","0.8.0+build11","0.9.1","0.11.0","1.0.0","2.0.0","12.0.0"];
	$output = $self->sortVersions($versions);
	#$self->logDebug("output", $output);
	ok($self->arraysHaveSameOrder($output, $correct), "versionSort    composite permutations: @$output");
	
	$versions = [ "0.8.0-alpha", "0.8.0-alpha.1",  "0.8.0-alpha.12",  "0.8.0-alpha.2",  "0.8.0-beta", "0.8.0-rc2", "0.8.0+build11", "0.8.0+build1", "0.8.0+build2" ];
	$correct = ["0.8.0-alpha","0.8.0-alpha.1","0.8.0-alpha.2","0.8.0-alpha.12","0.8.0-beta","0.8.0-rc2", "0.8.0+build1","0.8.0+build2","0.8.0+build11"];
	$output = $self->sortVersions($versions);
	#$self->logDebug("output", $output);
	ok($self->arraysHaveSameOrder($output, $correct), "versionSort    composite permutations: @$output");
}

method testParseSemVer {
	diag("Test parseSemVer");

	my $versions = [	
		"1.0.0-alpha",
		"1.0.0-alpha.1",
		"1.0.0-beta.2",
		"1.0.0-beta.11",
		"1.0.0-rc.1",
		"1.0.0-rc.1+build.1",
		"1.0.0",
		"1.0.0+0.3.7",
		"1.3.7+build",
		"1.3.7+build.2.b8f12d7",
		"1.3.7+build.11.e0f985a"
	];
	
	my $expected = [
		[1, 0, 0, "alpha", ""],
		[1, 0, 0, "alpha.1", ""],
		[1, 0, 0, "beta.2", ""],
		[1, 0, 0, "beta.11", ""],
		[1, 0, 0, "rc.1", ""],
		[1, 0, 0, "rc.1", "build.1"],
		[1, 0, 0, "", ""],
		[1, 0, 0, "", "0.3.7"],
		[1, 3, 7, "", "build"],
		[1, 3, 7, "", "build.2"],
		[1, 3, 7, "", "build.11"]
	];

	for ( my $i = 0; $i < @$versions; $i++ ) {
		my ($major, $minor, $patch, $release, $build) = $self->parseSemVer($$versions[$i]);

		my $matched = 0;
		if ( $major == $$expected[$i][0]
			and $minor == $$expected[$i][1]
			and $patch == $$expected[$i][2]
			and $release eq $$expected[$i][3]
			and $build eq $$expected[$i][4]
		) { $matched = 1; }
		ok ($matched, "parseSemVer    $$versions[$i]");
	}
}

method testSameHigherVersion {
	

	my $versions = [
		#### SIMPLE
		["2.8.12.1", "2.8.12.0"],
		["2.8.12.1", "2.8.12.1"],
		["2.8.12.1", "2.8.12.3"],
	
		#### MIXED VERSIONS
		["2.8.12", "2.8.1.13"],
		["2.8.12", "2.8.12.13"],
		["2.8.12.build24", "2.8.12.build37"],
		["2.8.12.build24", "2.8.12.build3"],
		["2.8.12.build24", "2.8.12"],
	];
	
	my $expecteds = [
		0,
		1,
		1,
		0,
		1,
		1,
		0,
		0
	];

	for ( my $i = 0; $i < @$versions; $i++ ) {
		my $version1= $$versions[$i][0];
		my $version2= $$versions[$i][1];
		
		my $expected = $$expecteds[$i];
		my $actual	=	$self->sameHigherVersion($version1, $version2);
		$self->logDebug("expected", $expected);
		$self->logDebug("actual", $actual);
		
		ok ($expected == $actual, "sameHigherVersion    $version1: $version2 ($expected)");
	}

}

#### INTEGRATION TESTS
method testSetVersion () {
	my $inputdir 	= 	"$Bin/inputs";
	my $outputdir 	= 	"$Bin/outputs";

	#### SET LOG FILE
	my $logfile		=	"$Bin/outputs/setversion.log";
	$self->logfile($logfile);

	##### SET REPO DIR, BRANCH AND VERSION FILE
	my $repository	=	"testrepo";
	my $repodir		=	"$outputdir/$repository";
	my $branch		=	"master";
	my $versionfile	=	"$repodir/VERSION";
	
	my $checkouts = [
		"1.3.7+build.11.e0f985a",
		"1.0.0-alpha.1"
		#,
		#"1.0.0-beta.2",
		#"1.0.0-rc.1",
		#"1.0.0-rc.1+build.1",
		#"1.0.0"
	];

	my $argsarray = [
		["semver", $repodir, $versionfile, $branch, "1.2.0", "Description for 1.2.0"],
 		["semver", $repodir, $versionfile, $branch, "1.3.7+build.11", "Description for 1.3.7+build.11" ],
		["semver", $repodir, $versionfile, $branch, "1.3.8+build.11", "Description for 1.3.8+build.11" ],
		["semver", $repodir, $versionfile, $branch, "2.0.0-alpha.1", "Description for 2.0.0-alpha.1" ],
		["semver", $repodir, $versionfile, $branch, "0.8.0", "Description for 0.8.0" ]
	];

	my $expectedarray = [
		[	
			undef,
			undef,
			"1.3.8+build.11",
			"2.0.0-alpha.1",
			undef
		],
		[	
			"1.2.0",
			"1.3.7+build.11",
			"1.3.8+build.11",
			"2.0.0-alpha.1",
			undef
		]
	];

	for ( my $c = 0; $c < @$checkouts; $c++ ) {
		my $currentversion 	= 	$$checkouts[$c];

		for ( my $i = 0; $i < @$argsarray; $i++ ) {
			my $args = $$argsarray[$i];
			my $repodir		=	$$args[1];
			my $version		= 	$$args[4];

			#### DEBUG
			$self->logDebug("version", $version);

			#### COPY DIR
			$self->setUpDirs("$inputdir/$repository", $repodir);
		
			#### CHECK OUT VERSION
			$self->changeToRepo($repodir);
			$self->checkoutTag($repodir, $currentversion);
			$self->logDebug("checked out tag: $currentversion");
		
			#### SET VERSION
			my ($result) = $self->setVersion(@$args);
			$self->logDebug("result", $result);
	
			my $expected = $$expectedarray[$c][$i];
			$self->logDebug("expected", $expected);
	
			if ( defined $result and defined $expected ) {
				#### VERIFY RESULT
				ok($result eq $expected, "setVersion    $currentversion --> $version");
				
				##### CHECK TAG NUMBER
				my ($tag) = $self->currentLocalTag();
				ok($result eq $tag, "setVersion    tag: $tag");
				
				#### CHECK TABLE ENTRY
				my $fileversion = $self->getVersionFile($$args[2]);
				ok($result eq $fileversion, "setVersion    versionfile: $fileversion");
			}
			elsif ( not defined $result ) {
				ok(! $expected, "setVersion    $currentversion --> $version");
			}
			else {
				ok(! $result, "setVersion    $currentversion --> $version");
			}
			#### CLEAN UP
			`rm -fr $repodir`;
			
			#last;
		}
	}
}

method testIncrementSemVer {
	diag("Test incrementSemVer");

	#### DIRECTORIES
	my $inputdir 	= 	"$Bin/inputs";
	my $outputdir 	= 	"$Bin/outputs";

	#### SET LOG FILE
	my $logfile		=	"$Bin/outputs/incrementversion.log";
	$self->logfile($logfile);

	##### SET REPO DIR, BRANCH AND VERSION FILE
	my $repository	=	"testrepo";
	my $sourcedir	=	"$inputdir/$repository";
	my $targetdir	=	"$outputdir/$repository";

	my $tests = [
		{
			name 		=>	"three-digit build",
			version		=>	"0.8.0-beta.1+build.719",
			expected	=>	"0.8.0-beta.1+build.720",		
			versiontype	=>	"build",
			releasename	=>	undef
		}
		,
		{
			name 		=>	"patch",
			version		=>	"0.8.0-beta.1+build.719",
			expected	=>	"0.8.1",		
			versiontype	=>	"patch",
			releasename	=>	undef
		}
		,
		{
			name 		=>	"minor",
			version		=>	"0.8.0-beta.1+build.719",
			expected	=>	"0.9.0",		
			versiontype	=>	"minor",
			releasename	=>	undef
		}
		,
		{
			name 		=>	"major",
			version		=>	"0.8.0-beta.1+build.719",
			expected	=>	"1.0.0",		
			versiontype	=>	"major",
			releasename	=>	undef
		}
		,
		{
			name 		=>	"releasetype rc1",
			version		=>	"0.8.0-beta.1+build.719",
			expected	=>	"0.8.0-rc1",		
			versiontype	=>	undef,
			releasename	=>	"rc1"
		}
		,
		{
			name 		=>	"releasetype rc1 (even if less than current rc2)",
			version		=>	"0.8.0-rc2+build.719",
			expected	=>	"0.8.0-rc1",		
			versiontype	=>	undef,
			releasename	=>	"rc1"
		}
	];
	
	foreach my $test ( @$tests ) {
		my $name 			= 	$test->{name};
		my $version 		= 	$test->{version};
		my $expected 		= 	$test->{expected};
		my $versiontype 	= 	$test->{versiontype};
		my $releasename 	= 	$test->{releasename};
		$self->logDebug("name",  $name);	
		$self->logDebug("version",  $version);	
		$self->logDebug("expected",  $expected);	
		$self->logDebug("versiontype",  $versiontype);	
		$self->logDebug("releasename",  $releasename);
		
		#### INCREMENT VERSION
		my $actual = $self->incrementSemVer($version, $versiontype, $releasename);
		$self->logDebug("actual", $actual);

		if ( defined $actual and defined $expected ) {
			ok($actual eq $expected, "incrementSemVer    $version --> $expected");
		}
		elsif ( not defined $actual ) {
			ok(! $expected, "incrementSemVer    $version --> undef ($versiontype, $releasename)");
		}
		else {
			ok(! $actual, "incrementSemVer    $version --> undef ($versiontype, $releasename)");
		}
	}
}

method testIncrementVersion {
	diag("Test incrementVersion");
	
	my $inputdir 	= 	"$Bin/inputs";
	my $outputdir 	= 	"$Bin/outputs";
	
	#### SET LOG FILE
	my $logfile		=	"$Bin/outputs/incrementversion.log";
	$self->logfile($logfile);

	##### SET REPO DIR, BRANCH AND VERSION FILE
	my $repository	=	"testrepo";
	my $targetdir	=	"$outputdir/$repository";
	my $sourcedir	=	"$inputdir/$repository";
	$self->logDebug("sourcedir", $sourcedir);
	$self->logDebug("targetdir", $targetdir);
	
	my $branch		=	"master";
	my $versionfile	=	"$targetdir/VERSION";

	my $checkouts = [
		"1.3.7+build.11.e0f985a",
		"1.0.0-alpha.1",
		"1.0.0-beta.2",
		"1.0.0-rc.2",
		"1.0.0-rc.2+build.5",
		"1.0.0"
	];

	my $argsarray = [
		[ "semver", "major", $targetdir, $versionfile, undef, "Description of this version", $branch ],
		[ "semver", "minor", $targetdir, $versionfile, undef, "Description of this version", $branch ],
		[ "semver", "patch", $targetdir, $versionfile, undef, "Description of this version", $branch ],
		[ "semver", "release", $targetdir, $versionfile, undef, "Description of this version", $branch ],
		[ "semver", "build", $targetdir, $versionfile, undef, "Description of this version", $branch ],
		[ "semver", "build", $targetdir, $versionfile, "alpha", "Description of this version", $branch ],
		[ "semver", "major", $targetdir, $versionfile, "alpha", "Description of this version", $branch ],
		[ "semver", undef, $targetdir, $versionfile, "beta", "Description of this version", $branch ],
		[ "semver", undef, $targetdir, $versionfile, "rc", "Description of this version", $branch ]
	];

	my $expectedarray = [
		#"1.3.7+build.11.e0f985a"
		[	
			"2.0.0",
			"1.4.0",
			"1.3.8",
			undef,
			"1.3.7+build.12",
			undef,
			"2.0.0-alpha.1",
			undef,
			undef
		],

		#"1.0.0-alpha.1"
		[
			"2.0.0",
			"1.1.0",
			"1.0.1",
			"1.0.0-alpha.2",
			"1.0.0-alpha.1+build.1",
			undef,
			"2.0.0-alpha.1",
			"1.0.0-beta.1",
			"1.0.0-rc.1"
		],

		#"1.0.0-beta.2"
		[
			"2.0.0",
			"1.1.0",
			"1.0.1",
			"1.0.0-beta.3",
			"1.0.0-beta.2+build.1",
			undef,
			"2.0.0-alpha.1",
			undef,
			"1.0.0-rc.1"
		],

		# "1.0.0-rc.2"
		[
			"2.0.0",
			"1.1.0",
			"1.0.1",
			"1.0.0-rc.3",
			"1.0.0-rc.2+build.1",
			undef,
			"2.0.0-alpha.1",
			undef,
			undef
		],

		# "1.0.0-rc.2+build.5",
		[
			"2.0.0",
			"1.1.0",
			"1.0.1",
			"1.0.0-rc.3",
			"1.0.0-rc.2+build.6",
			undef,
			"2.0.0-alpha.1",
			undef,
			undef
		],
		
		# "1.0.0"
		[
			"2.0.0",
			"1.1.0",
			"1.0.1",
			undef,
			"1.0.0+build.1",
			undef,
			"2.0.0-alpha.1",
			undef,
			undef
		]
	];


	for ( my $c = 0; $c < @$checkouts; $c++ ) {
	#for ( my $c = 0; $c < 1; $c++ ) {
		my $currentversion 	= 	$$checkouts[$c];
		print "currentversion: $currentversion\n";	
		
		for ( my $i = 0; $i < @$argsarray; $i++ ) {
		#for ( my $i = 1; $i < 2; $i++ ) {
	
			my $args = $$argsarray[$i];

			my $versiontype		= 	$$args[1] || '';
			my $releasename		=	$$args[4] || '';
			
			#### DEBUG OUTPUT
			$self->logDebug("");
			$self->logDebug("#### currentversion", $currentversion);
			$self->logDebug("#### versiontype", $versiontype);
			$self->logDebug("#### releasename", $releasename);
			
			#### COPY DIR
			$self->setUpDirs($sourcedir, $targetdir);
			
			#### CHECK OUT TAG
			$self->changeToRepo($targetdir);
			$self->checkoutTag($targetdir, $currentversion);

			#### RUN UPGRADE
			my $newversion = $self->incrementVersion(@$args);
			$self->logDebug("newversion", $newversion);
			
			my $expected = $$expectedarray[$c][$i];
			$self->logDebug("expected", $expected);
			
			#### SET LABELS
			my $type = $versiontype || 'undef';
			my $version = $currentversion || 'undef';
			my $release = $releasename || 'undef';
			
			if ( defined $newversion and defined $expected ) {
				ok($newversion eq $expected, "incrementVersion    $version --> $expected ($type, $release)");
				
				##### CHECK CURRENT TAG
				$self->changeToRepo($targetdir);
				my ($tag) = $self->currentLocalTag();
				$self->logDebug("tag", $tag);
				ok($newversion eq $tag, "incrementVersion    tag: $tag should be newversion: $newversion");

				#### CHECK VERSION FILE
				my $fileversion = $self->getVersionFile($$args[3]);
				ok($newversion eq $fileversion, "incrementVersion    versionfile contents: $fileversion");
			}
			elsif ( not defined $newversion ) {
				ok(! $expected, "incrementVersion    $version --> undef ($type, $release)");
			}
			else {
				ok(! $newversion, "incrementVersion    $version --> undef ($type, $release)");
			}
			
		#### CLEAN UP
			`rm -fr $targetdir`;
		}
	}

	##### REMOVE LOCAL REPOSITORY 
	#`rm -fr $inputdir`;

}


method getVersionFile ($versionfile) {
	my $contents = $self->fileContents($versionfile);
	$contents =~ s/\s+$//;
	
	return $contents;
}



}
