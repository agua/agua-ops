#!/usr/bin/perl -w

use Test::More tests => 18;     #  qw(no_plan);
use FindBin qw($Bin);
use lib "$Bin/../../../../lib";
BEGIN
{
    my $installdir = $ENV{'installdir'} || "/a";
    unshift(@INC, "$installdir/extlib/lib/perl5");
    unshift(@INC, "$installdir/extlib/lib/perl5/x86_64-linux-gnu-thread-multi/");
    unshift(@INC, "$installdir/lib");
    unshift(@INC, "$installdir/lib/external/lib/perl5");
}

#### CREATE OUTPUTS DIR
my $outputsdir = "$Bin/outputs";
`mkdir -p $outputsdir` if not -d $outputsdir;

use Test::Ops::GitHub;
use Getopt::Long;
use Conf::Yaml;

#### SET DUMPFILE
my $dumpfile    =   "$Bin/../../../../dump/create.dump";

#### SET CONF FILE
my $installdir  =   $ENV{'installdir'} || "/a";
my $configfile    =   "$installdir/conf/config.yml";

#### SET $Bin
$Bin =~ s/^.+t\/bin/$installdir\/t\/bin/;

#### SET LOG
my $log     =   2;
my $printlog    =   5;
my $logfile     =   "$Bin/outputs/install.log";

#### GET OPTIONS
my $pwd = $Bin;
my $login;
my $showreport = 1;
my $token;
my $password;
my $keyfile;
my $help;
GetOptions (
    'log=i'     => \$log,
    'printlog=i'    => \$printlog,
    'login=s'       => \$login,
    'showreport=s'  => \$showreport,
    'token=s'       => \$token,
    'password=s'    => \$password,
    'keyfile=s'     => \$keyfile,
    'help'          => \$help
) or die "No options specified. Try '--help'\n";
usage() if defined $help;

#### LOAD LOGIN, ETC. FROM ENVIRONMENT VARIABLES
$login = $ENV{'login'} if not defined $login or not $login;
$token = $ENV{'token'} if not defined $token;
$password = $ENV{'password'} if not defined $password;
$keyfile = $ENV{'keyfile'} if not defined $keyfile;

my $whoami = `whoami`;
$whoami =~ s/\s+//g;
if ( not defined $login or not defined $token
    or not defined $keyfile ) {
    print "Missing login, token or keyfile. Run this script manually and provide GitHub login and token credentials and SSH private keyfile\n";
    #ok(1, "Quitting");
    for ( 0 .. 17 ) { pass; }
    done_testing(18);
    #skip(18);
    exit;
}
elsif ( $whoami ne "root" ) {
    print "Install.t    Must run as root\n";
    #done_testing(1);
    #is_passing(18);
    
    exit ;    
}

my $conf = Conf::Yaml->new(
    memory      =>  1,
    inputfile	=>	$configfile,
    log     =>  2,
    printlog    =>  2,
    logfile     =>  $logfile
);

my $username = $conf->getKey("database:TESTUSER");

my $object = new Test::Ops::GitHub (
    log			=>	$log,
    printlog    =>  $printlog,
    logfile     =>  $logfile,
    dumpfile    =>  $dumpfile,
    conf        =>  $conf,
    showreport  =>  $showreport,
    pwd         =>  $pwd,
    username    =>  $username,
    
    login       =>  $login,
    token       =>  $token,
    password    =>  $password,
    keyfile     =>  $keyfile
);


#### TEST GET USER INFO
$object->testGetUserInfo();

#### TEST SET CREDENTIALS
$object->testSetCredentials();

#### TEST GET REPO
$object->testGetRepo();

#### TEST GET REPO
$object->testGetRemoteTags();

#### TEST CREATE REPO
$object->testCreateRepo();

#### TEST FORK REPO
$object->testForkRepo();

#### TEST FORK REPO
$object->testRemoveOAuthToken();

#### TEST FORK REPO
$object->testAddOAuthToken();

#### CLEAN UP
`rm -fr $Bin/outputs/*`
