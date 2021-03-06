#!/usr/bin/perl -w

use strict;

=head2

APPLICATION     stager

PURPOSE

PACKAGE		Ops::Main::Stager

PURPOSE

	A TOOL TO SIMPLIFY THE TASK OF STAGING FROM
	
	DEVEL --> PRODUCTION REPOSITORIES

	-   SIMPLE COMMAND TO STAGE ANY REPO
	
	-   ALLOW MULTILINE COMMIT MESSAGE

	-   stage.pm DOES FILE MANIPULATIONS, RENAMING, ETC.

	-   stage.conf (Agua::Conf FORMAT) STORES STAGE INFO

EXAMPLES

./stage.pl \
--version 0.8.0-alpha+build.1 \
--stagefile /repos/private/syoung/biorepodev/stage.pm \
--mode 1-2 \
--message "First line
(EMPTY LINE)
(EMPTY LINE)
Second line
Third line"

=cut

#### FLUSH BUFFER
$| = 1;

#### USE LIB
use FindBin qw($Bin);
use lib "$Bin/../..";

#### EXTERNAL MODULES
use Getopt::Long;

#### INTERNAL MODULES
use Ops::Stager;

#### GET OPTIONS
my $branch          =   "master";
my $versionformat   =   "semver";
my $logfile 		= 	"/tmp/stager.log";
my $log     	    =   2;
my $printlog    	=   5;
my $stagefile;
my $mode;
my $message;
my $version;
my $versiontype;
my $package;
my $outputdir;
my $releasename;
my $versionfile;
my $help;
GetOptions (

	#### REQUIRED
    'package=s'         =>  \$package,
    'mode=s'            =>  \$mode,
    'stagefile=s'       =>  \$stagefile,
    'message=s'     	=>  \$message,

	#### EITHER OR
	'version=s'         =>  \$version,
    'versiontype=s'     =>  \$versiontype,

	#### DEBUG
    'log=s'             =>  \$log,
    'printlog=s'        =>  \$printlog,

	#### OPTIONAL
    'versionfile=s'     =>  \$versionfile,
    'versionformat=s'   =>  \$versionformat,
    'branch=s'          =>  \$branch,
    'outputdir=s'       =>  \$outputdir,
    'releasename=s'     =>  \$releasename,
    'logfile=s'         =>  \$logfile,
    'help'              =>  \$help
) or die "No options specified. Try '--help'\n";
usage() if defined $help;

print "version.pl    bad mode format: $mode (example: N-N)\n" and exit if $mode !~ /^(\d+)-(\d+)$/;

print "version.pl    stagefile not defined\n" and exit if not defined $stagefile;
print "version.pl    message not defined\n" and exit if not defined $message;
print "version.pl    neither version nor versiontype are defined\n" and exit if not defined $version and not defined $versiontype;
print "version.pl    both version and versiontype are defined\n" and exit if defined $version and defined $versiontype;
print "version.pl    versiontype must be 'major'O, 'minor', 'patch' or 'build'\n" and exit if defined $versiontype and not $versiontype =~ /^(major|minor|patch|release|build)$/;
print "version.pl    releasename must be 'alpha', 'beta', or 'rc'\n" and exit if defined $releasename and not $releasename =~ /^(alpha|beta|rc)$/;


my $object = Ops::Stager->new({
    version     	=>  $version,
    versiontype     =>  $versiontype,
    versionfile     =>  $versionfile,
    versionformat   =>  $versionformat,
    branch          =>  $branch,
    package     	=>  $package,
    logfile         =>  $logfile,
    outputdir       =>  $outputdir,
    releasename     =>  $releasename,
    logfile     	=>   $logfile,
    log			    =>	$log,
    printlog   		=>   $printlog
});
$object->stageRepo($stagefile, $mode, $message);

######################## SUBROUTINES #####################

sub usage {
    print `perldoc $0`;
    exit;
}