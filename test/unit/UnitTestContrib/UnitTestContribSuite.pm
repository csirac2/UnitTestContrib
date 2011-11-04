package UnitTestContribSuite;

use strict;
use warnings;

use Unit::TestSuite;
use Data::Dumper;
our @ISA = 'Unit::TestSuite';

sub name { 'UnitTestContribSuite' }

sub include_tests {
    my @tests            = (qw(EavesdropTests));
    my $seleniumBrowsers = $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers};
    my $webserverConfigs = $Foswiki::cfg{UnitTestContrib}{Webservers};

    if ( ref( ($seleniumBrowsers) )
        && scalar( keys %{$seleniumBrowsers} ) )
    {
        if ( ref($webserverConfigs)
            && scalar( keys %{$webserverConfigs} ) )
        {
            push( @tests, 'WebserverTests' );
        }
        else {
            print STDERR <<'HERE';
**** No webservers configured in $Foswiki::cfg{UnitTestContrib}{Webservers}.
**** SKIPPING WebserverTests
HERE
        }
    }
    else {
        print STDERR <<'HERE';
**** No browsers configured in $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers},
**** SKIPPING WebserverTests
HERE
    }

    return @tests;
}

1;
