use strict;

# tests for the correct expansion of REVINFO

package Fn_REVINFO;
use base qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Error qw( :try );

sub new {
    $Foswiki::cfg{Register}{AllowLoginName} = 1;
    my $self = shift()->SUPER::new( 'REVINFO', @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $this->{guest_wikiname} = Foswiki::Func::getWikiName();
    $this->{session}->{user} = $this->{test_user_cuid};    # OUCH
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web}, "GropeGroup",
        "   * Set GROUP = ScumBag,WikiGuest\n" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "GlumDrop",
        "Burble\n" );
    $topicObject->save();
}

sub test_basic {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%REVINFO%');
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{guest_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
}

sub test_basic2 {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'GlumDrop' );
    my $ui = $topicObject->expandMacros('%REVINFO%');
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
}

sub test_basic3 {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'GlumDrop' );
    my $ui = $topicObject->expandMacros('%REVINFO{topic="GlumDrop"}%');
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
}

sub test_thisWebVars {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'GlumDrop' );
    my $ui =
      $topicObject->expandMacros('%REVINFO{topic="%BASEWEB%.GlumDrop"}%');
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
}

#the following 2 return with reasonable looking non-0, but with WikiGuest as author - perhaps there's a bigger bug out there.
sub BROKENtest_thisTopicVars {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'GlumDrop' );
    my $ui = $topicObject->expandMacros('%REVINFO{topic="%BASETOPIC%"}%');
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
}

sub BROKENtest_thisWebTopicVars {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'GlumDrop' );
    my $ui =
      $topicObject->expandMacros('%REVINFO{topic="%BASEWEB%.%BASETOPIC%"}%');
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
}

sub test_otherWeb {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{topic="GropeGroup" web="' . $this->{users_web} . '"}%',
    );
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
}

sub test_otherWeb2 {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{topic="' . $this->{users_web} . '.GropeGroup"}%' );
    unless ( $ui =~
/^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/
      )
    {
        $this->assert( 0, $ui );
    }
}

sub test_formatUser {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'GlumDrop' );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{format="$username $wikiname $wikiusername"}%');
    $this->assert_str_equals(
"$this->{test_user_login} $this->{test_user_wikiname} $this->{users_web}\.$this->{test_user_wikiname}",
        $ui
    );
}

sub test_compatibility1 {
    my $this = shift;

    # Create a topic with raw meta to force a wikiname into the author field.
    # The wikiname must be for a user who is in WikiUsers.
    # This test is specific to the "traditional" text database implementation,
    # either RcsWrap or RcsLite.
    if (   $Foswiki::cfg{Store}{Implementation} !~ /Rcs(Lite|Wrap)$/ )
    {
        return;
    }
    $this->assert(
        open(
            F, '>', "$Foswiki::cfg{DataDir}/$this->{test_web}/CrikeyMoses.txt"
        )
    );
    print F <<'HERE';
%META:TOPICINFO{author="ScumBag" date="1120846368" format="1.1" version="$Rev$"}%
HERE
    close(F);
    my $topicObject =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'CrikeyMoses' );
    my $ui =
      $topicObject->expandMacros('%REVINFO{format="$username $wikiname"}%');
    $this->assert_str_equals( "scum ScumBag", $ui );

}

sub test_compatibility2 {
    my $this = shift;

    # Create a topic with raw meta to force a login into the author field.
    # The login must be for a user who is in WikiUsers.
    # This test is specific to the "traditional" text database implementation,
    # either RcsWrap or RcsLite.
    if (   $Foswiki::cfg{Store}{Implementation} !~ /Rcs(Lite|Wrap)$/ )
    {
        return;
    }
    $this->assert(
        open(
            F, '>', "$Foswiki::cfg{DataDir}/$this->{test_web}/CrikeyMoses.txt"
        )
    );
    print F <<'HERE';
%META:TOPICINFO{author="scum" date="1120846368" format="1.1" version="$Rev$"}%
HERE
    close(F);
    my $topicObject =
      Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'CrikeyMoses' );
    my $ui =
      $topicObject->expandMacros('%REVINFO{format="$username $wikiname"}%');
    $this->assert_str_equals( "scum ScumBag", $ui );

}

sub test_5873 {
    my $this = shift;

    # Create a topic with raw meta to force a login into the author field.
    # The login must be for a user who does not exist.
    # This test is specific to the "traditional" text database implementation,
    # either RcsWrap or RcsLite.
    if (   $Foswiki::cfg{Store}{Implementation} !~ /Rcs(Lite|Wrap)$ / )
    {
        return;
    }
    $this->assert(
        open(
            F, '>', "$Foswiki::cfg{DataDir}/$this->{test_web}/GeeWillikins.txt"
        )
    );
    print F <<'HERE';
%META:TOPICINFO{author="eltonjohn" date="1120846368" format="1.1" version="$Rev$"}%
HERE
    close(F);
    $Foswiki::cfg{RenderLoggedInButUnknownUsers} = 0;
    my $topicObject =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        'GeeWillikins' );
    my $ui = $topicObject->expandMacros(
        '%REVINFO{format="$username $wikiname $wikiusername"}%');
    $this->assert_str_equals( "eltonjohn eltonjohn eltonjohn", $ui );
    $Foswiki::cfg{RenderLoggedInButUnknownUsers} = 1;
    $ui = $topicObject->expandMacros(
        '%REVINFO{format="$username $wikiname $wikiusername"}%');
    $this->assert_str_equals( "unknown unknown unknown", $ui );
}

sub test_42 {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, "HappyPill",
        "   * Set ALLOWTOPICVIEW = CarlosCastenada\n" );
    $topicObject->save();
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'GlumDrop' );
    my $ui = $topicObject->expandMacros(
            '%REVINFO{topic="'
          . $this->{test_web}
          . '.HappyPill" format="$username $wikiname $wikiusername"}%',
    );
    $this->assert( $ui =~ /No permission to view/ );
}

#see http://trunk.foswiki.org/Tasks/Item8708
#since pre-history, there were 'i' options on the regex's for formatRevision
#this is undoccoed, and kills SpreadSheetPlugin's attempts to use $DATE and $TIME as _its_ inner language.
#so I've removed it.
sub test_CaseSensitiveFormatString {
    my $this = shift;
     
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'GlumDrop' );
    my $ui = $topicObject->expandMacros(
            '%REVINFO{format="$DATE"}%',
    );
    $this->assert_str_equals( '$DATE', $ui );
}

# SMELL: need to test for other revs specified by the 'rev' parameter

# SMELL: need to test for the format parameter strings:
# $web $topic $rev $time $date $rcs $http $email $iso $sec $min $hou
# $day $wday $dow $week $mo $ye $epoch $tz $comment

1;
