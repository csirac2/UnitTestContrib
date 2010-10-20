# tests for the correct expansion of SEARCH
# SMELL: this test is pathetic, becase SEARCH has dozens of untested modes
#
# In order to keep this test down to a manageable run time, the fixture
# groups are only applied to those tests where we are testing the correct
# parsing of the search expression and its correct application in searching.
# Where we are primarily testing formatting and pagination, we keep the
# test out of the fixture groups on the assumption that all search and
# query algorithms output is formatted by the same code.
#
# NOTE: When developing, or after modifying search or query algorithms,
# you are highly recommended to run this suite with the "test" functions
# converted to "verify" - just in case!
#
package Fn_SEARCH;

use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );
use Assert;
use Foswiki::Search;
use Foswiki::Search::InfoCache;

use File::Spec qw(case_tolerant);       #TODO: this really should be in the Store somehow - but its not worth doing now, as we should really obliterate the issue

sub new {
    my $self = shift()->SUPER::new( 'SEARCH', @_ );
    return $self;
}

# This particular test makes perl chew several hundred megabytes underl 5.10.0
# Devel::Leak::Object does not report any particular problems with this test.
# This test is run in a separate process to be able to reclaim that memory
# after the test is complete.
sub run_in_new_process {
    return 1;
}

sub set_up {
    my ($this) = shift;
    $this->SUPER::set_up(@_);

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'OkTopic',
        "BLEEGLE blah/matchme.blah" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'OkATopic',
        "BLEEGLE dontmatchme.blah" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'OkBTopic',
        "BLEEGLE dont.matchmeblah" );
    $topicObject->save();
}

#TODO: figure out how to bomb out informativly if a dependency for one of the algo's isn't met - like no grep...
sub fixture_groups {
    my ( %salgs, %qalgs );
    foreach my $dir (@INC) {
        if ( opendir( my $Dir, "$dir/Foswiki/Store/SearchAlgorithms" ) ) {
            foreach my $alg ( readdir $Dir ) {
                next unless $alg =~ /^(.*)\.pm$/;
                $alg = $1;
                # skip forking search for now, its extremely broken
                # on windows
                next if ($^O eq 'MSWin32' && $alg eq 'Forking');
                $salgs{$alg} = 1;
            }
            closedir($Dir);
        }
        if ( opendir( my $Dir, "$dir/Foswiki/Store/QueryAlgorithms" ) ) {
            foreach my $alg ( readdir $Dir ) {
                next unless $alg =~ /^(.*)\.pm$/;
                $alg = $1;
                $qalgs{$alg} = 1;
            }
            closedir($Dir);
        }
    }
    my @groups;
    foreach my $alg ( keys %salgs ) {
        my $fn = $alg . 'Search';
        push( @groups, $fn );
        next if ( defined(&$fn) );
        eval <<SUB;
sub $fn {
require Foswiki::Store::SearchAlgorithms::$alg;
\$Foswiki::cfg{Store}{SearchAlgorithm} = 'Foswiki::Store::SearchAlgorithms::$alg'; }
SUB
        die $@ if $@;
    }
    foreach my $alg ( keys %qalgs ) {
        my $fn = $alg . 'Query';
        push( @groups, $fn );
        next if ( defined(&$fn) );
        eval <<SUB;
sub $fn {
require Foswiki::Store::QueryAlgorithms::$alg;
\$Foswiki::cfg{Store}{QueryAlgorithm} = 'Foswiki::Store::QueryAlgorithms::$alg'; }
SUB
        die $@ if $@;
    }

    return (\@groups);
}

sub loadExtraConfig {
    my $this = shift; # the Test::Unit::TestCase object
    my $context = shift;
    
    $this->SUPER::loadExtraConfig($context, @_);
    #turn on the MongoDBPlugin so that the saved data goes into mongoDB
    #This is temoprary until Crawford and I cna find a way to push dependencies into unit tests
    if (($Foswiki::cfg{Store}{SearchAlgorithm} =~ /MongoDB/) or 
        ($Foswiki::cfg{Store}{QueryAlgorithm} =~ /MongoDB/) or 
        ($context =~ /MongoDB/)) {
        $Foswiki::cfg{Plugins}{MongoDBPlugin}{Module} = 'Foswiki::Plugins::MongoDBPlugin'; 
        $Foswiki::cfg{Plugins}{MongoDBPlugin}{Enabled} = 1; 
        $Foswiki::cfg{Plugins}{MongoDBPlugin}{EnableOnSaveUpdates} = 1; 
        
        #push(@{$Foswiki::cfg{Store}{Listeners}}, 'Foswiki::Plugins::MongoDBPlugin::Listener');
        $Foswiki::cfg{Store}{Listeners}{'Foswiki::Plugins::MongoDBPlugin::Listener'} = 1; 
        require Foswiki::Plugins::MongoDBPlugin;
        Foswiki::Plugins::MongoDBPlugin::getMongoDB()->remove('current', {'_web' => $this->{test_web}});
    }
}

sub tear_down {
    my $this = shift; # the Test::Unit::TestCase object
    
    $this->SUPER::tear_down(@_);
    #need to clear the web every test?
    if (($Foswiki::cfg{Store}{SearchAlgorithm} =~ /MongoDB/) or 
        ($Foswiki::cfg{Store}{QueryAlgorithm} =~ /MongoDB/)) {
        require Foswiki::Plugins::MongoDBPlugin;
        Foswiki::Plugins::MongoDBPlugin::getMongoDB()->remove('current', {'_web' => $this->{test_web}});
    }
}

sub verify_simple {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" topic="OkATopic,OkBTopic,OkTopic" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_Item4692 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"BLEEGLE" topic="NonExistant" nonoise="on" format="$topic"}%');

    $this->assert_str_equals( '', $result );
}

sub verify_b {
    my $this = shift;

    # Test regex with \b, used in rename searches
    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\bmatc[h]me\b" type="regex" topic="OkATopic,OkBTopic,OkTopic" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
}

sub verify_topicName {
    my $this = shift;

    # Test topic name search

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Ok.*" type="regex" scope="topic" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_regex_trivial {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_literal {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_keyword {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_word {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"blah" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkATopic/, $result );

    # 'blah' is in OkATopic, but not as a word
    $this->assert_does_not_match( qr/OkBTopic/, $result, $result );
}

sub verify_scope_all_type_word {
    my $this = shift;
    
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'VirtualBeer',
        "There are alot of Virtual Beers to go around" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'RealBeer',
        "There are alot of Virtual Beer to go around" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'FamouslyBeered',
        "Virtually speaking there could be alot of famous Beers" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'VirtualLife',
        "In a all life, I would expect to find fine Beer" );
    $topicObject->save();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"Virtual Beer" type="word" scope="all" nonoise="on" format="$topic"}%'
      );

    my $expected = <<EXPECT;
RealBeer
VirtualBeer
VirtualLife
EXPECT
    $this->assert_str_equals( $expected,  $result."\n" );
}
sub verify_scope_all_type_keyword {
    my $this = shift;
    
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'VirtualBeer',
        "There are alot of Virtual Beers to go around" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'RealBeer',
        "There are alot of Virtual Beer to go around" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'FamouslyBeered',
        "Virtually speaking there could be alot of famous Beers" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'VirtualLife',
        "In a all life, I would expect to find fine Beer" );
    $topicObject->save();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"Virtual Beer" type="keyword" scope="all" nonoise="on" format="$topic"}%'
      );

    my $expected = <<EXPECT;
FamouslyBeered
RealBeer
VirtualBeer
VirtualLife
EXPECT
    $this->assert_str_equals( $expected,  $result."\n" );
}

sub verify_scope_all_type_literal {
    my $this = shift;
    
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'VirtualBeer',
        "There are alot of Virtual Beers to go around" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'RealBeer',
        "There are alot of Virtual Beer to go around" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'FamouslyBeered',
        "Virtually speaking there could be alot of famous Beers" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'VirtualLife',
        "In a all life, I would expect to find fine Beer" );
    $topicObject->save();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"Virtual Beer" type="literal" scope="all" nonoise="on" format="$topic"}%'
      );

    my $expected = <<EXPECT;
RealBeer
VirtualBeer
EXPECT
    $this->assert_str_equals( $expected,  $result."\n" );
}

# Verify that the default result orering is independent of the web= and
# topic= parameters
sub verify_default_alpha_order_query {
    my $this   = shift;
    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
                "1" 
                type="query"
                web="System,Main,Sandbox"
                topic="WebSearch,WebHome,WebPreferences"
                nonoise="on" 
                format="$web.$topic"
        }%'
    );
    my $expected = <<EXPECT;
Main.WebHome
Main.WebPreferences
Main.WebSearch
Sandbox.WebHome
Sandbox.WebPreferences
Sandbox.WebSearch
System.WebHome
System.WebPreferences
System.WebSearch
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub verify_default_alpha_order_search {
    my $this   = shift;
    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
                "." 
                type="regex"
                web="System,Main,Sandbox"
                topic="WebSearch,WebHome,WebPreferences"
                nonoise="on" 
                format="$web.$topic"
        }%'
    );
    my $expected = <<EXPECT;
Main.WebHome
Main.WebPreferences
Main.WebSearch
Sandbox.WebHome
Sandbox.WebPreferences
Sandbox.WebSearch
System.WebHome
System.WebPreferences
System.WebSearch
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

#####################
sub _septic {
    my ( $this, $head, $foot, $sep, $results, $expected ) = @_;
    my $str = $results ? '*Topic' : 'Septic';
    $head = $head        ? 'header="HEAD"'      : '';
    $foot = $foot        ? 'footer="FOOT"'      : '';
    $sep  = defined $sep ? "separator=\"$sep\"" : '';
    my $result =
      $this->{test_topicObject}->expandMacros(
"%SEARCH{\"name~'$str'\" type=\"query\" nosearch=\"on\" nosummary=\"on\" nototal=\"on\" format=\"\$topic\" $head $foot $sep}%"
      );
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

#####################

sub test_no_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 0, undef, 1, <<EXPECT);
OkATopic
OkBTopic
OkTopic
EXPECT
}

sub test_no_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 0, undef, 0, <<EXPECT);
EXPECT
}

sub test_no_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 0, "", 1, <<EXPECT);
OkATopicOkBTopicOkTopic
EXPECT
}

sub test_no_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 0, "", 0, <<EXPECT);
EXPECT
}

sub test_no_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 0, ",", 1, <<EXPECT);
OkATopic,OkBTopic,OkTopic
EXPECT
}

sub test_no_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 0, ",", 0, <<EXPECT);
EXPECT
}
#####################

sub test_no_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 1, undef, 1, <<EXPECT);
OkATopic
OkBTopic
OkTopic
FOOT
EXPECT
}

sub test_no_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 1, undef, 0, <<EXPECT);
EXPECT
}

sub test_no_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 1, "", 1, <<EXPECT);
OkATopicOkBTopicOkTopicFOOT
EXPECT
}

sub test_no_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic( 0, 1, "", 0, <<EXPECT);
EXPECT
}

sub test_no_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic( 0, 1, ",", 1, <<EXPECT);
OkATopic,OkBTopic,OkTopicFOOT
EXPECT
}

#####################

sub test_with_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 1, undef, 1, <<EXPECT);
HEAD
OkATopic
OkBTopic
OkTopic
FOOT
EXPECT
}

sub test_with_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 1, undef, 0, <<EXPECT);
EXPECT
}

sub test_with_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 1, "", 1, <<EXPECT);
HEADOkATopicOkBTopicOkTopicFOOT
EXPECT
}

sub test_with_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 1, "", 0, <<EXPECT);
EXPECT
}

sub test_with_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 1, ",", 1, <<EXPECT);
HEADOkATopic,OkBTopic,OkTopicFOOT
EXPECT
}

sub test_with_header_with_footer_with_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 1, ",", 0, <<EXPECT);
EXPECT
}

#####################

sub test_with_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 0, undef, 1, <<EXPECT);
HEAD
OkATopic
OkBTopic
OkTopic
EXPECT
}

sub test_with_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 0, undef, 0, <<EXPECT);
EXPECT
}

sub test_with_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 0, "", 1, <<EXPECT);
HEADOkATopicOkBTopicOkTopic
EXPECT
}

sub test_with_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 0, "", 0, <<EXPECT);
EXPECT
}

sub test_with_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_septic( 1, 0, ",", 1, <<EXPECT);
HEADOkATopic,OkBTopic,OkTopic
EXPECT
}

sub test_with_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_septic( 1, 0, ",", 0, <<EXPECT);
EXPECT
}

sub test_no_header_no_footer_with_nl_separator {
    my $this = shift;
    $this->_septic( 0, 0, '$n', 1, <<EXPECT);
OkATopic
OkBTopic
OkTopic
EXPECT
}

sub verify_regex_match {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"match" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_literal_match {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"match" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_keyword_match {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"match" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_word_match {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"match" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/OkTopic/,  $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
}

sub verify_regex_matchme {
    my $this = shift;

    # ---------------------
    # Search string 'matchme'
    # regex

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_literal_matchme {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );
}

sub verify_keyword_matchme {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/,  $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );

}

sub verify_word_matchme {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_minus_regex {
    my $this = shift;

    # ---------------------
    # Search string 'matchme -dont'
    # regex

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme -dont" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/OkTopic/,  $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
}

sub verify_minus_literal {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme -dont" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/OkTopic/,  $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_minus_keyword {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme -dont" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_minus_word {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"matchme -dont" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_slash_regex {
    my $this = shift;

    # ---------------------
    # Search string 'blah/matchme.blah'
    # regex

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah/matchme.blah" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_slash_literal {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah/matchme.blah" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_slash_keyword {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah/matchme.blah" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_slash_word {
    my $this = shift;

    # word

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"blah/matchme.blah" type="word" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_matches( qr/OkTopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );

}

sub verify_quote_regex {
    my $this = shift;

    # ---------------------
    # Search string 'BLEEGLE dont'
    # regex

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"BLEEGLE dont\"" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/OkTopic/,  $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );

}

sub verify_quote_literal {
    my $this = shift;

    # literal

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"BLEEGLE dont\"" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/OkTopic/,  $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
    $this->assert_does_not_match( qr/OkBTopic/, $result );

}

sub verify_quote_keyword {
    my $this = shift;

    # keyword

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"BLEEGLE dont\"" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );

    $this->assert_does_not_match( qr/OkTopic/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
    $this->assert_matches( qr/OkATopic/, $result );

}

sub verify_quote_word {
    my $this = shift;

    # word
    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"BLEEGLE dont\"" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_does_not_match( qr/OkTopic/,  $result );
    $this->assert_does_not_match( qr/OkATopic/, $result );
    $this->assert_matches( qr/OkBTopic/, $result );
}

sub verify_SEARCH_3860 {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros( <<'HERE');
%SEARCH{"BLEEGLE" topic="OkTopic" format="$wikiname $wikiusername" nonoise="on" }%
HERE
    my $wn = $this->{session}->{users}->getWikiName( $this->{session}->{user} );
    $this->assert_str_equals( "$wn $this->{users_web}.$wn\n", $result );

    $result = $this->{test_topicObject}->expandMacros( <<'HERE');
%SEARCH{"BLEEGLE" topic="OkTopic" format="$createwikiname $createwikiusername" nonoise="on" }%
HERE
    $this->assert_str_equals( "$wn $this->{users_web}.$wn\n", $result );
}

sub verify_search_empty_regex {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"" type="regex" scope="text" nonoise="on" format="$topic"}%');
    $this->assert_str_equals( "", $result );
}

sub verify_search_empty_literal {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );
}

sub verify_search_empty_keyword {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );
}

sub verify_search_empty_word {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"" type="word" scope="text" nonoise="on" format="$topic"}%');
    $this->assert_str_equals( "", $result );
}

sub verify_search_numpty_regex {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"something.Very/unLikelyTo+search-for;-\)" type="regex" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );
}

sub verify_search_numpty_literal {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"something.Very/unLikelyTo+search-for;-)" type="literal" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );
}

sub verify_search_numpty_keyword {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"something.Very/unLikelyTo+search-for;-)" type="keyword" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );
}

sub verify_search_numpty_word {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"something.Very/unLikelyTo+search-for;-)" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( "", $result );
}

sub set_up_for_formatted_search {
    my $this = shift;

    my $text = <<'HERE';
%META:TOPICINFO{author="ProjectContributor" date="1169714817" format="1.1" version="1.2"}%
%META:TOPICPARENT{name="TestCaseAutoFormattedSearch"}%
!MichaelAnchor, One/WIKI.NET and !AnnaAnchor lived in Skagen in !DenmarkEurope!. There is a very nice museum you can visit!

This text is fill in text which is there to ensure that the unique word below does not show up in a summary.

   * Bullet 1
   * Bullet 2
   * Bullet 3
   * Bullet 4

%META:FORM{name="FormattedSearchForm"}%
%META:FIELD{name="Name" attributes="" title="Name" value="!AnnaAnchor"}%
HERE

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'FormattedSearchTopic1', $text );
    $topicObject->save();
}

sub test_footer_with_ntopics {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"name~\'*Topic\'" type="query"  nonoise="on" footer="Total found: $ntopics" format="$topic"}%'
      );

    $this->assert_str_equals(
        join( "\n", sort qw(OkATopic OkBTopic OkTopic) ) . "\nTotal found: 3",
        $result );
}

sub test_multiple_and_footer_with_ntopics_and_nhits {
    my $this = shift;

    $this->set_up_for_formatted_search();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Bullet" type="regex" multiple="on" nonoise="on" footer="Total found: $ntopics, Hits: $nhits" format="$text - $nhits"}%'
      );

    $this->assert_str_equals(
"   * Bullet 1 - 1\n   * Bullet 2 - 2\n   * Bullet 3 - 3\n   * Bullet 4 - 4\nTotal found: 1, Hits: 4",
        $result
    );
}

sub test_footer_with_ntopics_empty_format {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"name~\'*Topic\'" type="query"  nonoise="on" footer="Total found: $ntopics" format="" separator=""}%'
      );

    $this->assert_str_equals( "Total found: 3", $result );
}

sub test_nofinalnewline {
    my $this = shift;

    # nofinalnewline="off"
    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"name~\'OkTopic\'" type="query"  nonoise="on" format="$topic" nofinalnewline="off"}%'
      );

    $this->assert_str_equals( "OkTopic\n", $result );
    
    # nofinalnewline="on"
    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"name~\'OkTopic\'" type="query"  nonoise="on" format="$topic" nofinalnewline="on"}%'
      );

    $this->assert_str_equals( "OkTopic", $result );

    # nofinalnewline should default be on
    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"name~\'OkTopic\'" type="query"  nonoise="on" format="$topic"}%'
      );

    $this->assert_str_equals( "OkTopic", $result );

}

sub test_formatted_search_summary_with_exclamation_marks {
    my $this    = shift;
    my $session = $this->{session};

    $this->set_up_for_formatted_search();
    my $actual, my $expected;

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Anna" topic="FormattedSearchTopic1" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="$summary"}%'
      );
    $actual = $this->{test_topicObject}->renderTML($actual);
    $expected =
'<nop>MichaelAnchor, One/<nop>WIKI.<nop><nop>NET and <nop>AnnaAnchor lived in Skagen in <nop>DenmarkEurope!. There is a very nice museum you can visit!';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Anna" topic="FormattedSearchTopic1" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="$formfield(Name)"}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>AnnaAnchor';
    $this->assert_str_equals( $expected, $actual );
}

# Item8718
sub test_formatted_search_with_exclamation_marks_inside_bracket_link {
    my $this    = shift;
    my $session = $this->{session};

    $this->set_up_for_formatted_search();
    my $actual, my $expected;

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Anna" topic="FormattedSearchTopic1" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="[[$web.$topic][$formfield(Name)]]"}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $actual = _cut_the_crap($actual);
    $expected = '<a href=""><nop>AnnaAnchor</a>';
    
    $this->assert_str_equals( $expected, $actual );
}

sub test_METASEARCH {
    my $this    = shift;
    my $session = $this->{session};

    $this->set_up_for_formatted_search();
    my $actual, my $expected;

    $actual =
      $this->{test_topicObject}->expandMacros(
'%METASEARCH{type="topicmoved" topic="FormattedSearchTopic1" title="This topic used to exist and was moved to: "}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = 'This topic used to exist and was moved to: ';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%METASEARCH{type="parent" topic="TestCaseAutoFormattedSearch" title="Children: "}%'
      );
    $actual = $this->{test_topicObject}->renderTML($actual);
    $expected =
      $this->{test_topicObject}->renderTML('Children: FormattedSearchTopic1 ');
    $this->assert_str_equals( $expected, $actual );
}

sub set_up_for_queries {
    my $this = shift;
    my $text = <<'HERE';
%META:TOPICINFO{author="TopicUserMapping_guest" date="1178612772" format="1.1" version="1.1"}%
%META:TOPICPARENT{name="WebHome"}%
something before. Another
This is QueryTopic FURTLE
somethig after
%META:FORM{name="TestForm"}%
%META:FIELD{name="Field1" attributes="H" title="A Field" value="A Field"}%
%META:FIELD{name="Field2" attributes="" title="Another Field" value="2"}%
%META:FIELD{name="Firstname" attributes="" title="First Name" value="Emma"}%
%META:FIELD{name="Lastname" attributes="" title="First Name" value="Peel"}%
%META:TOPICMOVED{by="TopicUserMapping_guest" date="1176311052" from="Sandbox.TestETP" to="Sandbox.TestEarlyTimeProtocol"}%
%META:FILEATTACHMENT{name="README" comment="Blah Blah" date="1157965062" size="5504"}%
HERE
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'QueryTopic',
        $text );
    $topicObject->save();

    $text = <<'HERE';
%META:TOPICINFO{author="TopicUserMapping_guest" date="12" format="1.1" version="1.2"}%
first line
This is QueryTopicTwo SMONG
third line
%META:TOPICPARENT{name="QueryTopic"}%
%META:FORM{name="TestyForm"}%
%META:FIELD{name="FieldA" attributes="H" title="B Field" value="7"}%
%META:FIELD{name="FieldB" attributes="" title="Banother Field" value="8"}%
%META:FIELD{name="Firstname" attributes="" title="Pre Name" value="John"}%
%META:FIELD{name="Lastname" attributes="" title="Post Name" value="Peel"}%
%META:FIELD{name="form" attributes="" title="Blah" value="form good"}%
%META:FIELD{name="FORM" attributes="" title="Blah" value="FORM GOOD"}%
%META:FILEATTACHMENT{name="porn.gif" comment="Cor" date="15062" size="15504"}%
%META:FILEATTACHMENT{name="flib.xml" comment="Cor" date="1157965062" size="1"}%
HERE
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'QueryTopicTwo',
        $text );
    $topicObject->save();

    $this->{session}->finish();
    my $query = new Unit::Request("");
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->{session} = new Foswiki( undef, $query );
    $this->assert_str_equals( $this->{test_web}, $this->{session}->{webName} );
    $Foswiki::Plugins::SESSION = $this->{session};

    $this->{test_topicObject} =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
}

# NOTE: most query ops are tested in Fn_IF.pm, and are not re-tested here

my $stdCrap = 'type="query" nonoise="on" format="$topic" separator=" "}%';

sub verify_parentQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"parent.name=\'WebHome\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub verify_attachmentSizeQuery1 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"attachments[size > 0]"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic QueryTopicTwo', $result );
}

sub verify_attachmentSizeQuery2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"META:FILEATTACHMENT[size > 10000]"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
}

sub verify_indexQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"attachments[name=\'flib.xml\']"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
}

sub verify_gropeQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"Lastname=\'Peel\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic QueryTopicTwo', $result );
}

sub verify_4580Query1 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"text ~ \'*SMONG*\' AND Lastname=\'Peel\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
}

sub verify_4580Query2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"text ~ \'*FURTLE*\' AND Lastname=\'Peel\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub verify_gropeQuery2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"Lastname=\'Peel\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic QueryTopicTwo', $result );
}

sub verify_formQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"form.name=\'TestyForm\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
}

sub verify_formQuery2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"TestForm"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub verify_formQuery3 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"TestForm[name=\'Field1\'].value=\'A Field\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub verify_formQuery4 {
    my $this = shift;

    if (  ($Foswiki::cfg{OS} eq 'WINDOWS')
        and ($Foswiki::cfg{DetailedOS} ne 'cygwin')
        and ($Foswiki::cfg{Store}{SearchAlgorithm} eq 'Foswiki::Store::SearchAlgorithms::Forking') )
    {
        $this->expect_failure();
        $this->annotate("THIS IS WINDOWS & grep; Test will fail because of Item1072");
    }
    
    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"TestForm.Field1=\'A Field\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub verify_formQuery5 {
    my $this = shift;

    if (  ($Foswiki::cfg{OS} eq 'WINDOWS')
        and ($Foswiki::cfg{DetailedOS} ne 'cygwin')
        and ($Foswiki::cfg{Store}{SearchAlgorithm} eq 'Foswiki::Store::SearchAlgorithms::Forking') )
    {
        $this->expect_failure();
        $this->annotate("THIS IS WINDOWS & grep; Test will fail because of Item1072");
    }

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"TestyForm.form=\'form good\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
    $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"TestyForm.FORM=\'FORM GOOD\'"' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
}

sub verify_refQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"parent.name/(Firstname ~ \'*mm?\' AND Field2=2)"'
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );
}

# make sure syntax errors are handled cleanly. All the error cases thrown by
# the infix parser are tested more thoroughly in Fn_IF, and don't have to
# be re-tested here.
sub verify_badQuery1 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}->expandMacros( '%SEARCH{"A * B"' . $stdCrap );
    $this->assert_matches( qr/Error was: Syntax error in 'A \* B' at ' \* B'/s,
        $result );
}

# Compare performance of an RE versus a query. Only enable this if you are
# interested in benchmarking.
sub benchmarktest_largeQuery {
    my $this = shift;

    # Generate 1000 topics
    # half (500) of these match the first term of the AND
    # 100 match the second
    # 10 match the third
    # 1 matches the fourth

    for my $n ( 1 .. 21 ) {
        my $vA = ( $n <= 500 ) ? 'A' : 'B';
        my $vB = ( $n <= 100 ) ? 'A' : 'B';
        my $vC = ( $n <= 10 )  ? 'A' : 'B';
        my $vD = ( $n == 1 )   ? 'A' : 'B';
        my $vE = ( $n == 2 )   ? 'A' : 'B';
        my $text = <<HERE;
%META:TOPICINFO{author="TopicUserMapping_guest" date="12" format="1.1" version="1.2"}%
---+ Progressive Sexuality
A Symbol Interpreted In American Architecture. Meta-Physics Of Marxism & Poverty In The American Landscape. Exploration Of Crime In Mexican Sculptures: A Study Seen In American Literature. Brief Survey Of Suicide In Italian Art: The Big Picture. Special Studies In Bisexual Female Architecture. Brief Survey Of Suicide In Polytheistic Literature: Analysis, Analysis, and Critical Thinking. Radical Paganism: Modern Theories. Liberal Mexican Religion In The Modern Age. Selected Topics In Global Warming: $vD Policy In Modern America. Survey Of The Aesthetic Minority Revolution In The American Landscape. Populist Perspectives: Myth & Reality. Ethnicity In Modern America: The Bisexual Latino Condition. Postmodern Marxism In Modern America. Female Literature As A Progressive Genre. Horror & Life In Recent Times. The Universe Of Female Values In The Postmodern Era.

---++ Work, Politics, And Conflict In European Drama: A Symbol Interpreted In 20th Century Poetry
Sexuality & Socialism In Modern Society. Special Studies In Early Egyptian Art: A Study Of Globalism In The United States. Meta-Physics Of Synchronized Swimming: The Baxter-Floyd Principle At Work. Ad-Hoc Investigation Of Sex In Middle Eastern Art: Contemporary Theories. Concepts In Eastern Mexican Folklore. The Liberated Dimension Of Western Minority Mythology. French Art Interpretation: A Figure Interpreted In American Drama

---+ Theories Of Liberal Pre-Cubism & The Crowell Law.
We are committed to enhance vertical sub-functionalities and skill sets. Our function is to competently reinvent our mega-relationships. Our responsibility is to expertly engineer content. Our obligation is to continue to zealously simplify our customer-centric paradigms as part of our five-year plan to successfully market an overhyped more expensive line of products and produce more dividends for our serfs. $vA It is our mission to optimize progressive schemas and supply-chains to better serve the country. We are committed to astutely deliver our net-niches, user-centric face time, and assets in order to dominate the economy. It is our goal to conveniently facilitate our e-paradigms, our frictionless skill sets, and our architectures to shore up revenue for our workers. Our goal is to work towards skillfully enabling catalysts for metrics.

We resolve to endeavor to synthesize our sub-partnerships in order that we may intelligently unleash bleeding-edge total quality management as part of our master plan to burgeon our bottom line. It is our business to work to enhance our initiatives in order that we may take $vB over the nation and take over the country. It's our task to reinvent massively-parallel relationships. We execute a strategic plan to quickly facilitate our niches and enthusiastically maximize our extensible perspectives.

Our obligation is to work to spearhead cutting-edge portals so that hopefully we may successfully market an overhyped poor product line.

We have committed to work to effectively facilitate global e-channels as part of a larger $vC strategy to create a higher quality product and create a lot of bucks. Our duty is to work to empower our revolutionary functionalities and simplify our idiot-proof synergies as a component of our plan to beat the snot out of our enemies. We resolve to engage our mega-eyeballs, our e-bandwidth, and intuitive face time in order to earn a lot of scratch. It's our obligation to generate our niches.

---+ It is our job to strive to simplify our bandwidth.
We have committed to enable customer-centric supply-chains and our mega-channels as part of our business plan to meet the wants of our valued customers.
We have committed to take steps towards $vE reinventing our cyber-key players and harnessing frictionless net-communities so that hopefully we may better serve our customers.
%META:FORM{name="TestForm"}%
%META:FIELD{name="FieldA" attributes="" title="Banother Field" value="$vA"}%
%META:FIELD{name="FieldB" attributes="" title="Banother Field" value="$vB"}%
%META:FIELD{name="FieldC" attributes="" title="Banother Field" value="$vC"}%
%META:FIELD{name="FieldD" attributes="" title="Banother Field" value="$vD"}%
%META:FIELD{name="FieldE" attributes="" title="Banother Field" value="$vE"}%
HERE
        my $topicObject =
          Foswiki::Meta->new( $this->{session}, $this->{test_web},
            "QueryTopic$n", $text );
        $topicObject->save();
    }
    require Benchmark;

    # Search using a regular expression
    my $start = new Benchmark;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"^[%]META:FIELD{name=\"FieldA\".*\bvalue=\"A\";^[%]META:FIELD{name=\"FieldB\".*\bvalue=\"A\";^[%]META:FIELD{name=\"FieldC\".*\bvalue=\"A\";^[%]META:FIELD{name=\"FieldD\".*\bvalue=\"A\"|^[%]META:FIELD{name=\"FieldE\".*\bvalue=\"A\"" type="regex" nonoise="on" format="$topic" separator=" "}%'
      );
    my $retime = Benchmark::timediff( new Benchmark, $start );
    $this->assert_str_equals( 'QueryTopic1 QueryTopic2', $result );

    # Repeat using a query
    $start = new Benchmark;
    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"FieldA=\'A\' AND FieldB=\'A\' AND FieldC=\'A\' AND (FieldD=\'A\' OR FieldE=\'A\')" type="query" nonoise="on" format="$topic" separator=" "}%'
      );
    my $querytime = Benchmark::timediff( new Benchmark, $start );
    $this->assert_str_equals( 'QueryTopic1 QueryTopic2', $result );
    print STDERR "Query " . Benchmark::timestr($querytime),
      "\nRE " . Benchmark::timestr($retime), "\n";
}

sub test_4347 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
"%SEARCH{\"$this->{test_topic}\" scope=\"topic\" nonoise=\"on\" format=\"\$formfield(Blah)\"}%"
      );
    $this->assert_str_equals( '', $result );
}

sub verify_likeQuery {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"text ~ \'*SMONG*\'" ' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"text ~ \'*QueryTopicTwo*\'" ' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'QueryTopicTwo' );
    $result =
      $topicObject->expandMacros( '%SEARCH{"text ~ \'*SMONG*\'" ' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'QueryTopicTwo' );
    $result = $topicObject->expandMacros(
        '%SEARCH{"text ~ \'*QueryTopicTwo*\'" ' . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

}

sub verify_likeQuery2 {
    my $this = shift;

    $this->set_up_for_queries();

    my $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"text ~ \'*SMONG*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"text ~ \'*QueryTopicTwo*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'QueryTopicTwo' );
    $result =
      $topicObject->expandMacros( '%SEARCH{"text ~ \'*SMONG*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'QueryTopicTwo' );
    $result =
      $topicObject->expandMacros( '%SEARCH{"text ~ \'*QueryTopicTwo*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopicTwo', $result );

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'QueryTopicTwo' );
    $result =
      $topicObject->expandMacros( '%SEARCH{"text ~ \'*Notinthetopics*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( '', $result );

    $result =
      $this->{test_topicObject}
      ->expandMacros( '%SEARCH{"text ~ \'*before. Another*\'" web="'
          . $this->{test_web} . '" '
          . $stdCrap );
    $this->assert_str_equals( 'QueryTopic', $result );
}

sub test_pattern {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" topic="OkATopic,OkBTopic,OkTopic" nonoise="on" format="X$pattern(.*?BLEEGLE (.*?)blah.*)Y"}%'
      );
    $this->assert_matches( qr/Xdontmatchme\.Y/, $result );
    $this->assert_matches( qr/Xdont.matchmeY/,  $result );
    $this->assert_matches( qr/XY/,              $result );
}

sub test_badpattern {
    my $this = shift;

    # The (??{ pragma cannot be run at runtime since perl 5.5

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" topic="OkATopic,OkBTopic,OkTopic" nonoise="on" format="X$pattern(.*?BL(??{\'E\' x 2})GLE( .*?)blah.*)Y"}%'
      );

    # If (??{ is evaluated, the topics should match:
    $this->assert_does_not_match( qr/XdontmatchmeY/,  $result );
    $this->assert_does_not_match( qr/Xdont.matchmeY/, $result );
    $this->assert_does_not_match( qr/X Y/,            $result );

    # If (??{ isn't evaluated, $pattern should return empty
    # and format should be XY for all 3 topics
    $this->assert_equals( 3, $result =~ s/^XY$//gm );
}

sub test_validatepattern {
    my $this = shift;
    my ( $pattern, $temp );

    # Test comment
    $pattern = Foswiki::validatePattern('foo(?#comment)bar');
    $this->assert_matches( qr/$pattern/, 'foobar' );

    # Test clustering and pattern-match modifiers
    $pattern = Foswiki::validatePattern('(?i:foo)(?-i)bar');
    $this->assert_matches( qr/$pattern/, 'FoObar' );
    $this->assert_does_not_match( qr/$pattern/, 'FoObAr' );

    # Test zero-width positive look-ahead
    $pattern = Foswiki::validatePattern('foo(?=bar)');
    $this->assert_matches( qr/$pattern/, 'foobar' );
    $this->assert_does_not_match( qr/$pattern/, 'barfoo bar' );
    $temp = 'foobar';
    $this->assert_equals( 1, $temp =~ s/$pattern// );
    $this->assert_equals( 'bar', $temp );

    # Test zero-width negative look-ahead
    $pattern = Foswiki::validatePattern('foo(?!bar)');
    $this->assert_does_not_match( qr/$pattern/, 'foobar' );
    $this->assert_matches( qr/$pattern/, 'barfoo bar' );
    $this->assert_matches( qr/$pattern/, 'foo' );
    $temp = 'fooblue';
    $this->assert_equals( 1, $temp =~ s/$pattern// );
    $this->assert_equals( 'blue', $temp );

    # Test independent sub-expression
    $pattern = Foswiki::validatePattern('foo(?>blue)bar');
    $this->assert_matches( qr/$pattern/, 'foobluebar' );

}

#Item977
sub test_formatOfLinks {
    my $this = shift;

    my $topicObject = Foswiki::Meta->new(
        $this->{session},
        $this->{test_web}, 'Item977', "---+ Apache

Apache is the [[http://www.apache.org/httpd/][well known web server]].
"
    );
    $topicObject->save();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"Item977" scope="topic" nonoise="on" format="$summary"}%');

    $this->assert_str_equals( 'Apache Apache is the well known web server.',
        $result );

#TODO: these test should move to a proper testing of Render.pm - will happen during
#extractFormat feature
    $this->assert_str_equals(
        'Apache is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
'Apache is the [[http://www.apache.org/httpd/][well known web server]].'
        )
    );

    #test a few others to try to not break things
    $this->assert_str_equals(
        'Apache is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
'Apache is the [[http://www.apache.org/httpd/ well known web server]].'
        )
    );
    $this->assert_str_equals(
        'Apache is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
            'Apache is the [[ApacheServer][well known web server]].')
    );

    #SMELL: an unexpected result :/
    $this->assert_str_equals( 'Apache is the   well known web server  .',
        $this->{session}->{renderer}
          ->TML2PlainText('Apache is the [[well known web server]].') );
    $this->assert_str_equals( 'Apache is the well known web server.',
        $this->{session}->{renderer}
          ->TML2PlainText('Apache is the well known web server.') );

}

sub _getTopicList {
    my ($this, $expected, $web, $options, $sadness) = @_;

    #    my $options = {
    #        casesensitive  => $caseSensitive,
    #        wordboundaries => $wordBoundaries,
    #        includeTopics  => $topic,
    #        excludeTopics  => $excludeTopic,
    #    };

    my $webObject = Foswiki::Meta->new( $this->{session}, $web );

    # Run the search on topics in this web
    my $search = $this->{session}->search();
    my $iter =
      Foswiki::Search::InfoCache::getTopicListIterator( $webObject, $options );

    ASSERT( UNIVERSAL::isa( $iter, 'Foswiki::Iterator' ) ) if DEBUG;
    my @topicList = ();
    while ( my $t = $iter->next() ) {
        push( @topicList, $t );
    }

    my $l1 = join(',', @$expected);
    my $l2 = join(',', @topicList);
    $this->assert_str_equals($l1, $l2, "$sadness:\nwant: $l2\n got: $l1");
    return \@topicList;
}

sub verify_getTopicList {
    my $this = shift;

    #no topics specified..
    $this->_getTopicList([
            'OkATopic', 'OkBTopic',
            'OkTopic',  'TestTopicSEARCH',
            'WebPreferences'
        ],
        $this->{test_web}, {},
        'no filters, all topics in test_web'
    );
    $this->_getTopicList([
            'WebAtom',           'WebChanges',
            'WebCreateNewTopic', 'WebHome',
            'WebIndex',          'WebLeftBar',
            'WebNotify',         'WebPreferences',
            'WebRss',            'WebSearch',
            'WebSearchAdvanced', 'WebStatistics',
            'WebTopicList'
        ],
        '_default', {},
        'no filters, all topics in test_web'
    );

    #use wildcards
    $this->_getTopicList(
        [ 'OkATopic', 'OkBTopic', 'OkTopic' ],
        $this->{test_web}, { includeTopics => 'Ok*' },
        'comma separated list'
    );
    $this->_getTopicList([
            'WebAtom',           'WebChanges',
            'WebCreateNewTopic', 'WebHome',
            'WebIndex',          'WebLeftBar',
            'WebNotify',         'WebPreferences',
            'WebRss',            'WebSearch',
            'WebSearchAdvanced', 'WebStatistics',
            'WebTopicList'
        ],
        '_default', { includeTopics => 'Web*' },
        'no filters, all topics in test_web'
    );

    #comma separated list specifed for inclusion
    $this->_getTopicList(
        [ 'OkTopic', 'TestTopicSEARCH' ],
        $this->{test_web},
        { includeTopics => 'TestTopicSEARCH,OkTopic,NoSuchTopic' },
        'comma separated list'
    );
    $this->_getTopicList(
        [ 'WebCreateNewTopic', 'WebStatistics' ],
        '_default',
        {
            includeTopics => 'WebStatistics, WebCreateNewTopic, NoSuchTopic'
           },
        'no filters, all topics in test_web'
       );

    #excludes
    $this->_getTopicList(
        [ 'OkATopic', 'OkTopic', 'TestTopicSEARCH', 'WebPreferences' ],
        $this->{test_web}, { excludeTopics => 'NoSuchTopic,OkBTopic'},
        'no filters, all topics in test_web'
    );
    $this->_getTopicList([
            'WebAtom',           'WebChanges',
            'WebCreateNewTopic', 'WebHome',
            'WebIndex',          'WebLeftBar',
            'WebNotify',         'WebPreferences',
            'WebRss',            'WebSearchAdvanced',
            'WebStatistics',     'WebTopicList'
        ],
        '_default', { excludeTopics => 'WebSearch' },
        'no filters, all topics in test_web'
    );

    #Talk about missing alot of tests
    $this->_getTopicList([
            'OkATopic', 'OkBTopic',
            'OkTopic',  'TestTopicSEARCH',
            'WebPreferences'
        ],
        $this->{test_web}, { includeTopics => '*' },
        'all topics, using wildcard'
    );
    $this->_getTopicList([ 'OkATopic', 'OkBTopic', 'OkTopic' ],
        $this->{test_web}, { includeTopics => 'Ok*' },
        'Ok* topics, using wildcard'
    );
    $this->_getTopicList(
        [],
        $this->{test_web},
        {
            includeTopics => 'ok*',
            casesensitive => 1
           },
        'case sensitive ok* topics, using wildcard'
       );
    $this->_getTopicList(
        [ 'OkATopic', 'OkBTopic', 'OkTopic' ],
        $this->{test_web},
        {
            includeTopics => 'ok*',
            casesensitive => 0
           },
        'case insensitive ok* topics, using wildcard'
    );
    
    if (File::Spec->case_tolerant()) {
        print STDERR "WARNING: case insensitive file system, skipping a test\n";
    } else {
        # this test won't work on Mac OS X or windows.
        $this->_getTopicList(
            [],
            $this->{test_web},
            {
                includeTopics => 'okatopic',
                casesensitive => 1
               },
            'case sensitive okatopic topic 1'
        );
    }
    
    $this->_getTopicList(
        ['OkATopic'],
        $this->{test_web},
        {
            includeTopics => 'okatopic',
            casesensitive => 0
           },
        'case insensitive okatopic topic'
    );
    ##### same again, with excludes.
    $this->_getTopicList(
        [
            'OkATopic', 'OkBTopic',
            'OkTopic',  'TestTopicSEARCH',
            'WebPreferences'
           ],
        $this->{test_web},
        {
            includeTopics => '*',
            excludeTopics => 'web*'
           },
        'all topics, using wildcard'
    );
    $this->_getTopicList(
        [ 'OkATopic', 'OkBTopic', 'OkTopic' ],
        $this->{test_web},
        {
            includeTopics => 'Ok*',
            excludeTopics => 'okatopic'
           },
        'Ok* topics, using wildcard'
    );
    $this->_getTopicList(
        [],
        $this->{test_web},
        {
            includeTopics => 'ok*',
            excludeTopics => 'WebPreferences',
            casesensitive => 1
           },
        'case sensitive ok* topics, using wildcard'
    );
    $this->_getTopicList(
        [ 'OkATopic', 'OkBTopic', 'OkTopic' ],
        $this->{test_web},
        {
            includeTopics => 'ok*',
            excludeTopics => '',
            casesensitive => 0
           },
        'case insensitive ok* topics, using wildcard'
    );

    $this->_getTopicList(
        [ 'OkBTopic', 'OkTopic' ],
        $this->{test_web},
        {
            includeTopics => 'Ok*',
            excludeTopics => '*ATopic',
            casesensitive => 1
           },
        'case sensitive okatopic topic 2'
    );

    $this->_getTopicList(
        [ 'OkATopic', 'OkBTopic', 'OkTopic' ],
        
            $this->{test_web},
            {
                includeTopics => 'Ok*',
                excludeTopics => '*atopic',
                casesensitive => 1
            }
        ,
        'case sensitive okatopic topic 3'
    );

    $this->_getTopicList(
        [ 'OkBTopic', 'OkTopic' ],
        $this->{test_web},
        {
            includeTopics => 'ok*topic',
            excludeTopics => 'okatopic',
            casesensitive => 0
           },
        'case insensitive okatopic topic'
    );

}

sub verify_casesensitivesetting {
    my $this    = shift;
    my $session = $this->{session};

    my $actual, my $expected;

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkTopic,<nop>TestTopicSEARCH';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"bleegle" type="regex" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" type="regex" multiple="on" casesensitive="off" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkTopic,<nop>TestTopicSEARCH';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"bleegle" type="regex" multiple="on" casesensitive="off" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkTopic,<nop>TestTopicSEARCH';
    $this->assert_str_equals( $expected, $actual );

    #topic scope
    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Ok" type="regex" scope="topic" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkTopic';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"ok" type="regex" scope="topic" multiple="on" casesensitive="on" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Ok" type="regex" scope="topic" multiple="on" casesensitive="off" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkTopic';
    $this->assert_str_equals( $expected, $actual );

    $actual =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"ok" type="regex" scope="topic" multiple="on" casesensitive="off" nosearch="on" noheader="on" nototal="on" format="<nop>$topic" separator=","}%'
      );
    $actual   = $this->{test_topicObject}->renderTML($actual);
    $expected = '<nop>OkATopic,<nop>OkBTopic,<nop>OkTopic';
    $this->assert_str_equals( $expected, $actual );

}

sub verify_Item6082_Search {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestForm',
        <<'FORM');
| *Name*         | *Type* | *Size* | *Value*   | *Tooltip message* | *Attributes* |
| Why | text | 32 | | Mandatory field | M |
| Ecks | select | 1 | %SEARCH{"TestForm.Ecks~'Blah*'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}% | | |
FORM
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'SplodgeOne',
        <<FORM);
%META:FORM{name="TestForm"}%
%META:FIELD{name="Ecks" attributes="" title="X" value="Blah"}%
FORM
    $topicObject->save();

    my $actual = $topicObject->expandMacros(
'%SEARCH{"TestForm.Ecks~\'Blah*\'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}%'
    );
    my $expected = 'SplodgeOne;Blah';
    $this->assert_str_equals( $expected, $actual );

}

sub verify_quotemeta {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestForm',
        <<'FORM');
| *Name*         | *Type* | *Size* | *Value*   | *Tooltip message* | *Attributes* |
| Why | text | 32 | | Mandatory field | M |
| Ecks | select | 1 | %SEARCH{"TestForm.Ecks~'Blah*'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}% | | |
FORM
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'SplodgeOne',
        <<FORM);
%META:FORM{name="TestForm"}%
%META:FIELD{name="Ecks" attributes="" title="X" value="Blah"}%
FORM
    $topicObject->save();

    my $actual = $topicObject->expandMacros(
'%SEARCH{"TestForm.Ecks~\'Blah*\'" type="query" order="topic" separator="," format="$topic;$formfield(Ecks)" nonoise="on"}%'
    );
    my $expected = 'SplodgeOne;Blah';
    $this->assert_str_equals( $expected, $actual );

}

sub verify_Search_expression {

    #make sure perl-y characters in SEARCH expressions are escaped well enough
    my $this = shift;

    my $actual = $this->{test_topicObject}->expandMacros(
        '%SEARCH{"TestForm.Ecks~\'Bl>ah*\'" type="query" nototal="on"}%' );
    my $expected = <<'HERE';
<div class="foswikiSearchResultsHeader"><span>Searched: <b><noautolink>TestForm.Ecks~'Bl&gt;ah*'</noautolink></b></span><span id="foswikiNumberOfResultsContainer"></span></div>
HERE
    
    $this->assert_str_equals( $expected, $actual );

    $actual = $this->{test_topicObject}->expandMacros(
        '%SEARCH{"TestForm.Ecks = \'B/lah*\'" type="query" nototal="on"}%' );
    $expected = <<'HERE';
<div class="foswikiSearchResultsHeader"><span>Searched: <b><noautolink>TestForm.Ecks = 'B/lah*'</noautolink></b></span><span id="foswikiNumberOfResultsContainer"></span></div>
HERE
    $this->assert_str_equals( $expected, $actual );
}

#####################
#and again for multiple webs. :(
#TODO: rewrite using named params for more flexibility
#need summary, and multiple
sub _multiWebSeptic {
    my ( $this, $head, $foot, $sep, $results, $expected, $format ) = @_;
    my $str = $results ? '*Preferences' : 'Septic';
    $head = $head        ? 'header="HEAD($web)"'            : '';
    $foot = $foot        ? 'footer="FOOT($ntopics,$nhits)"' : '';
    $sep  = defined $sep ? "separator=\"$sep\""             : '';
    $format  = '$topic' unless (defined($format));

    my $result = $this->{test_topicObject}->expandMacros(
        "%SEARCH{\"name~'$str'\" 
            web=\"System,Main\" 
            type=\"query\" 
            nosearch=\"on\" 
            nosummary=\"on\" 
            nototal=\"on\" 
            format=\"$format\" 
            $head $foot $sep }%"
    );
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

#####################

sub test_multiWeb_no_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, undef, 1, <<EXPECT);
SitePreferences
WebPreferences
DefaultPreferences
WebPreferences
EXPECT
}

sub test_multiWeb_no_header_no_footer_no_separator_with_results_counters {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, undef, 1, <<EXPECT, '$nhits, $ntopics, $index, $topic');
1, 1, 1, SitePreferences
2, 2, 2, WebPreferences
1, 1, 3, DefaultPreferences
2, 2, 4, WebPreferences
EXPECT
}

sub test_multiWeb_no_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, undef, 0, <<EXPECT);
EXPECT
}

sub test_multiWeb_no_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, "", 1, <<EXPECT);
SitePreferencesWebPreferencesDefaultPreferencesWebPreferences
EXPECT
}

sub test_multiWeb_no_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, "", 0, <<EXPECT);
EXPECT
}

sub test_multiWeb_no_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, ",", 1, <<EXPECT);
SitePreferences,WebPreferences,DefaultPreferences,WebPreferences
EXPECT
}

sub test_multiWeb_no_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 0, ",", 0, <<EXPECT);
EXPECT
}
#####################

sub test_multiWeb_no_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 1, undef, 1, <<EXPECT);
SitePreferences
WebPreferences
FOOT(2,2)DefaultPreferences
WebPreferences
FOOT(2,2)
EXPECT
}

sub test_multiWeb_no_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 1, undef, 0, <<EXPECT);
EXPECT
}

sub test_multiWeb_no_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 1, "", 1, <<EXPECT);
SitePreferencesWebPreferencesFOOT(2,2)DefaultPreferencesWebPreferencesFOOT(2,2)
EXPECT
}

sub test_multiWeb_no_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 1, "", 0, <<EXPECT);
EXPECT
}

sub test_multiWeb_no_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 0, 1, ",", 1, <<EXPECT);
SitePreferences,WebPreferencesFOOT(2,2)DefaultPreferences,WebPreferencesFOOT(2,2)
EXPECT
}

#####################

sub test_multiWeb_with_header_with_footer_no_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, undef, 1, <<EXPECT);
HEAD(Main)
SitePreferences
WebPreferences
FOOT(2,2)HEAD(System)
DefaultPreferences
WebPreferences
FOOT(2,2)
EXPECT
}

sub test_multiWeb_with_header_with_footer_no_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, undef, 0, <<EXPECT);
EXPECT
}

sub test_multiWeb_with_header_with_footer_empty_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, "", 1, <<EXPECT);
HEAD(Main)SitePreferencesWebPreferencesFOOT(2,2)HEAD(System)DefaultPreferencesWebPreferencesFOOT(2,2)
EXPECT
}

sub test_multiWeb_with_header_with_footer_empty_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, "", 0, <<EXPECT);
EXPECT
}

sub test_multiWeb_with_header_with_footer_with_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, ",", 1, <<EXPECT);
HEAD(Main)SitePreferences,WebPreferencesFOOT(2,2)HEAD(System)DefaultPreferences,WebPreferencesFOOT(2,2)
EXPECT
}

sub test_multiWeb_with_header_with_footer_with_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 1, ",", 0, <<EXPECT);
EXPECT
}

#####################

sub test_multiWeb_with_header_no_footer_no_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, undef, 1, <<EXPECT);
HEAD(Main)
SitePreferences
WebPreferences
HEAD(System)
DefaultPreferences
WebPreferences
EXPECT
}

sub test_multiWeb_with_header_no_footer_no_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, undef, 0, <<EXPECT);
EXPECT
}

sub test_multiWeb_with_header_no_footer_empty_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, "", 1, <<EXPECT);
HEAD(Main)SitePreferencesWebPreferencesHEAD(System)DefaultPreferencesWebPreferences
EXPECT
}

sub test_multiWeb_with_header_no_footer_empty_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, "", 0, <<EXPECT);
EXPECT
}

sub test_multiWeb_with_header_no_footer_with_separator_with_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, ",", 1, <<EXPECT);
HEAD(Main)SitePreferences,WebPreferencesHEAD(System)DefaultPreferences,WebPreferences
EXPECT
}

sub test_multiWeb_with_header_no_footer_with_separator_no_results {
    my $this = shift;
    $this->_multiWebSeptic( 1, 0, ",", 0, <<EXPECT);
EXPECT
}

#Item1992: calling Foswiki::Search::_makeTopicPattern repeatedly made a big mess.
sub test_web_and_topic_expansion {
    my $this   = shift;
    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
                "web" 
                type="text"
                web="System,Main,Sandbox"
                topic="WebHome,WebPreferences"
                scope="text" 
                nonoise="on" 
                format="$web.$topic"
                footer="FOOT($ntopics,$nhits)"
        }%'
    );
    my $expected = <<EXPECT;
Main.WebHome
Main.WebPreferences
FOOT(2,2)Sandbox.WebHome
Sandbox.WebPreferences
FOOT(2,2)System.WebHome
System.WebPreferences
FOOT(2,2)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

#####################
# PAGING
sub test_paging_three_webs_first_page {
    my $this = shift;
    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="1"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
Main.WebChanges
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(4,4)Sandbox.WebChanges
FOOT(1,1)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub test_paging_three_webs_second_page {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="2"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
Sandbox.WebHome
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(3,3)System.WebChanges
System.WebHome
FOOT(2,2)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub test_paging_three_webs_third_page {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="3"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
System.WebIndex
System.WebPreferences
FOOT(2,2)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub test_paging_three_webs_fourth_page {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="4"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub test_paging_three_webs_way_too_far {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="99"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

#------------------------------------
# PAGING with limit= does weird things.
sub test_paging_with_limit_first_page {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="1"
    pagesize="3"
    limit="3"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
Main.WebChanges
Main.WebHome
Main.WebIndex
FOOT(3,3)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub test_paging_with_limit_second_page {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="2"
    pagesize="3"
    limit="3"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
Sandbox.WebChanges
Sandbox.WebHome
Sandbox.WebIndex
FOOT(3,3)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub test_paging_with_limit_third_page {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="3"
    pagesize="3"
    limit="3"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
System.WebChanges
System.WebHome
System.WebIndex
FOOT(3,3)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub test_paging_with_limit_fourth_page {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="4"
    pagesize="3"
    limit="3"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub test_paging_with_limit_way_too_far {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="5"
    pagesize="3"
    limit="3"
    footer="FOOT($ntopics,$nhits)"
}%'
    );

    my $expected = <<EXPECT;
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

# Create three subwebs, and create a topic with the same name in all three
# which has a form and a field called "Order", which defines an ordering
# which is not the same as the ordering of the subwebs names. Now search
# the parent web recursively, with a sort order based on the value of the
# formfield. The sort should be based on the value of the 'Order' field.
#TODO: this is how the code has always worked, as the rendering of SEARCH results is done per web
#http://foswiki.org/Development/MakeSEARCHResultPartitioningByWebOptional
sub test_groupby_none_using_subwebs {
    my $this = shift;

    my $webObject =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/A" );
    $webObject->populateNewWeb();
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/A", 'TheTopic',
        <<CRUD);
%META:FORM{name="TestForm"}%
%META:FIELD{name="Order" title="Order" value="3"}%
CRUD
    $topicObject->save(forcedate=>1000);

    $webObject = Foswiki::Meta->new( $this->{session}, "$this->{test_web}/B" );
    $webObject->populateNewWeb();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/B", 'TheTopic',
        <<CRUD);
%META:FORM{name="TestForm"}%
%META:FIELD{name="Order" title="Order" value="1"}%
CRUD
    $topicObject->save(forcedate=>100);

    $webObject = Foswiki::Meta->new( $this->{session}, "$this->{test_web}/C" );
    $webObject->populateNewWeb();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/C", 'TheTopic',
        <<CRUD);
%META:FORM{name="TestForm"}%
%META:FIELD{name="Order" title="Order" value="2"}%
CRUD
    $topicObject->save(forcedate=>500);
    my $result;
#order by formfield, with groupby=none
 $result = $this->{test_topicObject}->expandMacros( <<GNURF );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="formfield(Order)"
 format="\$web"
 separator=","
 groupby="none"
}%
GNURF
    $this->assert_equals(
        "$this->{test_web}/B,$this->{test_web}/C,$this->{test_web}/A\n",
        $result );
        
#order by modified date, reverse=off, with groupby=none
    $result = $this->{test_topicObject}->expandMacros( <<GNURF );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="modified"
 reverse="off"
 format="\$web \$date"
 separator=", "
 groupby="none"
}%
GNURF
    $this->assert_equals(
        "$this->{test_web}/B 01 Jan 1970 - 00:01, $this->{test_web}/C 01 Jan 1970 - 00:08, $this->{test_web}/A 01 Jan 1970 - 00:16\n",
        $result );

#order by modified date, reverse=n, with groupby=none
    $result = $this->{test_topicObject}->expandMacros( <<GNURF );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="modified"
 reverse="on"
 format="\$web \$date"
 separator=", "
 groupby="none"
}%
GNURF
    $this->assert_equals(
        "$this->{test_web}/A 01 Jan 1970 - 00:16, $this->{test_web}/C 01 Jan 1970 - 00:08, $this->{test_web}/B 01 Jan 1970 - 00:01\n",
        $result );
        
#and the same again, this time using header&footer, as that is what really shows the issue.
#order by formfield, with groupby=none
    $result = $this->{test_topicObject}->expandMacros( <<GNURF );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="formfield(Order)"
 header="HEADER"
 format="\$web"
 footer="FOOTER"
 separator=", "
 groupby="none"
}%
GNURF
    $this->assert_equals(
        "HEADER$this->{test_web}/B, $this->{test_web}/C, $this->{test_web}/AFOOTER\n",
        $result );
        
#order by modified date, reverse=off, with groupby=none
    $result = $this->{test_topicObject}->expandMacros( <<GNURF );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="modified"
 reverse="off"
 header="HEADER"
 format="\$web \$date"
 footer="FOOTER"
 separator=", "
 groupby="none"
}%
GNURF
    $this->assert_equals(
        "HEADER$this->{test_web}/B 01 Jan 1970 - 00:01, $this->{test_web}/C 01 Jan 1970 - 00:08, $this->{test_web}/A 01 Jan 1970 - 00:16FOOTER\n",
        $result );

#order by modified date, reverse=n, with groupby=none
    $result = $this->{test_topicObject}->expandMacros( <<GNURF );
%SEARCH{"Order!=''"
 type="query"
 web="$this->{test_web}"
 topic="TheTopic"
 recurse="on"
 nonoise="on"
 order="modified"
 reverse="on"
 header="HEADER"
 format="\$web \$date"
 footer="FOOTER"
 separator=", "
 groupby="none"
}%
GNURF
    $this->assert_equals(
        "HEADER$this->{test_web}/A 01 Jan 1970 - 00:16, $this->{test_web}/C 01 Jan 1970 - 00:08, $this->{test_web}/B 01 Jan 1970 - 00:01FOOTER\n",
        $result );
#order by modified, limit=2, with groupby=none
    $result = $this->{test_topicObject}->expandMacros( <<GNURF );
%SEARCH{"1"
 type="query"
 web="$this->{test_web},Main,System,Sandbox,"
 topic="WebHome"
 recurse="on"
 nonoise="on"
 order="modified"
 header="HEADER"
 format="\$web \$topic"
 footer="FOOTER"
 separator=", "
 groupby="none"
 limit="2"
}%
GNURF
    $this->assert_equals(
        "HEADERMain WebHome, Sandbox WebHomeFOOTER\n",
        $result );
}

# The results of SEARCH are highly sensitive to the template;
# reduce sensitivity by trimming the result
sub _cut_the_crap {
    my $result = shift;
    $result =~ s/<!--.*?-->//gs;
    $result =~ s/<\/?(em|span|div|b|h\d)\b.*?>//gs;
    $result =~ s/ (class|style|id|rel)=(["'])[^"']*\2//g;
    $result =~ s/( href=(["']))[^"']*(\2)/$1$3/g;
    $result =~ s/\d\d:\d\d( \(\w+\))?/TIME/g;
    $result =~ s/\d{2} \w{3} \d{4}/DATE/g;
    return $result;
}

sub test_no_format_no_shit {
    my $this = shift;

    my $result = $this->{test_topicObject}->expandMacros('%SEARCH{"BLEEGLE"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>Results from <nop>TemporarySEARCHTestWebSEARCH web retrieved at TIME

<a href="">OkATopic</a>
<nop>BLEEGLE dontmatchme.blah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkBTopic</a>
<nop>BLEEGLE dont.matchmeblah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkTopic</a>
<nop>BLEEGLE blah/matchme.blah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">TestTopicSEARCH</a>
<nop>BLEEGLE
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" nosummary="on"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>Results from <nop>TemporarySEARCHTestWebSEARCH web retrieved at TIME

<a href="">OkATopic</a>
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkBTopic</a>
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkTopic</a>
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">TestTopicSEARCH</a>
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" nosearch="on"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Results from <nop>TemporarySEARCHTestWebSEARCH web retrieved at TIME

<a href="">OkATopic</a>
<nop>BLEEGLE dontmatchme.blah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkBTopic</a>
<nop>BLEEGLE dont.matchmeblah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkTopic</a>
<nop>BLEEGLE blah/matchme.blah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest


<a href="">TestTopicSEARCH</a>
<nop>BLEEGLE
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" nototal="on"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
Results from <nop>TemporarySEARCHTestWebSEARCH web retrieved at TIME

<a href="">OkATopic</a>
<nop>BLEEGLE dontmatchme.blah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkBTopic</a>
<nop>BLEEGLE dont.matchmeblah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest



<a href="">OkTopic</a>
<nop>BLEEGLE blah/matchme.blah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">TestTopicSEARCH</a>
<nop>BLEEGLE
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" noheader="on"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
<a href="">OkATopic</a>
<nop>BLEEGLE dontmatchme.blah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkBTopic</a>
<nop>BLEEGLE dont.matchmeblah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkTopic</a>
<nop>BLEEGLE blah/matchme.blah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">TestTopicSEARCH</a>
<nop>BLEEGLE
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" noempty="on"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
Results from <nop>TemporarySEARCHTestWebSEARCH web retrieved at TIME




<a href="">OkATopic</a>
<nop>BLEEGLE dontmatchme.blah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkBTopic</a>
<nop>BLEEGLE dont.matchmeblah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkTopic</a>
<nop>BLEEGLE blah/matchme.blah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">TestTopicSEARCH</a>
<nop>BLEEGLE
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

Number of topics: 4
CRUD
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" zeroresults="on"}%');
    $this->assert_html_equals( <<CRUD, _cut_the_crap($result) );
Searched: <noautolink>BLEEGLE</noautolink>
Results from <nop>TemporarySEARCHTestWebSEARCH web retrieved at TIME




<a href="">OkATopic</a>
<nop>BLEEGLE dontmatchme.blah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkBTopic</a>
<nop>BLEEGLE dont.matchmeblah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">OkTopic</a>
<nop>BLEEGLE blah/matchme.blah
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

<a href="">TestTopicSEARCH</a>
<nop>BLEEGLE
NEW - <a href="">DATE - TIME</a> by TemporarySEARCHUsersWeb.WikiGuest

Number of topics: 4
CRUD

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"BLEEGLE" nosummary="on" nosearch="on" nototal="on" zeroresults="off" noheader="on" noempty="on"}%'
      );
    my $result2 =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"BLEEGLE" nosummary="on" nonoise="on"}%');
    $this->assert_html_equals( $result, $result2 );
}

sub verify_search_type_word {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"dont" scope="all" nonoise="on" format="$topic" separator="," type="word"}%'
      );
    $this->assert_str_equals( 'OkBTopic', $result );
    my @list = split( /,/, $result );
    my $dontcount = $#list;
    $this->assert( $dontcount == 0 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"+dont" scope="all" nonoise="on" format="$topic" separator="," type="word"}%'
      );
    @list = split( /,/, $result );
    $this->assert_str_equals( 'OkBTopic', $result );
    my $plus_dontcount = $#list;
    $this->assert( $plus_dontcount == 0 );
    $this->assert( $plus_dontcount == $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"-dont" scope="all" nonoise="on" format="$topic" separator="," type="word"}%'
      );
    $this->assert_str_equals( 'OkATopic,OkTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $minus_dontcount = $#list;
    $this->assert( $minus_dontcount == 3 );

    #$this->assert( $minus_dontcount == ($alltopics - $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!dont" scope="all" nonoise="on" format="$topic" separator="," type="word"}%'
      );
    $this->assert_str_equals( 'OkATopic,OkTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $bang_dontcount = $#list;
    $this->assert( $bang_dontcount == 3 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="word"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $quote_dontcount = $#list;
    $this->assert( $quote_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="word"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkBTopic,OkTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $not_quote_dontcount = $#list;
    $this->assert( $not_quote_dontcount == 4 );
}

sub verify_search_type_keyword {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"dont" scope="all" nonoise="on" format="$topic" separator="," type="keyword"}%'
      );
    $this->assert_str_equals( 'OkATopic,OkBTopic', $result );
    my @list = split( /,/, $result );
    my $dontcount = $#list;
    $this->assert( $dontcount == 1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"+dont" scope="all" nonoise="on" format="$topic" separator="," type="keyword"}%'
      );
    @list = split( /,/, $result );
    $this->assert_str_equals( 'OkATopic,OkBTopic', $result );
    my $plus_dontcount = $#list;
    $this->assert( $plus_dontcount == 1 );
    $this->assert( $plus_dontcount == $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"-dont" scope="all" nonoise="on" format="$topic" separator="," type="keyword"}%'
      );
    $this->assert_str_equals( 'OkTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $minus_dontcount = $#list;
    $this->assert( $minus_dontcount == 2 );

    #$this->assert( $minus_dontcount == ($alltopics - $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!dont" scope="all" nonoise="on" format="$topic" separator="," type="keyword"}%'
      );
    $this->assert_str_equals( 'OkTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $bang_dontcount = $#list;
    $this->assert( $bang_dontcount == 2 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="keyword"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $quote_dontcount = $#list;
    $this->assert( $quote_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="keyword"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkBTopic,OkTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $not_quote_dontcount = $#list;
    $this->assert( $not_quote_dontcount == 4 );
}

sub verify_search_type_literal {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"dont" scope="all" nonoise="on" format="$topic" separator="," type="literal"}%'
      );
    $this->assert_str_equals( 'OkATopic,OkBTopic', $result );
    my @list = split( /,/, $result );
    my $dontcount = $#list;
    $this->assert( $dontcount == 1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"+dont" scope="all" nonoise="on" format="$topic" separator="," type="literal"}%'
      );
    @list = split( /,/, $result );
    $this->assert_str_equals( '', $result );
    my $plus_dontcount = $#list;
    $this->assert( $plus_dontcount == -1 );
    $this->assert( $plus_dontcount != $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"-dont" scope="all" nonoise="on" format="$topic" separator="," type="literal"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $minus_dontcount = $#list;
    $this->assert( $minus_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!dont" scope="all" nonoise="on" format="$topic" separator="," type="literal"}%'
      );
    $this->assert_str_equals( 'OkTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $bang_dontcount = $#list;
    $this->assert( $bang_dontcount == 2 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="literal"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $quote_dontcount = $#list;
    $this->assert( $quote_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="literal"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkBTopic,OkTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $not_quote_dontcount = $#list;
    $this->assert( $not_quote_dontcount == 4 );
}

sub verify_search_type_regex {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"dont" scope="all" nonoise="on" format="$topic" separator="," type="regex"}%'
      );
    $this->assert_str_equals( 'OkATopic,OkBTopic', $result );
    my @list = split( /,/, $result );
    my $dontcount = $#list;
    $this->assert( $dontcount == 1 );

#this causes regex search to throw an error due to the '+'
#    $result =
#      $this->{test_topicObject}->expandMacros(
#        '%SEARCH{"+dont" scope="all" nonoise="on" format="$topic" separator="," type="regex"}%');
#    @list = split(/,/, $result);
#    $this->assert_str_equals( '', $result );
#    my $plus_dontcount = $#list;
#    $this->assert( $plus_dontcount == -1 );
#    $this->assert( $plus_dontcount != $dontcount );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"-dont" scope="all" nonoise="on" format="$topic" separator="," type="regex"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $minus_dontcount = $#list;
    $this->assert( $minus_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!dont" scope="all" nonoise="on" format="$topic" separator="," type="regex"}%'
      );
    $this->assert_str_equals( 'OkTopic,TestTopicSEARCH,WebPreferences',
        $result );
    @list = split( /,/, $result );
    my $bang_dontcount = $#list;
    $this->assert( $bang_dontcount == 2 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="regex"}%'
      );
    $this->assert_str_equals( '', $result );
    @list = split( /,/, $result );
    my $quote_dontcount = $#list;
    $this->assert( $quote_dontcount == -1 );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"!\"-dont\"" scope="all" nonoise="on" format="$topic" separator="," type="regex"}%'
      );
    $this->assert_str_equals(
        'OkATopic,OkBTopic,OkTopic,TestTopicSEARCH,WebPreferences', $result );
    @list = split( /,/, $result );
    my $not_quote_dontcount = $#list;
    $this->assert( $not_quote_dontcount == 4 );
}

sub verify_stop_words_search_word {
    my $this = shift;

    use Foswiki::Func;
    my $origSetting = Foswiki::Func::getPreferencesValue('SEARCHSTOPWORDS');
    Foswiki::Func::setPreferencesValue( 'SEARCHSTOPWORDS',
        'xxx luv ,kiss, bye' );

    my $TEST_TEXT  = "xxx Shamira";
    my $TEST_TOPIC = 'StopWordTestTopic';
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $TEST_TOPIC,
        $TEST_TEXT );
    $topicObject->save();

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Shamira" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_matches( qr/$TEST_TOPIC/, $result );

    $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"xxx" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( '', $result );

    $result =
      $this->{test_topicObject}->expandMacros(
        '%SEARCH{"+xxx" type="word" scope="text" nonoise="on" format="$topic"}%'
      );
    $this->assert_str_equals( '', $result );

    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"+xxx" type="word" topic="$TEST_TOPIC" scope="text" nonoise="on" format="$summary(searchcontext)"}%'
      );

    $this->assert_str_equals( '', $result );

    Foswiki::Func::setPreferencesValue( 'SEARCHSTOPWORDS', $origSetting );
}

sub createSummaryTestTopic {
    my ( $this, $topicName ) = @_;

    my $TEST_SUMMARY_TEXT =
"Alan says: 'I was on a landing; there were banisters'. He pauses before describing the exact shape and details of the banisters. 'There was a thin man there. I was toppling him over the banisters. He said to me: 'When you have lost the 4 stone and the 14 stone, then you might topple over.' That's all I can remember.' Alan is thoughtful a while then talks about the 'toppling over'. He thinks that the sense was that the man might get unbalanced and topple over. He considers whether he might be pushing him over in the dream. He thought there was a way in which the man was suggesting that when Alan had lost the 4 stone and the 14 stone then he might topple over too; might lose his balance.

	As Alan thought about different parts of his dream he let his mind follow the thoughts, images and memories which came to him. He thought about his weight loss programme. He couldn't think why he was dreaming about 4 and 14 stone, but it didn't bother him that he couldn't understand that part, something would probably come up later. Perhaps it's because his next goal is 18 stone, he muses. He remembers being thin as a young man at school. In particular in athletics, competing against an arch-rival in running. He remembers something else which happened at that time too. He smiles with surprise, saying that he hasn't thought of it for 30 years until this moment. But now he notices that thinking about this memory makes him feel anxious.

	Just as he's saying this, his analyst notices that as she begins to think of what she might say about the dream she finds herself feeling she'll have to be very careful not to say it insensitively and provoke a fight. Subtly and imperceptibly the atmosphere has become tense. He remembers fighting this rival; really fighting as if to the death. He thinks that he might have completely lost control and killed him if this strange thing hadn't happened at that point. He'd just gone like jelly; he got up and walked away.

	After dwelling a little more on the fears he'd suffered as a young thin man about losing control and being violent, he remembers his father's sudden death from a heart attack when he was a boy. What his analyst knows is that this death, so traumatic for Alan, had precipitated his disturbance as a child. He had developed obsessional routines involving checking and re-checking that he had turned off the taps and secured the locks on the windows at night, as if he believed that in some way he was culpable for the death of his father.

	Alan interrupts himself to say: 'I went to the doctor yesterday, by the way, to discuss coming off all the pills.' He reminds his analyst that he is currently taking four different pills. He reminds her what each is for: an antipsychotic, an antidepressant, a beta blocker and a blood pressure pill. They speak a bit about the visit to the GP and Alan stresses both his desire to give up all his medication now that he is improving with the help of his analysis and his need to do it very carefully. He knows someone who came off antidepressants suddenly, all at once, and nearly died because the doctors hadn't bothered to warn him that it was dangerous. He checked this out with the GP and is stopping at the rate of half a pill per fortnight. His analyst says: 'Perhaps this helps us understand the 4 and the 14 in the dream. While you very much want to be healthy and be doing well in your analysis, and to manage without taking the 4 pills by giving up more every 14 days, you are also afraid that without the pills and the fat jelly you've covered yourself with, you might get unbalanced and be compelled to fight and be violent. Perhaps you fear your violence towards me, your thin analyst, too. The banisters made me think of those outside the consulting room which you see as you come in.'

	Alan says: 'Oh yes; I knew I'd seen them somewhere before! But how do I know I won't go mad and do something to you? I just thought of something, just then.' Alan is now very agitated. 'It makes my blood boil the way analysts never defend themselves when they are attacked in the press. You hear one slander after another about Freud and psychoanalysis, and what do your lot do? Nothing!'";

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topicName,
        $TEST_SUMMARY_TEXT );
    $topicObject->save();
}

=pod

Test the summary, default format.

=cut

sub test_summary_default_word_search {
    my $this = shift;

    $this->createSummaryTestTopic('TestSummaryTopic');

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Alan" type="word" topic="TestSummaryTopic" scope="text" nonoise="on" format="$summary"}%'
      );

    $this->assert_html_equals( <<CRUD, $result );
Alan says<nop>: 'I was on a landing; there were banisters'. He pauses before describing the exact shape and details of the banisters. 'There was a thin man there. I was ...
CRUD
}

=pod

Test the default summary, limited to n chars.

=cut

sub test_summary_short_word_search {
    my $this = shift;

    $this->createSummaryTestTopic('TestSummaryTopic');

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"Alan" type="word" topic="TestSummaryTopic" scope="text" nonoise="on" format="$summary(12)"}%'
      );

    $this->assert_html_equals( <<CRUD, $result );
Alan says<nop>: 'I was ...
CRUD
}

=pod

Test the summary with search context (default length).

=cut

sub test_summary_searchcontext_default_word_search {
    my $this = shift;

    $this->createSummaryTestTopic('TestSummaryTopic');

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"do" type="word" topic="TestSummaryTopic" scope="text" nonoise="on" format="$summary(searchcontext)"}%'
      );

    $this->assert_html_equals( <<CRUD, $result );
<b>&hellip;</b>  his analysis and his need to <em>do</em> it very carefully. He knows  <b>&hellip;</b>  somewhere before! But how <em>do</em> I know I won't go mad and do  <b>&hellip;</b>  and psychoanalysis, and what <em>do</em> your lot do? Nothing <b>&hellip;</b>
CRUD
}

=pod

Test the summary with search context, limited to n chars (short).

=cut

sub test_summary_searchcontext_short_word_search {
    my $this = shift;

    $this->createSummaryTestTopic('TestSummaryTopic');

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"his" type="word" topic="TestSummaryTopic" scope="text" nonoise="on" format="$summary(searchcontext,40)"}%'
      );

    $this->assert_html_equals( <<CRUD, $result );
<b>&hellip;</b>  topple over too; might lose <em>his</em> balance. As Alan thought  <b>&hellip;</b> 
CRUD
}

=pod

Test the summary with search context, limited to n chars (long)

=cut

sub test_summary_searchcontext_long_word_search {
    my $this = shift;

    $this->createSummaryTestTopic('TestSummaryTopic');

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"his" type="word" topic="TestSummaryTopic" scope="text" nonoise="on" format="$summary(searchcontext,200)"}%'
      );

    $this->assert_html_equals( <<CRUD, $result );
<b>&hellip;</b>  topple over too; might lose <em>his</em> balance. As Alan thought  <b>&hellip;</b> about different parts of <em>his</em> dream he let his mind follow  <b>&hellip;</b> came to him. He thought about <em>his</em> weight loss programme. He  <b>&hellip;</b>  later. Perhaps it's because <em>his</em> next goal is 18 stone, he  <b>&hellip;</b> 
CRUD
}

sub verify_zeroresults {
    my $this = shift;
    my $result;
    
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE"}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" zeroresults="on"}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT
  
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" zeroresults="off"}%');
    $this->assert_equals( '', $result );
  
      $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" zeroresults="I did not find anything."}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
I did not find anything.
RESULT


#nototal=on
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="on"}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="on" zeroresults="on"}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="on" zeroresults="off"}%');
	$this->assert_equals( '', $result );

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="on" zeroresults="I did not find anything."}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
I did not find anything.
RESULT

#nototal=off
    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="off"}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="off" zeroresults="on"}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
Searched: <noautolink>NOBLEEGLE</noautolink>
Number of topics: 0
RESULT

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="off" zeroresults="off"}%');
    $this->assert_equals( '', $result );

    $result =
      $this->{test_topicObject}
      ->expandMacros('%SEARCH{"NOBLEEGLE" nototal="off" zeroresults="I did not find anything."}%');
    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
I did not find anything.
RESULT
}

# Item8800: SEARCH date param
sub verify_date_param {
    my $this = shift;
    
    my $text = <<HERE;
%META:TOPICINFO{author="TopicUserMapping_guest" date="1" format="1.1" version="1.2"}%
---+ Progressive Sexuality
A Symbol Interpreted In American Architecture. Meta-Physics Of Marxism & Poverty In The American Landscape. Exploration Of Crime In Mexican Sculptures: A Study Seen In American Literature. Brief Survey Of Suicide In Italian Art: The Big Picture. Special Studies In Bisexual Female Architecture. Brief Survey Of Suicide In Polytheistic Literature: Analysis, Analysis, and Critical Thinking. Radical Paganism: Modern Theories. Liberal Mexican Religion In The Modern Age. 

HERE
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        "VeryOldTopic", $text );
    my $rev = $topicObject->save(forcedate=>123);
    $this->assert_num_equals(1, $rev);
    my $file_date = $this->{session}->{store}->getApproxRevTime( $this->{test_web}, "VeryOldTopic" );
    #TODO: sadly, the core Handlers don't set the filedate, even though they could
    #$this->assert_num_equals(123, $file_date);
    
    my $result =
      $this->{test_topicObject}
#SMELL:
#TODO: the query type should be abstracted to test each&all backends
      ->expandMacros('%SEARCH{"1" type="query" date="1970" nonoise="on" format="$topic"}%');

    $this->assert_html_equals( <<RESULT, _cut_the_crap($result) );
VeryOldTopic
RESULT
}

sub verify_nl_in_result {
    my $this = shift;
    my $text = <<HERE;
%META:TOPICINFO{author="TopicUserMapping_guest" date="1" format="1.1" version="1.2"}%
Radical Meta-Physics
Marxism
Crime
Suicide
Paganism.
%META:FIELD{name="Name" attributes="" title="Name" value="Meta-Physics%0aMarxism%0aCrime%0aSuicide%0aPaganism."}%
HERE
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        "OffColour", $text );
    $topicObject->save();

    my $result;

    # Default $formfield, \n expands to <br /> because people most often display
    # multiline form fields in TML tables and \n would disturb the tables
    $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{"OffColour" scope="topic" nonoise="on" format="$formfield(Name)"}%');
    $this->assert_str_equals( <<RESULT, "$result\n" );
Meta-Physics<br />Marxism<br />Crime<br />Suicide<br />Paganism.
RESULT

    # Default $pattern, \n expands to \n (more sensible)
    $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{"OffColour" scope="topic" nonoise="on" format="$pattern(.*?(Meta.*?Paganism).*)"}%');
    $this->assert_str_equals( <<RESULT, "$result\n" );
Meta-Physics
Marxism
Crime
Suicide
Paganism
RESULT

    # $pattern newline="X", \n expands to X
    $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{"OffColour" scope="topic" nonoise="on" format="$pattern(.*?(Meta.*?Paganism).*)" newline="X"}%');
    $this->assert_str_equals( <<RESULT, "$result\n" );
Meta-PhysicsXMarxismXCrimeXSuicideXPaganism
RESULT

    # $formfield, newline="X", \n expands to X
    # SMELL: C. believes this is correct behaviour, but it doesn't work
    # because formfields are rendered by the Form package way before they
    # get here :-(
#    $result = $this->{test_topicObject}->expandMacros(
#        '%SEARCH{"OffColour" scope="topic" nonoise="on" format="$formfield(Name)" newline="X"}%');
#    $this->assert_str_equals( <<RESULT, "$result\n" );
#Meta-PhysicsXMarxismXCrimeXSuicideXPaganism.
#RESULT
}

###########################################
#pager formatting
sub test_pager_on {
    my $this = shift;
    
    my $viewTopicUrl = Foswiki::Func::getScriptUrl($this->{test_topicObject}->web, $this->{test_topicObject}->topic, 'view');

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="1"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
    pager="on"
}%'
    );

    my $expected = <<EXPECT;
Main.WebChanges
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(4,4)Sandbox.WebChanges
FOOT(1,1)
---
   Page 1 of 3   [[$viewTopicUrl?SEARCHc6139cf1d63c9614230f742fca2c6a36=2][Next >]]
---
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="2"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
    pager="on"
}%'
    );

    $expected = <<EXPECT;
Sandbox.WebHome
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(3,3)System.WebChanges
System.WebHome
FOOT(2,2)
---
[[$viewTopicUrl?SEARCH6331ae02a320baf1478c8302e38b7577=1][< Previous]]   Page 2 of 3   [[$viewTopicUrl?SEARCH6331ae02a320baf1478c8302e38b7577=3][Next >]]
---
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub test_pager_on_pagerformat {
    my $this = shift;
    
    my $viewTopicUrl = Foswiki::Func::getScriptUrl($this->{test_topicObject}->web, $this->{test_topicObject}->topic, 'view');

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="1"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
    pager="on"
    pagerformat="$n..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize, prevurl=$previousurl, nexturl=$nexturl..$n"
}%
'
    );

    my $expected = <<EXPECT;
Main.WebChanges
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(4,4)Sandbox.WebChanges
FOOT(1,1)
..prev=0, 1, next=2, numberofpages=3, pagesize=5, prevurl=, nexturl=$viewTopicUrl?SEARCHe9863b5d7ec27abeb8421578b0747c25=2..
EXPECT
    $this->assert_str_equals( $expected, $result );

    $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="2"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
    pager="on"
    pagerformat="$n..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize, prevurl=$previousurl, nexturl=$nexturl..$n"
}%
'
    );

    $expected = <<EXPECT;
Sandbox.WebHome
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(3,3)System.WebChanges
System.WebHome
FOOT(2,2)
..prev=1, 2, next=3, numberofpages=3, pagesize=5, prevurl=$viewTopicUrl?SEARCHc5ceccfcec96473a9efe986cf3597eb1=1, nexturl=$viewTopicUrl?SEARCHc5ceccfcec96473a9efe986cf3597eb1=3..
EXPECT
    $this->assert_str_equals( $expected, $result );
}

sub test_pager_off_pagerformat {
    my $this = shift;
    
    my $viewTopicUrl = Foswiki::Func::getScriptUrl($this->{test_topicObject}->web, $this->{test_topicObject}->topic, 'view');

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="1"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
    pager="off"
    pagerformat="$n..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize, prevurl=$previousurl, nexturl=$nexturl..$n"
}%'
    );

    my $expected = <<EXPECT;
Main.WebChanges
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(4,4)Sandbox.WebChanges
FOOT(1,1)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="2"
    pagesize="5"
    footer="FOOT($ntopics,$nhits)"
    OFFpager="on"
    pagerformat="$n..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize, prevurl=$previousurl, nexturl=$nexturl..$n"
}%'
    );

    $expected = <<EXPECT;
Sandbox.WebHome
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(3,3)System.WebChanges
System.WebHome
FOOT(2,2)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub test_pager_off_pagerformat_pagerinheaderfooter {
    my $this = shift;
    
    my $viewTopicUrl = Foswiki::Func::getScriptUrl($this->{test_topicObject}->web, $this->{test_topicObject}->topic, 'view');

    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="1"
    pagesize="5"
    header="HEADER($pager)"
    footer="FOOT($ntopics,$nhits)($pager)"
    pager="off"
    pagerformat="..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize.."
}%'
    );

    my $expected = <<EXPECT;
HEADER(..prev=0, 1, next=2, numberofpages=3, pagesize=5..)
Main.WebChanges
Main.WebHome
Main.WebIndex
Main.WebPreferences
FOOT(4,4)(..prev=0, 1, next=2, numberofpages=3, pagesize=5..)HEADER(..prev=0, 1, next=2, numberofpages=3, pagesize=5..)
Sandbox.WebChanges
FOOT(1,1)(..prev=0, 1, next=2, numberofpages=3, pagesize=5..)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

    $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic"
    showpage="2"
    pagesize="5"
    header="HEADER($pager)"
    footer="FOOT($ntopics,$nhits)($pager)"
    OFFpager="on"
    pagerformat="..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize.."
}%'
    );

    $expected = <<EXPECT;
HEADER(..prev=1, 2, next=3, numberofpages=3, pagesize=5..)
Sandbox.WebHome
Sandbox.WebIndex
Sandbox.WebPreferences
FOOT(3,3)(..prev=1, 2, next=3, numberofpages=3, pagesize=5..)HEADER(..prev=1, 2, next=3, numberofpages=3, pagesize=5..)
System.WebChanges
System.WebHome
FOOT(2,2)(..prev=1, 2, next=3, numberofpages=3, pagesize=5..)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );
}

sub test_pager_off_pagerformat_pagerinall {
    my $this = shift;
    
    my $result = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "web" 
    type="text"
    web="System,Main,Sandbox"
    topic="WebHome,WebChanges,WebIndex,WebPreferences"
    scope="text" 
    nonoise="on" 
    format="$web.$topic ($pager)ntopics=$ntopics"
    showpage="2"
    pagesize="5"
    header="HEADER($pager)ntopics=$ntopics"
    footer="FOOT($ntopics,$nhits)($pager)"
    OFFpager="on"
    pagerformat="ntopics=$ntopics..prev=$previouspage, $currentpage, next=$nextpage, numberofpages=$numberofpages, pagesize=$pagesize.."
}%'
    );

    my $expected = <<EXPECT;
HEADER(ntopics=0..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=0
Sandbox.WebHome (ntopics=1..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=1
Sandbox.WebIndex (ntopics=2..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=2
Sandbox.WebPreferences (ntopics=3..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=3
FOOT(3,3)(ntopics=3..prev=1, 2, next=3, numberofpages=3, pagesize=5..)HEADER(ntopics=0..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=0
System.WebChanges (ntopics=1..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=1
System.WebHome (ntopics=2..prev=1, 2, next=3, numberofpages=3, pagesize=5..)ntopics=2
FOOT(2,2)(ntopics=2..prev=1, 2, next=3, numberofpages=3, pagesize=5..)
EXPECT
    $expected =~ s/\n$//s;
    $this->assert_str_equals( $expected, $result );

}

sub test_simple_format {
    my $this = shift;

    my $actual = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "(WebPreferences|WebStatistics|WebHome)$"
    type="regex"
    scope="topic"
    web="TestCases, %SYSTEMWEB%, Main, Sandbox"
    format="   * !$web.$topic"
    nosearch="on"
}%
');
    my $expected = <<'HERE';
   * !Main.WebHome
   * !Main.WebPreferences
   * !Main.WebStatistics
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
   * !Sandbox.WebHome
   * !Sandbox.WebPreferences
   * !Sandbox.WebStatistics
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
   * !System.WebHome
   * !System.WebPreferences
   * !System.WebStatistics
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
   * !TestCases.WebHome
   * !TestCases.WebPreferences
   * !TestCases.WebStatistics
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
HERE
    
    $this->assert_str_equals( $expected, $actual );
}

sub test_formatdotBang {
    my $this = shift;

    my $actual = $this->{test_topicObject}->expandMacros(
        '%SEARCH{
    "(WebPreferences|WebStatistics|WebHome)$"
    type="regex"
    scope="topic"
    web="%SYSTEMWEB%"
    format="   * !$web.!$topic"
    nosearch="on"
}%
');
    my $expected = <<'HERE';
   * !System.!WebHome
   * !System.!WebPreferences
   * !System.!WebStatistics
<div class="foswikiSearchResultCount">Number of topics: <span>3</span></div>
HERE

    $this->assert_str_equals( $expected, $actual );
}


sub test_delayed_expansion {
    my $this = shift;
eval "require Foswiki::Macros::SEARCH";
    
    my $result = $Foswiki::Plugins::SESSION->SEARCH({
                                    _DEFAULT=>"1",
                                    type=>"query",
                                    nonoise=>"on",
                                    web=>"Main, System",
                                    topic=>"WebHome,WebIndex, WebPreferences",
                                    format=>'$topic',
                                    separator=>", ",
                                }, $this->{test_topicObject});
    $this->assert_str_equals( <<EXPECT, $result."\n" );
WebHome, WebIndex, WebPreferences, WebHome, WebIndex, WebPreferences
EXPECT

    $result = $Foswiki::Plugins::SESSION->SEARCH({
                                    _DEFAULT=>"1",
                                    type=>"query",
                                    nonoise=>"on",
                                    web=>"Main, System",
                                    topic=>"WebHome,WebIndex, WebPreferences",
                                    format=>'$percentWIKINAME$percent',
                                    separator=>", ",
                                }, $this->{test_topicObject});
    $this->assert_str_equals( <<EXPECT, $result."\n" );
%WIKINAME%, %WIKINAME%, %WIKINAME%, %WIKINAME%, %WIKINAME%, %WIKINAME%
EXPECT

#Item8849: the header (and similarly footer) are expended once too often, FOREACh and SEARCH should return the raw TML, which is _then_ expanded
    $result = $Foswiki::Plugins::SESSION->SEARCH({
                                    _DEFAULT=>"1",
                                    type=>"query",
                                    nonoise=>"on",
                                    web=>"Main, System",
                                    topic=>"WebHome,WebIndex, WebPreferences",
                                    header=>'$percentINCLUDE{Main.WebHeader}$percent',
                                    footer=>'$percentINCLUDE{Main.WebFooter}$percent',
                                    format=>'$topic',
                                    separator=>", ",
                                }, $this->{test_topicObject});
    $this->assert_str_equals( <<EXPECT, $result."\n" );
%INCLUDE{Main.WebHeader}%WebHome, WebIndex, WebPreferences%INCLUDE{Main.WebFooter}%%INCLUDE{Main.WebHeader}%WebHome, WebIndex, WebPreferences%INCLUDE{Main.WebFooter}%
EXPECT

}

####################################
#order tests.
sub set_up_for_sorting {
    my $this = shift;
    my $text = <<'HERE';
%META:TOPICINFO{author="TopicUserMapping_simon" date="1178612772" format="1.1" version="1.1"}%
%META:TOPICPARENT{name="WebHome"}%
something before. Another
This is QueryTopic FURTLE
somethig after

%META:FORM{name="TestyForm"}%
%META:FIELD{name="FieldA" attributes="H" title="B Field" value="1234"}%
%META:FIELD{name="FieldB" attributes="" title="Banother Field" value="098"}%
%META:FIELD{name="FieldC" attributes="" title="Banother Field" value="11"}%
%META:FIELD{name="Firstname" attributes="" title="Pre Name" value="Pedro"}%
%META:FIELD{name="Lastname" attributes="" title="Post Name" value="Peal"}%
%META:FIELD{name="form" attributes="" title="Blah" value="form good"}%
%META:FIELD{name="FORM" attributes="" title="Blah" value="FORM GOOD"}%
%META:FILEATTACHMENT{name="porn.gif" comment="Cor" date="15062" size="15504"}%
%META:FILEATTACHMENT{name="flib.xml" comment="Cor" date="1157965062" size="1"}%
HERE
#    $this->{twiki}->{store}->saveTopic( 'simon',
#        $this->{test_web}, 'QueryTopic', $text, undef, {forcedate=>1178612772} );
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'QueryTopic',
        $text );
    $topicObject->save(forcedate=>1178612772, author=>'simon');

    $text = <<'HERE';
%META:TOPICINFO{author="BaseUserMapping_666" date="12" format="1.1" version="1.2"}%
first line
This is QueryTopicTwo SMONG
third line
%META:TOPICPARENT{name="QueryTopic"}%
%META:FORM{name="TestyForm"}%
%META:FIELD{name="FieldA" attributes="H" title="B Field" value="7"}%
%META:FIELD{name="FieldB" attributes="" title="Banother Field" value="8"}%
%META:FIELD{name="FieldC" attributes="" title="Banother Field" value="2"}%
%META:FIELD{name="Firstname" attributes="" title="Pre Name" value="John"}%
%META:FIELD{name="Lastname" attributes="" title="Post Name" value="Peel"}%
%META:FIELD{name="form" attributes="" title="Blah" value="form good"}%
%META:FIELD{name="FORM" attributes="" title="Blah" value="FORM GOOD"}%
%META:FILEATTACHMENT{name="porn.gif" comment="Cor" date="15062" size="15504"}%
%META:FILEATTACHMENT{name="flib.xml" comment="Cor" date="1157965062" size="1"}%
HERE
    #$this->{twiki}->{store}->saveTopic( 'admin',
    #    $this->{test_web}, 'QueryTopicTwo', $text, undef, {forcedate=>12} );
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'QueryTopicTwo',
        $text );
    $topicObject->save(forcedate=>12, author=>'admin');


    $text = <<'HERE';
%META:TOPICINFO{author="TopicUserMapping_Gerald" date="14" format="1.1" version="1.2"}%
first line
This is QueryTopicThree SMONG
third line
%META:TOPICPARENT{name="QueryTopic"}%
%META:FORM{name="TestyForm"}%
%META:FIELD{name="FieldA" attributes="H" title="B Field" value="2"}%
%META:FIELD{name="FieldB" attributes="" title="Banother Field" value="-0.12"}%
%META:FIELD{name="FieldC" attributes="" title="Banother Field" value="10"}%
%META:FIELD{name="Firstname" attributes="" title="Pre Name" value="Jason"}%
%META:FIELD{name="Lastname" attributes="" title="Post Name" value="Peel"}%
%META:FIELD{name="form" attributes="" title="Blah" value="form good"}%
%META:FIELD{name="FORM" attributes="" title="Blah" value="FORM GOOD"}%
%META:FILEATTACHMENT{name="porn.gif" comment="Cor" date="15062" size="15504"}%
%META:FILEATTACHMENT{name="flib.xml" comment="Cor" date="1157965062" size="1"}%
HERE
    #$this->{twiki}->{store}->saveTopic( 'Gerald',
    #    $this->{test_web}, 'QueryTopicThree', $text, undef, {forcedate=>14} );
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'QueryTopicThree',
        $text );
    $topicObject->save(forcedate=>14, author=>'Gerald');

    $this->{session}->finish();
    my $query = new Unit::Request("");
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->{session} = new Foswiki( undef, $query );
    $this->assert_str_equals( $this->{test_web}, $this->{session}->{webName} );
    $Foswiki::Plugins::SESSION = $this->{session};

    $this->{test_topicObject} =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
}

sub test_orderTopic {
    my $this = shift;

    $this->set_up_for_sorting();
    my $search = '%SEARCH{".*" type="regex" scope="topic" web="'.$this->{test_web}.'" format="$topic" separator="," nonoise="on" ';
    my $result;
    
    #DEFAULT sort=topic..
    $result =
      $this->{test_topicObject}->expandMacros( $search.'}%');
    $this->assert_str_equals( "OkATopic,OkBTopic,OkTopic,QueryTopic,QueryTopicThree,QueryTopicTwo,TestTopicSEARCH,WebPreferences", $result );

    #order=topic
    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="topic"}%');
    $this->assert_str_equals( "OkATopic,OkBTopic,OkTopic,QueryTopic,QueryTopicThree,QueryTopicTwo,TestTopicSEARCH,WebPreferences", $result );

    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="topic" reverse="on"}%');
    $this->assert_str_equals( "WebPreferences,TestTopicSEARCH,QueryTopicTwo,QueryTopicThree,QueryTopic,OkTopic,OkBTopic,OkATopic", $result );

    #order=created
    #TODO: looks like forcedate is broken? so the date tests are unlikely to have enough difference to order.
    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="created" format="$topic ($createdate)"}%');
    #$this->assert_str_equals( "OkATopic,OkBTopic,OkTopic,QueryTopic,QueryTopicThree,QueryTopicTwo,TestTopicSEARCH,WebPreferences", $result );

    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="created" reverse="on"}%');
    #$this->assert_str_equals( "WebPreferences,TestTopicSEARCH,QueryTopicTwo,QueryTopicThree,QueryTopic,OkTopic,OkBTopic,OkATopic", $result );

    #order=modified
    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="modified"}%');
    #$this->assert_str_equals( "OkATopic,OkBTopic,OkTopic,QueryTopic,QueryTopicThree,QueryTopicTwo,TestTopicSEARCH,WebPreferences", $result );

    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="modified" reverse="on"}%');
    #$this->assert_str_equals( "WebPreferences,TestTopicSEARCH,QueryTopicTwo,QueryTopicThree,QueryTopic,OkTopic,OkBTopic,OkATopic", $result );

    #order=editby
    #TODO: imo this is a bug - alpha sorting should be caseinsensitive
    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="editby" format="$topic ($wikiname)"}%');
#    $this->assert_str_equals( "QueryTopicThree (Gerald),OkATopic (WikiGuest),OkBTopic (WikiGuest),OkTopic (WikiGuest),TestTopicSEARCH (WikiGuest),WebPreferences (WikiGuest),QueryTopicTwo (admin),QueryTopic (simon)", $result );
      $this->assert_str_equals( "QueryTopicThree (Gerald),OkTopic (WikiGuest),OkBTopic (WikiGuest),WebPreferences (WikiGuest),TestTopicSEARCH (WikiGuest),OkATopic (WikiGuest),QueryTopicTwo (admin),QueryTopic (simon)", $result );
#TODO: why is this different from 1.0.x?

    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="editby" reverse="on" format="$topic ($wikiname)"}%');
#    $this->assert_str_equals( "QueryTopic (simon),QueryTopicTwo (admin),OkATopic (WikiGuest),OkBTopic (WikiGuest),OkTopic (WikiGuest),TestTopicSEARCH (WikiGuest),WebPreferences (WikiGuest),QueryTopicThree (Gerald)", $result );
      $this->assert_str_equals( "QueryTopic (simon),QueryTopicTwo (admin),OkTopic (WikiGuest),OkBTopic (WikiGuest),WebPreferences (WikiGuest),TestTopicSEARCH (WikiGuest),OkATopic (WikiGuest),QueryTopicThree (Gerald)", $result );
#TODO: why is this different from 1.0.x?

    #order=formfield(FieldA)
    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="formfield(FieldA)" format="$topic ($formfield(FieldA))"}%');
    #$this->assert_str_equals( "OkATopic (),OkBTopic (),OkTopic (),TestTopicSEARCH (),WebPreferences (),QueryTopicThree (2),QueryTopicTwo (7),QueryTopic (1234)", $result );
    $this->assert_str_equals( "OkTopic (),OkBTopic (),WebPreferences (),TestTopicSEARCH (),OkATopic (),QueryTopicThree (2),QueryTopicTwo (7),QueryTopic (1234)", $result );

    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="formfield(FieldA)" reverse="on" format="$topic ($formfield(FieldA))"}%');
    #$this->assert_str_equals( "QueryTopic (1234),QueryTopicTwo (7),QueryTopicThree (2),OkATopic (),OkBTopic (),OkTopic (),TestTopicSEARCH (),WebPreferences ()", $result );
    $this->assert_str_equals( "QueryTopic (1234),QueryTopicTwo (7),QueryTopicThree (2),OkTopic (),OkBTopic (),WebPreferences (),TestTopicSEARCH (),OkATopic ()", $result );

    #order=formfield(FieldB)
    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="formfield(FieldB)" format="$topic ($formfield(FieldB))"}%');
    #$this->assert_str_equals( "OkATopic (),OkBTopic (),OkTopic (),TestTopicSEARCH (),WebPreferences (),QueryTopicThree (-0.12),QueryTopicTwo (8),QueryTopic (098)", $result );
    $this->assert_str_equals( "OkTopic (),OkBTopic (),WebPreferences (),TestTopicSEARCH (),OkATopic (),QueryTopicThree (-0.12),QueryTopicTwo (8),QueryTopic (098)", $result );

    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="formfield(FieldB)" reverse="on" format="$topic ($formfield(FieldB))"}%');
    #$this->assert_str_equals( "QueryTopic (098),QueryTopicTwo (8),QueryTopicThree (-0.12),OkATopic (),OkBTopic (),OkTopic (),TestTopicSEARCH (),WebPreferences ()", $result );
    $this->assert_str_equals( "QueryTopic (098),QueryTopicTwo (8),QueryTopicThree (-0.12),OkTopic (),OkBTopic (),WebPreferences (),TestTopicSEARCH (),OkATopic ()", $result );

    #order=formfield(FieldC)
    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="formfield(FieldC)" format="$topic ($formfield(FieldC))"}%');
    #$this->assert_str_equals( "OkATopic (),OkBTopic (),OkTopic (),TestTopicSEARCH (),WebPreferences (),QueryTopicTwo (2),QueryTopicThree (10),QueryTopic (11)", $result );
    $this->assert_str_equals( "OkTopic (),OkBTopic (),WebPreferences (),TestTopicSEARCH (),OkATopic (),QueryTopicTwo (2),QueryTopicThree (10),QueryTopic (11)", $result );

    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="formfield(FieldC)" reverse="on" format="$topic ($formfield(FieldC))"}%');
    #$this->assert_str_equals( "QueryTopic (11),QueryTopicThree (10),QueryTopicTwo (2),OkATopic (),OkBTopic (),OkTopic (),TestTopicSEARCH (),WebPreferences ()", $result );
    $this->assert_str_equals( "QueryTopic (11),QueryTopicThree (10),QueryTopicTwo (2),OkTopic (),OkBTopic (),WebPreferences (),TestTopicSEARCH (),OkATopic ()", $result );


    #order=formfield(Firstname)
    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="formfield(Firstname)" format="$topic ($formfield(Firstname))"}%');
    #$this->assert_str_equals( "OkATopic (),OkBTopic (),OkTopic (),TestTopicSEARCH (),WebPreferences (),QueryTopicThree (Jason),QueryTopicTwo (John),QueryTopic (Pedro)", $result );
    $this->assert_str_equals( "OkTopic (),OkBTopic (),WebPreferences (),TestTopicSEARCH (),OkATopic (),QueryTopicThree (Jason),QueryTopicTwo (John),QueryTopic (Pedro)", $result );

    $result =
      $this->{test_topicObject}->expandMacros( $search.'order="formfield(Firstname)" reverse="on" format="$topic ($formfield(Firstname))"}%');
    #$this->assert_str_equals( "QueryTopic (Pedro),QueryTopicTwo (John),QueryTopicThree (Jason),OkATopic (),OkBTopic (),OkTopic (),TestTopicSEARCH (),WebPreferences ()", $result );
    $this->assert_str_equals( "QueryTopic (Pedro),QueryTopicTwo (John),QueryTopicThree (Jason),OkTopic (),OkBTopic (),WebPreferences (),TestTopicSEARCH (),OkATopic ()", $result );

}

sub test_Item9269 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"does not matc[h]" 
  type="regex" 
  zeroresults="$dollarweb=$web" 
  format="dummy" 
}%'
      );

    $this->assert_str_equals( '$web=TemporarySEARCHTestWebSEARCH', $result );
    
    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{".*" 
  limit="1" 
  type="regex" 
  nonoise="on"
  header="header: $dollarweb=$web%BR%" 
  format="format: $dollarweb=$web%BR%" 
  footer="footer: $dollarweb=$web" 
}%'
      );

    $this->assert_str_equals( 'header: $web=TemporarySEARCHTestWebSEARCH<br />
format: $web=TemporarySEARCHTestWebSEARCH<br />
footer: $web=TemporarySEARCHTestWebSEARCH', $result );
   
    $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{".*"
  type="regex"
  nonoise="on"
  format="   1 $topic"
  pager="on"
  pagesize="10"
  pagerformat="pagerformat: $dollarweb=$web"
}%'
      );

    $this->assert_str_equals( '   1 OkATopic
   1 OkBTopic
   1 OkTopic
   1 TestTopicSEARCH
   1 WebPreferences
pagerformat: $web=TemporarySEARCHTestWebSEARCH', $result );
}

sub test_Item9502 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
'%SEARCH{"1"
  type="query"
  web="%WEB%"
  topic="%TOPIC%"
  nonoise="on"
  format="FOO $changes(x)"
}%'
      );

    $this->assert_matches( qr/^FOO /, $result );
}


1;
