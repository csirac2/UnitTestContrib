use strict;

# Example test case; use this as a basis to build your own

package AddToHeadTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'SortedHeadTests', @_ );
    return $self;
}

sub skip {
    my ( $this, $test ) = @_;

    return $this->check_dependency('Foswiki,>=,1.1')
      ? 'Feature removed from Foswiki 1.1+'
      : undef;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->expect_failure( 'Pre-Foswiki 1.1 feature',
        with_dep => 'Foswiki,>=,1.1' );
}

sub testSimple {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $raw_tag  = '%ADDTOHEAD{text="QQQ"}%%RENDERHEAD%';
    my $expected = "<!--  --> QQQ";
    my $result =
      Foswiki::Func::expandCommonVariables( $raw_tag, $topicName, $webName );
    $this->assert_equals( $expected, $result );
}

sub testOrderWithRequires {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};

    my $raw_tag =
'%ADDTOHEAD{"first" text="QQQ FIRST"}%%ADDTOHEAD{"second" text="QQQ SECOND" requires="third"}%%ADDTOHEAD{"third" text="QQQ THIRD"}%%RENDERHEAD%';
    my $expected =
        "<!-- first --> QQQ FIRST"
      . "\n<!-- third --> QQQ THIRD"
      . "\n<!-- second --> QQQ SECOND";
    my $result =
      Foswiki::Func::expandCommonVariables( $raw_tag, $topicName, $webName );
    $this->assert_equals( $expected, $result );
}

sub testTopicArgument {
    my $this = shift;

    my $topicName             = $this->{test_topic};
    my $webName               = $this->{test_web};
    my $testTopicWithHead     = 'testTopicWithHead';
    my $fullTestTopicWithHead = "$webName\.$testTopicWithHead";

    Foswiki::Func::saveTopic( $webName, $testTopicWithHead, undef,
        "THIS IS ANOTHER TOPIC" );

    my $raw_tag =
        '%ADDTOHEAD{"testtopic" topic="'
      . $fullTestTopicWithHead
      . '"}%%RENDERHEAD%';

    my $expected = "<!-- testtopic --> THIS IS ANOTHER TOPIC";
    my $result =
      Foswiki::Func::expandCommonVariables( $raw_tag, $topicName, $webName );
    $this->assert_equals( $expected, $result );
}

sub testFuncSimple {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    Foswiki::Func::addToHEAD( "first", "QQQ" );
    my $raw_tag  = '%RENDERHEAD%';
    my $expected = "<!-- first --> QQQ";
    my $result =
      Foswiki::Func::expandCommonVariables( $raw_tag, $topicName, $webName );
    $this->assert_equals( $expected, $result );
}

sub testFuncRequires {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    Foswiki::Func::addToHEAD( "first",  "QQQ FIRST" );
    Foswiki::Func::addToHEAD( "second", "QQQ SECOND", "third" );
    Foswiki::Func::addToHEAD( "third",  "QQQ THIRD" );
    my $raw_tag = '%RENDERHEAD%';
    my $expected =
        "<!-- first --> QQQ FIRST"
      . "\n<!-- third --> QQQ THIRD"
      . "\n<!-- second --> QQQ SECOND";
    my $result =
      Foswiki::Func::expandCommonVariables( $raw_tag, $topicName, $webName );
    $this->assert_equals( $expected, $result );
}

=pod

Test common usage with quotes and slashes.

=cut

sub testFuncStyle {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    Foswiki::Func::addToHEAD( 'PATTERN_STYLE',
'<link id="twikiLayoutCss" rel="stylesheet" type="text/css" href="PatternSkin/layout.css" media="all" />'
    );
    my $raw_tag = '%RENDERHEAD%';
    my $expected =
'<!-- PATTERN_STYLE --> <link id="twikiLayoutCss" rel="stylesheet" type="text/css" href="PatternSkin/layout.css" media="all" />';
    my $result =
      Foswiki::Func::expandCommonVariables( $raw_tag, $topicName, $webName );
    $this->assert_equals( $expected, $result );
}

1;
