use MooseX::Declare;

class Test::Ops::Main with (Test::Common,
	Table::Main,
	Engine::Cluster::Jobs,
	Table::Common,
	Util::Main) {
use Data::Dumper;
use Test::More;
use Test::DatabaseRow;
use DBase::Factory;

# INTS
has 'workflowpid'	=> ( isa => 'Int|Undef', is => 'rw', required => 0 );
has 'workflownumber'=>  ( isa => 'Str', is => 'rw' );
has 'start'     	=>  ( isa => 'Int', is => 'rw' );
has 'submit'  		=>  ( isa => 'Int', is => 'rw' );

# STRINGS
has 'fileroot'	=> ( isa => 'Str|Undef', is => 'rw', default => '' );
has 'qstat'		=> ( isa => 'Str|Undef', is => 'rw', default => '' );

# STRINGS
has 'queue'			=>  ( isa => 'Str|Undef', is => 'rw', default => 'default' );
has 'cluster'		=>  ( isa => 'Str|Undef', is => 'rw' );
has 'username'  	=>  ( isa => 'Str', is => 'rw' );
has 'workflow'  	=>  ( isa => 'Str', is => 'rw' );
has 'project'   	=>  ( isa => 'Str', is => 'rw' );

# OBJECTS
has 'json'		=> ( isa => 'HashRef', is => 'rw', required => 0 );
has 'db'	=> ( isa => 'DBase::MySQL', is => 'rw', required => 0 );
has 'stages'		=> 	( isa => 'ArrayRef', is => 'rw', required => 0 );
has 'stageobjects'	=> 	( isa => 'ArrayRef', is => 'rw', required => 0 );
has 'monitor'		=> 	( isa => 'Maybe|Undef', is => 'rw', required => 0 );

has 'conf' 	=> (
	is =>	'rw',
	'isa' => 'Conf::Yaml',
	default	=>	sub { Conf::Yaml->new( backup	=>	1 );	}
);

method BUILD ($hash) {
    $self->setDbh();
    $Test::DatabaseRow::dbh = $self->table()->db()->dbh();
}

method testSetMonitor {
	my $clustertype =  $self->conf()->getKey("agua:CLUSTERTYPE");
	my $classfile = "Agua/Monitor/" . uc($clustertype) . ".pm";
	my $module = "Agua::Monitor::$clustertype";
	$self->logDebug("Doing require $classfile");
	require $classfile;
	my $monitor = $module->new(
		{
			'pid'		=>	$$,
			'conf' 		=>	$self->conf(),
			'db'	=>	$self->table()->db()
		}
	);

	return $monitor;
}

method testReplaceInFile {

my $oldmasterip = "ip-10-126-43-137.ec2.internal";
	my $newmasterip = "ip-10-126-35-168.ec2.internal";
	$self->logDebug("oldmasterip", $oldmasterip);
	$self->logDebug("newmasterip", $newmasterip);
my $text q= qq{
cat /etc/exports
/agua  10.126.43.137(async,no_root_squash,no_subtree_check,rw)
/data  10.126.43.137(async,no_root_squash,no_subtree_check,rw)
/nethome  10.126.43.137(async,no_root_squash,no_subtree_check,rw)
};

}





}   #### Test::Ops::Main