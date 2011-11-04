package Unit::Webserver;

use strict;
use warnings;
use Assert;
use File::Temp();
use Data::Dumper();
use Foswiki::Configure::Root       ();
use Foswiki::Configure::Valuer     ();
use Foswiki::Configure::FoswikiCfg ();

sub new {
    my ( $class, $name, $type, $variant, $server_conf, $foswiki_conf ) = @_;
    my $typeclass;

    ASSERT( $class eq 'Unit::WebServer',
        "Classes must implement their own ->new()" );
    $typeclass = 'Unit::Webserver::' . $type;
    ASSERT( eval "require $typeclass; 1;",
        "Class missing for type '$type'? $@" );

    return $typeclass->new( $name, $type, $variant, $server_conf,
        $foswiki_conf );
}

sub finish {
    my ($this) = @_;

    $this->tear_down();
    $this->{name}            = undef;
    $this->{type}            = undef;
    $this->{variant}         = undef;
    $this->{server_conf}     = undef;
    $this->{foswiki_conf}    = undef;
    $this->{TempFiles}       = undef;
    $this->{LocalSiteDir}    = undef;
    $this->{LocalSiteDirObj} = undef;
    $this->{LocalSitePath}   = undef;

    return;
}

sub init {
    my ( $class, $name, $type, $variant, $server_conf, $foswiki_conf ) = @_;
    my %data = (
        name         => $name,
        type         => $type,
        variant      => $variant,
        server_conf  => $server_conf,
        foswiki_conf => $foswiki_conf
    );

    if ( !$server_conf->{LocalSiteDir} ) {
        $server_conf->{LocalSiteDirObj} = File::Temp->newdir();
        $server_conf->{LocalSiteDir} =
          $server_conf->{LocalSiteDirObj}->dirname();
    }
    ASSERT( $server_conf->{LocalSiteDir} && -d $server_conf->{LocalSiteDir} );
    $data{LocalSitePath} =
      File::Spec->catfile( $server_conf->{LocalSiteDir}, 'LocalSite.cfg' );

    return %data;
}

#sub write_localsite {
#    my ($class, $foswiki_conf, $path) = @_;
#    my %default_conf = (
#        UnitTestContrib => { State => 'UnderTest'}
#    );
#    ASSERT($path);
#    ASSERT(! -e $path);
#    my $valuer = Foswiki::Configure::Valuer->new( \%default_conf, $foswiki_conf );
#    my $root = Foswiki::Configure::Root->new();
##    my $tmpfh = File::Temp->new();
##    print $tmpfh <<'HERE';
#$Foswiki::cfg{UnitTestContrib}{State} = 'UnderTest';
#HERE
#    my $tmpfilename = $tmpfh->filename();
#    $tmpfh->close() or die $!;
#    Foswiki::Configure::FoswikiCfg::_parse($tmpfilename, $root, 1);
#    foreach my $k (keys %{$foswiki_conf}) {
#        $default_conf{$k} = $foswiki_conf->{$k};
#    }
#    print "Stuff: " . Data::Dumper->Dump([\%default_conf]);
#    my $saver = Foswiki::Configure::FoswikiCfg->new();
#    #$saver->{logger}  = $logger;
#    $foswiki_conf->{CHICKENS} = 43;
#    $saver->{valuer}  = $valuer;
#    $saver->{root}    = $root;
#    $saver->{content} = '';
#    my $out = $saver->_save();
#    #print Data::Dumper->Dump([$saver]);
#    open( my $fh, '>', $path )
#      || die "Could not open $path for write: $!";
#    print $fh $saver->{content};
#    close($fh) or die "Could not close $path: $!";
#
#    return;
#}

sub add_tempfile {
    my ( $this, $filename ) = @_;

    push( @{ $this->{TempFiles} }, $filename );

    return;
}

sub tear_down {
    my ($this) = @_;

    ASSERT( ref( $this->{TempFiles} ) eq 'ARRAY' );
    foreach my $filename ( @{ $this->{TempFiles} } ) {
        ASSERT( -f $filename, "'$filename' doesn't exist, can't unlink" );
        unlink $filename;
    }

    return;
}

sub get_scripturlpath {
    my ( $this, $script ) = @_;
    my $conf = $this->{foswiki_conf};
    my $path;

    ASSERT($conf);
    ASSERT( $conf->{ScriptUrlPath} );
    if ( $conf->{ScriptUrlPaths} ) {
        ASSERT( ref( $conf->{ScriptUrlPaths} ) eq 'HASH' );
        if ( exists $conf->{ScriptUrlPaths}{$script}
            and $conf->{ScriptUrlPaths}{$script} )
        {
            $path = $conf->{ScriptUrlPaths}{$script};
        }
    }
    if ( !$path ) {
        $path = $conf->{ScriptUrlPath} . '/' . $script;
    }

    return $path;
}

# A very poor man's config writer...
sub write_localsite {
    my ($this) = @_;
    my $path = $this->{LocalSitePath};

    ASSERT($path);
    $this->{foswiki_conf}->{UnitTestContrib}{State} = 'UnderTest';
    my @lines =
      split( /[\r\n]+/, Data::Dumper->Dump( [ $this->{foswiki_conf} ] ) );

    ASSERT( scalar(@lines) );
    $lines[0]  =~ s/^\$VAR1\s*=\s*\{/%Foswiki::cfg = (/;
    $lines[-1] =~ s/\};$/);/;
    ASSERT($path);
    ASSERT( !-f $path, "Tried to write $path, but it already exists!" );
    open( my $fh, '>', $path ) or die "Couldn't write $path: $!";
    print $fh join( "\n", @lines );
    close($fh) or die $!;
    $this->add_tempfile($path);

    return;
}

1;
