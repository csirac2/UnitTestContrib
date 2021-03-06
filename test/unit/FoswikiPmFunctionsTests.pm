# NOTE: this is a VERY limited subset of subroutines in Foswiki.pm (um, ok, one - moved from ManageDotPmTests..)

use strict;
use warnings;
use diagnostics;

package FoswikiPmFunctionsTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );
use Foswiki;
use Foswiki::UI::Manage;
use Foswiki::UI::Save;

my $debug = 0;
my $fatwilly;

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    my $query = new Unit::Request();
    $fatwilly = Foswiki->new( undef, $query );
    $this->{request}  = $query;
    $this->{response} = new Unit::Response();
}

sub test_isValidTopicName_WebHome {
    my $this = shift;

    my $result = Foswiki::isValidTopicName( 'WebHome', 1 );
    my $expected = 1;
    print("result=$result.\n")     if $debug;
    print("expected=$expected.\n") if $debug;
    $this->assert( $result eq $expected );
}

sub test_isValidTopicName_WebHome_NOT_nonwikiword {
    my $this = shift;

    my $result = Foswiki::isValidTopicName( 'WebHome', 0 );
    my $expected = 1;
    print("result=$result.\n")     if $debug;
    print("expected=$expected.\n") if $debug;
    $this->assert( $result eq $expected );
}

sub test_isValidTopicName_Aa_nonwikiword {
    my $this = shift;

    my $result = Foswiki::isValidTopicName( 'Aa', 1 );
    my $expected = 1;
    print("result=$result.\n")     if $debug;
    print("expected=$expected.\n") if $debug;
    $this->assert( $result eq $expected );
}

sub test_isValidTopicName_Aa_NOT_nonwikiword {
    my $this = shift;

    my $result = Foswiki::isValidTopicName( 'Aa', 0 );
    my $expected = 0;
    print("result=$result.\n")     if $debug;
    print("expected=$expected.\n") if $debug;
    $this->assert( $result eq $expected );
}

1;
