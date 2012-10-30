# See bottom of file for license and copyright

package FoswikiFnTestCase;
use strict;
use warnings;

=begin TML

---+ package FoswikiFnTestCase

This base class layers some extra stuff on FoswikiTestCase to
try and make life for Foswiki testers even easier at higher levels.
Normally this will be the base class for tests that require an almost
complete user environment. However it does quite a lot of relatively
slow setup, so should not be used for simpler tests (such as those
targeting single classes).

   1. Do not be afraid to modify Foswiki::cfg. You cannot break other
      tests that way.
   2. Never, ever write to any webs except the {test_web} and
      {users_web}, or any other test webs you create and remove
      (following the pattern shown below)
   3. The password manager is set to HtPasswdUser, and you can create
      users as shown in the creation of {test_user}
   4. A single user has been pre-registered, wikinamed 'ScumBag'

=cut

use FoswikiTestCase();
our @ISA = qw( FoswikiTestCase );

use Foswiki();
use Unit::Request();
use Unit::Response();
use Foswiki::UI::Register();
use Error qw( :try );

our @mails;

sub new {
    my $class = shift;
    my $var   = shift;
    my $this  = $class->SUPER::new(@_);

    $this->{var}        = $var;
    $this->{test_web}   = 'Temporary' . $var . 'TestWeb' . $var;
    $this->{test_topic} = 'TestTopic' . $var;
    $this->{users_web}  = 'Temporary' . $var . 'UsersWeb';

    return $this;
}

=begin TML

---++ ObjectMethod loadExtraConfig()
This method can be overridden (overrides should call up to the base class)
to add extra stuff to Foswiki::cfg.

=cut

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig(@_);

    $Foswiki::cfg{Store}{Implementation}    = "Foswiki::Store::RcsLite";
    $Foswiki::cfg{RCS}{AutoAttachPubFiles}  = 0;
    $Foswiki::cfg{Register}{AllowLoginName} = 1;
    $Foswiki::cfg{Htpasswd}{FileName} = "$Foswiki::cfg{WorkingDir}/htpasswd";
    unless ( -e $Foswiki::cfg{Htpasswd}{FileName} ) {
        my $fh;
        open( $fh, ">", $Foswiki::cfg{Htpasswd}{FileName} ) || die $!;
        close($fh) || die $!;
    }
    $Foswiki::cfg{PasswordManager}       = 'Foswiki::Users::HtPasswdUser';
    $Foswiki::cfg{Htpasswd}{GlobalCache} = 0;
    $Foswiki::cfg{UserMappingManager}    = 'Foswiki::Users::TopicUserMapping';
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::TemplateLogin';
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $Foswiki::cfg{RenderLoggedInButUnknownUsers} = 0;

    $Foswiki::cfg{Register}{NeedVerification} = 0;
    $Foswiki::cfg{MinPasswordLength}          = 0;
    $Foswiki::cfg{UsersWebName}               = $this->{users_web};
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);

    my $query = new Unit::Request("");
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    # Note: some tests are testing Foswiki::UI which also creates a session
    $this->createNewFoswikiSession( undef, $query );
    $this->{response} = new Unit::Response();
    @mails = ();
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    my $webObject = $this->populateNewWeb( $this->{test_web} );
    $webObject->finish();
    $webObject = $this->populateNewWeb( $this->{users_web} );
    $webObject->finish();

    $this->{test_user_forename} = 'Scum';
    $this->{test_user_surname}  = 'Bag';
    $this->{test_user_wikiname} =
      $this->{test_user_forename} . $this->{test_user_surname};
    $this->{test_user_login} = 'scum';
    $this->{test_user_email} = 'scumbag@example.com';
    $this->registerUser(
        $this->{test_user_login},   $this->{test_user_forename},
        $this->{test_user_surname}, $this->{test_user_email}
    );
    $this->{test_user_cuid} =
      $this->{session}->{users}->getCanonicalUserID( $this->{test_user_login} );
    $this->{test_topicObject}->finish() if $this->{test_topicObject};
    ( $this->{test_topicObject} ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->{test_topicObject}->text("BLEEGLE\n");
    $this->{test_topicObject}->save( forcedate => ( time() + 60 ) );
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $this->{test_web} );
    $this->removeWebFixture( $this->{session}, $Foswiki::cfg{UsersWebName} );
    unlink( $Foswiki::cfg{Htpasswd}{FileName} );
    $this->SUPER::tear_down();

}

=begin TML

---++ ObjectMethod removeWeb($web)

Remove a temporary web fixture (data and pub)

=cut

sub removeWeb {
    my ( $this, $web ) = @_;
    $this->removeWebFixture( $this->{session}, $web );
}

=begin TML

---++ StaticMethod sentMail($net, $mess)

Default implementation for the callback used by Net.pm. Sent mails are
pushed onto a global variable @FoswikiFnTestCase::mails.

=cut

sub sentMail {
    my ( $net, $mess ) = @_;
    push( @mails, $mess );
    return undef;
}

=begin TML

---++ ObjectMethod registerUser($loginname, $forename, $surname, $email)

Can be used by subclasses to register test users.

=cut

sub registerUser {
    my ( $this, $loginname, $forename, $surname, $email ) = @_;
    my $q = $this->{session}{request};

    my $params = {
        'TopicName'     => ['UserRegistration'],
        'Twk1Email'     => [$email],
        'Twk1WikiName'  => ["$forename$surname"],
        'Twk1Name'      => ["$forename $surname"],
        'Twk0Comment'   => [''],
        'Twk1FirstName' => [$forename],
        'Twk1LastName'  => [$surname],
        'action'        => ['register']
    };

    if ( $Foswiki::cfg{Register}{AllowLoginName} ) {
        $params->{"Twk1LoginName"} = $loginname;
    }
    my $query = Unit::Request->new($params);

    $query->path_info("/$this->{users_web}/UserRegistration");

    $this->createNewFoswikiSession( undef, $query );
    $this->assert( $this->{session}
          ->topicExists( $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName} )
    );

    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        $this->captureWithKey(
            register_cgi => \&Foswiki::UI::Register::register_cgi,
            $this->{session}
        );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        if ( $this->check_dependency('Foswiki,<,1.2') ) {
            $this->assert_str_equals( "attention", $e->{template},
                $e->stringify() );
            $this->assert_str_equals( "thanks", $e->{def}, $e->stringify() );
        }
        else {
            $this->assert_str_equals( "register", $e->{template},
                $e->stringify() );
            $this->assert_str_equals( "thanks", $e->{def}, $e->stringify() );
        }
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    # Reload caches
    $this->createNewFoswikiSession( undef, $q );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
}

1;
