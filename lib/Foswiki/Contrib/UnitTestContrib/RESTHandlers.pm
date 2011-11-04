package Foswiki::Contrib::UnitTestContrib::RESTHandlers;

use strict;
use warnings;

use Assert;
use Foswiki::Func();

my %module_whitelist = map { $_ => $_ } (qw(CGI FCGI));

# Guarding accidental exposure of module version info, should execution somehow
# reach here in a production environment.
# - Must have the special LocalSite.cfg entry
#   $Foswiki::cfg{UnitTestContrib}{State} = 'UnderTest'
# - Must be authenticated
# - Must be an admin user
sub register {
    my $success;

    if ( Foswiki::Func::isAnAdmin( Foswiki::Func::getCanonicalUserID() )
        && $Foswiki::cfg{UnitTestContrib}{State} eq 'UnderTest' )
    {
        Foswiki::Func::registerRESTHandler( 'moduleversion', \&_moduleversion,
            authenticate => 1 );
        $success = 1;
    }
    else {
        my $msg = <<'HERE';
BAD: Foswiki::Contrib::UnitTestContrib::initPlugin was called, which should only
ever happen when under test!'
HERE
        Foswiki::Func::writeWarning($msg);
        print STDERR $msg;
    }

    return $success;
}

sub _moduleversion {
    my ($session) = @_;
    ASSERT( Foswiki::Func::isAnAdmin( Foswiki::Func::getCanonicalUserID() ) );
    my $junk    = Foswiki::Func::getRequestObject()->param('module');
    my $version = 'ERROR';
    my $module;

    if ( $junk =~ /^([a-zA-Z][a-zA-Z0-9_:]+)$/ ) {
        $module = $module_whitelist{$1};
        if ( $module
            && !eval "require $module; $version = ${module}::VERSION; 1;" )
        {
            $version = $@;
        }
    }

    return $version;
}

1;
