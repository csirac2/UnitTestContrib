package Unit::Webserver::ApacheHtAccess;

use strict;
use warnings;

use Unit::Webserver();
our @ISA = ('Unit::Webserver');

use Assert;
use Data::Dumper;
use File::Temp();
use File::Spec();
use Unit::Request();
use Foswiki();
use Foswiki::Meta();
use Foswiki::Func();

sub variants {
    my ($class) = @_;

    return (qw(cgi fcgid));
}

sub new {
    my ( $class, $name, $type, $variant, $server_conf, $foswiki_conf ) = @_;
    ASSERT( $type eq 'ApacheHtAccess' );
    my %data =
      $class->SUPER::init( $name, $type, $variant, $server_conf,
        $foswiki_conf );
    my $this = bless( \%data, $class );

    $this->write_localsite();
    print Dumper( \%data );
    $this->write_apacheconfig();

    return $this;
}

sub finish {
    my ($this) = @_;

    return $this->SUPER::finish();
}

sub _parent_dir {
    my ( $class, $dir ) = @_;

    ASSERT($dir);
    my @dirs = File::Spec->splitdir($dir);
    pop(@dirs);
    $dir = File::Spec->catdir(@dirs);

    return $dir;
}

sub _get_confcode {
    my ( $class, %params ) = @_;
    my $session;
    my $web   = $Foswiki::cfg{SystemWebName};
    my $topic = 'UnitTestApacheConfigGenerator';
    my $topicObj;
    my $requestObj = Unit::Request->new( \%params );
    my $confcode;

    $requestObj->pathInfo("/$web/$topic");
    $session = Foswiki->new( undef, $requestObj );
    $topicObj = Foswiki::Meta->new( $session, $web, $topic );
    $topicObj->load();

    $confcode =
      $topicObj->expandMacros('%INCLUDE{"%TOPIC%" section="confcode"}%');
    $topicObj->finish();
    $session->finish();

    return $confcode;
}

sub write_apacheconfig {
    my ($this) = @_;
    my %defaults = (
        rewrite       => 'on',
        htaccess      => 'htaccess',
        dir           => $this->_parent_dir( $this->{foswiki_conf}{ScriptDir} ),
        reqandor      => 'and',
        loginmanager  => 'Template',
        errordocument => 'UserRegistration',
        blockmodphp   => 1,
        controlattach => 'on',
        foswikiversion => 1.1
    );
    ASSERT( ref( $this->{server_conf} ) eq 'HASH' );
    my %conf             = ( %defaults, %{ $this->{server_conf} } );
    my $confcode         = $this->_get_confcode(%conf);
    my $htaccessfilename = File::Spec->catfile( $conf{dir}, '.htaccess' );

    ASSERT( ( !-f $htaccessfilename ),
        "Don't want to overwrite '$htaccessfilename' which already exists" );
    open( my $fh, '>', $htaccessfilename )
      or die "Couldn't open '$htaccessfilename': $!";
    print $fh $confcode;
    close($fh) or die "Couldn't close '$htaccessfilename': $!";
    $this->add_tempfile($htaccessfilename);

    return;
}

1;
