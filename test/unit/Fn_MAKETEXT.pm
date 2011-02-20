use strict;

# tests for the correct expansion of MAKETEXT

package Fn_MAKETEXT;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

my $topicObject;

sub new {
    my $self = shift()->SUPER::new( 'MAKETEXT', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'WebHome' );
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();
    setLocalSite();
}

sub setLocalSite {
	delete $INC{'Foswiki/I18N.pm'}
    $Foswiki::cfg{WebMasterEmail} = 'a.b@c.org';
    $Foswiki::cfg{UserInterfaceInternationalisation} = 1;
}

sub test_MAKETEXT_simple {
    my $this = shift;

    my $result = $topicObject->expandMacros('%MAKETEXT{"edit"}%');
    $this->assert_str_equals( 'edit', $result );
}

sub test_MAKETEXT_doc_example_1 {
    my $this = shift;

    my $result = $topicObject->expandMacros('%MAKETEXT{string="Notes:"}%');
    $this->assert_str_equals( 'Notes:', $result );
}

sub test_MAKETEXT_doc_example_2 {
    my $this = shift;

    my $result = $topicObject->expandMacros(
        '%MAKETEXT{ 
"If you have any questions, please contact [_1]." 
args="%WIKIWEBMASTER%" 
}%'
    );
    $this->assert_str_equals(
        'If you have any questions, please contact a.b@c.org.', $result );
}

sub test_MAKETEXT_doc_example_3 {
    my $this = shift;

    my $result = $topicObject->expandMacros(
'%MAKETEXT{"Did you want to [[[_1]][reset [_2]\'s password]]?" args="%SYSTEMWEB%.ResetPassword,%WIKIUSERNAME%"}%'
    );

    $this->assert_str_equals(
'Did you want to [[System.ResetPassword][reset TemporaryMAKETEXTUsersWeb.WikiGuest\'s password]]?',
        $result
    );
}

sub test_MAKETEXT_single_arg {
    my $this = shift;

    my $result =
      $topicObject->expandMacros('%MAKETEXT{"edit [_1]" args="WebHome"}%');
    $this->assert_str_equals( 'edit WebHome', $result );
}

sub test_MAKETEXT_expand_variables_in_args {
    my $this = shift;

    my $result =
      $topicObject->expandMacros('%MAKETEXT{"edit [_1]" args="%HOMETOPIC%"}%');
    $this->assert_str_equals( 'edit WebHome', $result );
}

sub test_MAKETEXT_multiple_args {
    my $this = shift;

    my $result = $topicObject->expandMacros(
        '%MAKETEXT{"edit [_1] [_2]" args="WebHome, now"}%');
    $this->assert_str_equals( 'edit WebHome now', $result );
}

sub test_MAKETEXT_multiple_args_one_empty {
    my $this = shift;

    my $result =
      $topicObject->expandMacros('%MAKETEXT{"edit [_1][_2]" args="WebHome"}%');
    $this->assert_str_equals( 'edit WebHome', $result );
}

sub test_MAKETEXT_multiple_args_forgot_to_reference_one {
    my $this = shift;

    my $result =
      $topicObject->expandMacros('%MAKETEXT{"edit [_1]" args="WebHome, now"}%');
    $this->assert_str_equals( 'edit WebHome', $result );
}

sub test_MAKETEXT_underscore {
    my $this = shift;

    # name starts with underscore: error
    my $result = $topicObject->expandMacros('%MAKETEXT{"_edit"}%');
    $this->assert_str_equals(
'<span class="foswikiAlert">Error: MAKETEXT argument\'s can\'t start with an underscore ("_").</span>',
        $result
    );
}

sub test_MAKETEXT_access_key {
    my $this = shift;

    my $result = $topicObject->expandMacros('%MAKETEXT{"ed&it"}%');
    $this->assert_str_equals( 'ed<span class=\'foswikiAccessKey\'>i</span>t',
        $result );
}

1;
