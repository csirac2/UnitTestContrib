package FuncUsersTests;

use strict;
use warnings;

# These tests should pass for all usermappers written.
# Some basic tests for adding/removing users in the Foswiki users topic,
# and finding them again.

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Foswiki::Func;
use Foswiki::UI::Register;
use Error qw( :try );
use Data::Dumper;

my %loginname;

sub new {
    my $self = shift()->SUPER::new( 'FuncUsers', @_ );
    return $self;
}

sub AllowLoginName {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName} = 1;
    $loginname{UserA}                       = 'usera';
    $loginname{UserA86}                     = 'usera86';
    $loginname{User86A}                     = 'user86a';
    $loginname{UserB}                       = 'userb';
    $loginname{UserC}                       = 'userc';
    $loginname{NonExistantuser}             = 'nonexistantuser';
    $loginname{ScumBag}                     = 'scum';
    $loginname{UserZ}                       = 'userz';

    $loginname{DotLogin}   = 'dot.login';
    $loginname{EmailLogin} = 'email@example.com';

}

sub DontAllowLoginName {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName} = 0;
    $loginname{UserA}                       = 'UserA';
    $loginname{UserA86}                     = 'UserA86';
    $loginname{User86A}                     = 'User86A';
    $loginname{UserB}                       = 'UserB';
    $loginname{UserC}                       = 'UserC';
    $loginname{NonExistantuser}             = 'NonExistantuser';
    $loginname{ScumBag}                     = 'scum';

    #the scum user was registered _before_ these options in the base class
    $loginname{UserZ} = 'UserZ';

    $loginname{DotLogin}   = 'DotLogin';
    $loginname{EmailLogin} = 'EmailLogin';

}

sub TemplateLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::TemplateLogin';
}

sub ApacheLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::ApacheLogin';
}

sub NoLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager';
}

sub BaseUserMapping {
    my $this = shift;
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::BaseUserMapping';
}

sub TopicUserMapping {
    my $this = shift;
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::TopicUserMapping';
    $this->set_up_for_verify();
}

sub NonePasswordManager {
    $Foswiki::cfg{PasswordManager} = 'none';
}

sub HtPasswordPasswordManager {
    $Foswiki::cfg{PasswordManager} = 'Foswiki::Users::HtPasswdUser';
}

# See the pod doc in Unit::TestCase for details of how to use this
sub fixture_groups {
    return (
        [ 'NoLoginManager', 'ApacheLoginManager', 'TemplateLoginManager' ],
        [ 'AllowLoginName', 'DontAllowLoginName' ],
        [ 'NonePasswordManager', 'HtPasswordPasswordManager' ],
        ['TopicUserMapping']
    );    #TODO: 'BaseUserMapping'
}

#if we can't register, then thngs like GetCanonicalId(UserA) will fail, returning '' or undef
#TODO: These unit tests were not written to support the $Foswiki::cfg{PasswordManager} eq 'none' case
#need to analyse each test here and work out how they should work (ie, there is no spec either.)
sub noUsersRegistered {
    my $this = shift;
    return (
        ( $Foswiki::cfg{PasswordManager} eq 'none' )
          &&

          #            ($Foswiki::cfg{Register}{AllowLoginName} == 0) &&
          (
            $Foswiki::cfg{UserMappingManager} eq
            'Foswiki::Users::TopicUserMapping'
          )

#           &&  ($Foswiki::cfg{LoginManager} eq 'Foswiki::LoginManager::TemplateLogin')
    );
}

#delay the calling of set_up til after the cfg's are set by above closure
sub set_up_for_verify {
    my $this = shift;

    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{AdminUserLogin} );

    try {
        $this->registerUser( $loginname{UserA}, 'User', 'A',
            'user@example.com' );

        $this->registerUser( $loginname{UserA86}, 'User', 'A86',
            'user86@example.com' );
        $this->registerUser( $loginname{User86A}, 'User86', 'A',
            'user86a@example.com' );

        #TODO:
        #this should fail... as its the same as the one above
        #$this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
        #this one does fail..
        #$this->registerUser('86usera', '86User', 'A', 'user86a@example.com');
        $this->registerUser( $loginname{UserB}, 'User', 'B',
            'user@example.com' );
        $this->registerUser( $loginname{UserC}, 'User', 'C',
            'userc@example.com;userd@example.com' );

        $this->registerUser( $loginname{UserZ}, 'User', 'Z',
            'userZ@example.com' );

        $this->registerUser( $loginname{DotLogin}, 'Dot', 'Login',
            'dot@example.com' );

#            $this->registerUser($loginname{EmailLogin}, 'Email', 'Login', 'email@example.com');

        my $topicObject =
          Foswiki::Meta->new( $this->{session}, $this->{users_web},
            'AandBGroup',
            "   * Set GROUP = UserA, UserB, $Foswiki::cfg{AdminUserWikiName}" );
        $topicObject->save();
        $topicObject =
          Foswiki::Meta->new( $this->{session}, $this->{users_web},
            'AandCGroup', "   * Set GROUP = UserA, UserC" );
        $topicObject->save();
        $topicObject =
          Foswiki::Meta->new( $this->{session}, $this->{users_web},
            'BandCGroup', "   * Set GROUP = UserC, UserB" );
        $topicObject->save();
        $topicObject = Foswiki::Meta->new(
            $this->{session},
            $this->{users_web},
            'ScumGroup',
"   * Set GROUP = UserA, $Foswiki::cfg{DefaultUserWikiName}, $loginname{UserZ}"
        );
        $topicObject->save();
        $topicObject = Foswiki::Meta->new(
            $this->{session}, $this->{users_web},
            $Foswiki::cfg{SuperAdminGroup},
            "   * Set GROUP = UserA, $Foswiki::cfg{AdminUserWikiName}"
        );
        $topicObject->save();
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };

    # Force a re-read
    $this->{session}->finish();
    $this->{session}           = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    @FoswikiFntestCase::mails  = ();
}

sub verify_emailToWikiNames {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    my @users = Foswiki::Func::emailToWikiNames( 'userc@example.com', 1 );
    $this->assert_str_equals( "UserC", join( ',', @users ) );
    @users = Foswiki::Func::emailToWikiNames( 'userd@example.com', 0 );
    $this->assert_str_equals( "$this->{users_web}.UserC", join( ',', @users ) );
    @users = Foswiki::Func::emailToWikiNames( 'user@example.com', 1 );
    $this->assert_str_equals( "UserA,UserB", join( ',', sort @users ) );
}

sub verify_wikiNameToEmails {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    my @emails = Foswiki::Func::wikinameToEmails('UserA');
    $this->assert_str_equals( "user\@example.com", join( ',', @emails ) );
    @emails = Foswiki::Func::wikinameToEmails('UserB');
    $this->assert_str_equals( "user\@example.com", join( ',', @emails ) );
    @emails = Foswiki::Func::wikinameToEmails('UserC');
    $this->assert_str_equals(
        "userd\@example.com,userc\@example.com",
        join( ',', reverse sort @emails )
    );
    @emails = Foswiki::Func::wikinameToEmails('AandCGroup');
    $this->assert_str_equals(
        "userd\@example.com,userc\@example.com,user\@example.com",
        join( ',', reverse sort @emails ) );
}

sub verify_eachUser {
    my $this = shift;
    @FoswikiFntestCase::mails = ();

    my @list;
    my $ite = Foswiki::Func::eachUser();
    while ( $ite->hasNext() ) {
        my $u = $ite->next();
        push( @list, $u );
    }
    my $ulist = join( ',', sort @list );

    my @correctList;
    if (
        $Foswiki::cfg{UserMappingManager} eq 'Foswiki::Users::BaseUserMapping' )
    {
        @correctList =
          qw/ProjectContributor RegistrationAgent UnknownUser WikiGuest/;
    }
    else {
        @correctList =
          qw/ProjectContributor RegistrationAgent UnknownUser User86A UserA UserA86 UserB UserC UserZ WikiGuest DotLogin/;
        if ( $Foswiki::cfg{Register}{AllowLoginName} == 1 ) {
            push @correctList, 'ScumBag'
              ; # this user is created in the base class with the assumption of AllowLoginName
        }
        else {
            push @correctList, 'scum';    #
        }
    }
    push @correctList, $Foswiki::cfg{AdminUserWikiName};
    my $correct = join( ',', sort @correctList );
    $this->assert_str_equals( $correct, $ulist );
}

sub verify_eachGroupTraditional {
    my $this = shift;
    my @list;

    $Foswiki::cfg{SuperAdminGroup} = 'AdminGroup';

    # Force a re-read
    $this->{session}->finish();
    $this->{session}           = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    @FoswikiFntestCase::mails  = ();

    my $ite = Foswiki::Func::eachGroup();
    while ( $ite->hasNext() ) {
        my $u = $ite->next();
        push( @list, $u );
    }
    my $ulist = join( ',', sort @list );
    my @correctList;
    if (
        $Foswiki::cfg{UserMappingManager} eq 'Foswiki::Users::BaseUserMapping' )
    {
        @correctList = qw/AdminGroup BaseGroup/;
    }
    else {
        @correctList =
          qw/AandBGroup AandCGroup BandCGroup ScumGroup AdminGroup BaseGroup/;
    }
    my $correct = join( ',', sort @correctList );
    $this->assert_str_equals( $correct, $ulist );
}

sub verify_eachGroupCustomAdmin {
    my $this = shift;
    my @list;

    $Foswiki::cfg{SuperAdminGroup} = 'Super Admin';

    # Force a re-read
    $this->{session}->finish();
    $this->{session}           = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    @FoswikiFntestCase::mails  = ();

    my $ite = Foswiki::Func::eachGroup();
    while ( $ite->hasNext() ) {
        my $u = $ite->next();
        push( @list, $u );
    }
    my $ulist = join( ',', sort @list );
    my @correctList;
    if (
        $Foswiki::cfg{UserMappingManager} eq 'Foswiki::Users::BaseUserMapping' )
    {
        @correctList = qw/BaseGroup/;
    }
    else {
        @correctList =
          qw/AdminGroup AandBGroup AandCGroup BandCGroup ScumGroup BaseGroup/;
    }
    push @correctList, $Foswiki::cfg{SuperAdminGroup};
    my $correct = join( ',', sort @correctList );
    $this->assert_str_equals( $correct, $ulist );
}

# SMELL: nothing tests if we are an admin!
sub verify_isAnAdmin {
    my $this     = shift;
    my $iterator = Foswiki::Func::eachUser();
    while ( $iterator->hasNext() ) {
        my $u = $iterator->next();
        $u =~ /.*\.(.*)/;
        $Foswiki::Plugins::SESSION->{user} = $u;
        my $sadmin = Foswiki::Func::isAnAdmin($u);

        next if ( $this->noUsersRegistered() && ( $u eq 'UserA' ) );

        if (   $u eq $Foswiki::cfg{AdminUserWikiName}
#having rego agent an admin pretty much defeats the purpose of not making WikiGuest admin
#            || $u eq $Foswiki::cfg{Register}{RegistrationAgentWikiName}
            || $u eq 'UserA' )
        {
            $this->assert( $sadmin, $u );
        }
        else {
            $this->assert( !$sadmin, $u );
        }
    }
}

sub verify_isGroupMember {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    $Foswiki::Plugins::SESSION->{user} =
      $Foswiki::Plugins::SESSION->{users}
      ->getCanonicalUserID( $loginname{UserA} );
    $this->assert( $Foswiki::Plugins::SESSION->{user} );
    $this->assert( Foswiki::Func::isGroupMember('AandBGroup') );
    $this->assert( Foswiki::Func::isGroupMember('AandCGroup') );
    $this->assert( !Foswiki::Func::isGroupMember('BandCGroup') );
    $this->assert( Foswiki::Func::isGroupMember( 'BandCGroup', 'UserB' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'BandCGroup', 'UserC' ) );
    $this->assert(
        Foswiki::Func::isGroupMember(
            'ScumGroup', $Foswiki::cfg{DefaultUserWikiName}
        )
    );

    $this->assert( Foswiki::Func::isGroupMember( 'ScumGroup', 'UserZ' ) );
    $this->assert(
        Foswiki::Func::isGroupMember( 'ScumGroup', $loginname{UserZ} ) );

}

sub verify_eachMembership {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    my @list;
    my $it = Foswiki::Func::eachMembership('UserA');
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( 'AandBGroup,AandCGroup,AdminGroup,ScumGroup',
        join( ',', sort @list ) );
    $it   = Foswiki::Func::eachMembership('UserB');
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( 'AandBGroup,BandCGroup',
        join( ',', sort @list ) );

    $it   = Foswiki::Func::eachMembership('UserC');
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( 'AandCGroup,BandCGroup',
        sort join( ',', @list ) );

    $it   = Foswiki::Func::eachMembership('WikiGuest');
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( 'BaseGroup,ScumGroup', sort join( ',', @list ) );

    $it   = Foswiki::Func::eachMembership( $loginname{UserZ} );
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( 'ScumGroup', sort join( ',', @list ) );

    $it   = Foswiki::Func::eachMembership('UserZ');
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( 'ScumGroup', sort join( ',', @list ) );

}

sub verify_eachMembershipDefault {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    my $it   = Foswiki::Func::eachMembership();
    my @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->annotate(
        $Foswiki::Plugins::SESSION->{user} . " is member of...\n" );
    $this->assert_str_equals( 'BaseGroup,ScumGroup', sort join( ',', @list ) );
}

sub verify_eachGroupMember {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    my $it = Foswiki::Func::eachGroupMember('AandBGroup');
    my @list;
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( "UserA,UserB,$Foswiki::cfg{AdminUserWikiName}",
        sort join( ',', @list ) );

    $it   = Foswiki::Func::eachGroupMember('ScumGroup');
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( "UserA,$Foswiki::cfg{DefaultUserWikiName},UserZ",
        sort join( ',', @list ) );

}

sub verify_isGroup {
    my $this = shift;

    $this->assert( !Foswiki::Func::isGroup('UserA') );

    $this->assert( Foswiki::Func::isGroup( $Foswiki::cfg{SuperAdminGroup} ) );
    $this->assert( Foswiki::Func::isGroup('BaseGroup') );

    #Item5540
    $this->assert( !Foswiki::Func::isGroup('S') );
    $this->assert( !Foswiki::Func::isGroup('1') );
    $this->assert( !Foswiki::Func::isGroup('AS') );
    $this->assert( !Foswiki::Func::isGroup('') );
    $this->assert( !Foswiki::Func::isGroup('#') );

    return if ( $this->noUsersRegistered() );

    $this->assert( Foswiki::Func::isGroup('AandBGroup') );
}

sub verify_getCanonicalUserID_extended {
    my $this = shift;
    my $guest_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} );

    $this->assert_str_equals( $guest_cUID,
        Foswiki::Func::getCanonicalUserID() );

    $this->assert_str_equals( $guest_cUID,
        Foswiki::Func::getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} ) );
    $this->assert_str_equals( $guest_cUID,
        Foswiki::Func::getCanonicalUserID($guest_cUID) );
    $this->assert_str_equals( $guest_cUID,
        Foswiki::Func::getCanonicalUserID( $Foswiki::cfg{DefaultUserWikiName} )
    );
    $this->assert_str_equals(
        $guest_cUID,
        Foswiki::Func::getCanonicalUserID(
                $Foswiki::cfg{UsersWebName} . '.'
              . $Foswiki::cfg{DefaultUserWikiName}
        )
    );

    my $admin_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $Foswiki::cfg{AdminUserLogin} );
    $this->assert_str_equals( $admin_cUID,
        Foswiki::Func::getCanonicalUserID($admin_cUID) );
    $this->assert_str_equals( $admin_cUID,
        Foswiki::Func::getCanonicalUserID( $Foswiki::cfg{AdminUserLogin} ) );
    $this->assert_str_equals( $admin_cUID,
        Foswiki::Func::getCanonicalUserID( $Foswiki::cfg{AdminUserWikiName} ) );
    $this->assert_str_equals(
        $admin_cUID,
        Foswiki::Func::getCanonicalUserID(
            $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{AdminUserWikiName}
        )
    );

    #TODO: consider how to render unkown user's
    $this->assert_null( $this->{session}->{users}
          ->getCanonicalUserID( $loginname{NonExistantuser} ) );
    my $cUID = Foswiki::Func::getCanonicalUserID( $loginname{NonExistantuser} );
    $this->assert_null( $cUID, $cUID );
    $this->assert_null( Foswiki::Func::getCanonicalUserID('NonExistantUser') );
    $this->assert_null(
        Foswiki::Func::getCanonicalUserID(
            $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUser'
        )
    );
    $this->assert_null(
        Foswiki::Func::getCanonicalUserID(
            $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUser86'
        )
    );

    return if ( $this->noUsersRegistered() );

    my $usera_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{UserA} );
    $this->assert_str_equals( $usera_cUID,
        Foswiki::Func::getCanonicalUserID($usera_cUID) );
    $this->assert_str_equals( $usera_cUID,
        Foswiki::Func::getCanonicalUserID( $loginname{UserA} ) );
    $this->assert_str_equals( $usera_cUID,
        Foswiki::Func::getCanonicalUserID('UserA') );
    $this->assert_str_equals(
        $usera_cUID,
        Foswiki::Func::getCanonicalUserID(
            $Foswiki::cfg{UsersWebName} . '.' . 'UserA'
        )
    );

#            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
    my $usera86_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{UserA86} );
    $this->assert_str_equals( $usera86_cUID,
        Foswiki::Func::getCanonicalUserID($usera86_cUID) );
    $this->assert_str_equals( $usera86_cUID,
        Foswiki::Func::getCanonicalUserID( $loginname{UserA86} ) );
    $this->assert_str_equals( $usera86_cUID,
        Foswiki::Func::getCanonicalUserID('UserA86') );
    $this->assert_str_equals(
        $usera86_cUID,
        Foswiki::Func::getCanonicalUserID(
            $Foswiki::cfg{UsersWebName} . '.' . 'UserA86'
        )
    );

#            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{User86A} );
    $this->assert_str_equals( $user86a_cUID,
        Foswiki::Func::getCanonicalUserID($user86a_cUID) );
    $this->assert_str_equals( $user86a_cUID,
        Foswiki::Func::getCanonicalUserID( $loginname{User86A} ) );
    $this->assert_str_equals( $user86a_cUID,
        Foswiki::Func::getCanonicalUserID('User86A') );
    $this->assert_str_equals(
        $user86a_cUID,
        Foswiki::Func::getCanonicalUserID(
            $Foswiki::cfg{UsersWebName} . '.' . 'User86A'
        )
    );

#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

#TODO: consider what to return for GROUPs
#    $this->assert_null($this->{session}->{users}->getCanonicalUserID('AandBGroup'));
#    $this->assert_null(Foswiki::Func::getCanonicalUserID('AandBGroup'));
#    $this->assert_null(Foswiki::Func::getCanonicalUserID($Foswiki::cfg{UsersWebName}.'.'.'AandBGroup'));

#TODO: consider what to return for GROUPs
#    $this->assert_null($this->{session}->{users}->getCanonicalUserID($Foswiki::cfg{SuperAdminGroup}));
#    $this->assert_null(Foswiki::Func::getCanonicalUserID($Foswiki::cfg{SuperAdminGroup}));
#    $this->assert_null(Foswiki::Func::getCanonicalUserID($Foswiki::cfg{UsersWebName}.'.'.$Foswiki::cfg{SuperAdminGroup}));
}

sub verify_getWikiName_extended {
    my $this = shift;

    $this->assert_str_equals( $Foswiki::cfg{DefaultUserWikiName},
        Foswiki::Func::getWikiName() );

    my $guest_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} );
    $this->assert_str_equals( $Foswiki::cfg{DefaultUserWikiName},
        Foswiki::Func::getWikiName( $Foswiki::cfg{DefaultUserLogin} ) );
    $this->assert_str_equals(
        $Foswiki::cfg{DefaultUserWikiName},
        Foswiki::Func::getWikiName($guest_cUID)
    );
    $this->assert_str_equals( $Foswiki::cfg{DefaultUserWikiName},
        Foswiki::Func::getWikiName( $Foswiki::cfg{DefaultUserWikiName} ) );
    $this->assert_str_equals(
        $Foswiki::cfg{DefaultUserWikiName},
        Foswiki::Func::getWikiName(
                $Foswiki::cfg{UsersWebName} . '.'
              . $Foswiki::cfg{DefaultUserWikiName}
        )
    );

    my $admin_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $Foswiki::cfg{AdminUserLogin} );
    $this->annotate( $admin_cUID . ' => '
          . $Foswiki::cfg{AdminUserLogin} . ' => '
          . $Foswiki::cfg{AdminUserWikiName} );
    $this->assert_str_equals(
        $Foswiki::cfg{AdminUserWikiName},
        Foswiki::Func::getWikiName($admin_cUID)
    );
    $this->assert_str_equals( $Foswiki::cfg{AdminUserWikiName},
        Foswiki::Func::getWikiName( $Foswiki::cfg{AdminUserLogin} ) );
    $this->assert_str_equals( $Foswiki::cfg{AdminUserWikiName},
        Foswiki::Func::getWikiName( $Foswiki::cfg{AdminUserWikiName} ) );
    $this->assert_str_equals(
        $Foswiki::cfg{AdminUserWikiName},
        Foswiki::Func::getWikiName(
            $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{AdminUserWikiName}
        )
    );

    #TODO: consider how to render unkown user's
    #$Foswiki::cfg{RenderLoggedInButUnknownUsers} is false, or undefined

    $this->assert_str_equals( 'TopicUserMapping_NonExistantUser',
        Foswiki::Func::getWikiName('TopicUserMapping_NonExistantUser') );
    my $nonexistantuser_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $loginname{NonExistantuser} );
    $this->annotate($nonexistantuser_cUID);    #returns guest
    $this->assert_str_equals( $Foswiki::cfg{DefaultUserWikiName},
        Foswiki::Func::getWikiName($nonexistantuser_cUID) );
    $this->assert_str_equals( $loginname{NonExistantuser},
        Foswiki::Func::getWikiName( $loginname{NonExistantuser} ) );
    $this->assert_str_equals( 'NonExistantUser',
        Foswiki::Func::getWikiName('NonExistantUser') );
    $this->assert_str_equals(
        'NonExistantUser',
        Foswiki::Func::getWikiName(
            $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUser'
        )
    );
    $this->assert_str_equals(
        'NonExistantUser86',
        Foswiki::Func::getWikiName(
            $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUser86'
        )
    );

    return if ( $this->noUsersRegistered() );

    my $usera_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{UserA} );
    $this->assert_str_equals( 'UserA',
        Foswiki::Func::getWikiName($usera_cUID) );
    $this->assert_str_equals( 'UserA',
        Foswiki::Func::getWikiName( $loginname{UserA} ) );
    $this->assert_str_equals( 'UserA', Foswiki::Func::getWikiName('UserA') );
    $this->assert_str_equals(
        'UserA',
        Foswiki::Func::getWikiName(
            $Foswiki::cfg{UsersWebName} . '.' . 'UserA'
        )
    );

#            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
    my $usera86_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{UserA86} );
    $this->assert_str_equals( 'UserA86',
        Foswiki::Func::getWikiName($usera86_cUID) );
    $this->assert_str_equals( 'UserA86',
        Foswiki::Func::getWikiName( $loginname{UserA86} ) );
    $this->assert_str_equals( 'UserA86',
        Foswiki::Func::getWikiName('UserA86') );
    $this->assert_str_equals(
        'UserA86',
        Foswiki::Func::getWikiName(
            $Foswiki::cfg{UsersWebName} . '.' . 'UserA86'
        )
    );

#            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{User86A} );
    $this->assert_str_equals( 'User86A',
        Foswiki::Func::getWikiName($user86a_cUID) );
    $this->assert_str_equals( 'User86A',
        Foswiki::Func::getWikiName( $loginname{User86A} ) );
    $this->assert_str_equals( 'User86A',
        Foswiki::Func::getWikiName('User86A') );
    $this->assert_str_equals(
        'User86A',
        Foswiki::Func::getWikiName(
            $Foswiki::cfg{UsersWebName} . '.' . 'User86A'
        )
    );

#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

#TODO: consider how to render unkown user's
#my $AandBGroup_cUID = $this->{session}->{users}->getCanonicalUserID('AandBGroup');
#$this->annotate($AandBGroup_cUID);
#$this->assert_str_equals('AandBGroup', Foswiki::Func::getWikiName($AandBGroup_cUID));
#$this->assert_str_equals('AandBGroup', Foswiki::Func::getWikiName('AandBGroup'));
#$this->assert_str_equals('AandBGroup', Foswiki::Func::getWikiName('AandBGroup'));
#$this->assert_str_equals('AandBGroup', Foswiki::Func::getWikiName($Foswiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}

sub verify_getWikiUserName_extended {
    my $this = shift;

    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{DefaultUserWikiName},
        Foswiki::Func::getWikiUserName()
    );

    my $guest_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{DefaultUserWikiName},
        Foswiki::Func::getWikiUserName( $Foswiki::cfg{DefaultUserLogin} )
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{DefaultUserWikiName},
        Foswiki::Func::getWikiUserName($guest_cUID)
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{DefaultUserWikiName},
        Foswiki::Func::getWikiUserName( $Foswiki::cfg{DefaultUserWikiName} )
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{DefaultUserWikiName},
        Foswiki::Func::getWikiUserName(
                $Foswiki::cfg{UsersWebName} . '.'
              . $Foswiki::cfg{DefaultUserWikiName}
        )
    );

    my $admin_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $Foswiki::cfg{AdminUserLogin} );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{AdminUserWikiName},
        Foswiki::Func::getWikiUserName($admin_cUID) );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{AdminUserWikiName},
        Foswiki::Func::getWikiUserName( $Foswiki::cfg{AdminUserLogin} )
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{AdminUserWikiName},
        Foswiki::Func::getWikiUserName( $Foswiki::cfg{AdminUserWikiName} )
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{AdminUserWikiName},
        Foswiki::Func::getWikiUserName(
            $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{AdminUserWikiName}
        )
    );

    #TODO: consider how to render unkown user's
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUserAsdf',
        Foswiki::Func::getWikiUserName('NonExistantUserAsdf')
    );
    my $nonexistantuser_cUID =
      $this->{session}->{users}->getCanonicalUserID('nonexistantuserasdf');
    $this->annotate($nonexistantuser_cUID);    #returns guest
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{DefaultUserWikiName},
        Foswiki::Func::getWikiUserName($nonexistantuser_cUID)
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'nonexistantuserasdf',
        Foswiki::Func::getWikiUserName('nonexistantuserasdf')
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'nonexistantuserasdfqwer',
        Foswiki::Func::getWikiUserName('nonexistantuserasdfqwer')
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUserAsdf',
        Foswiki::Func::getWikiUserName('NonExistantUserAsdf')
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUserAsdf',
        Foswiki::Func::getWikiUserName(
            $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUserAsdf'
        )
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUserAsdf86',
        Foswiki::Func::getWikiUserName(
            $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUserAsdf86'
        )
    );

    return if ( $this->noUsersRegistered() );

    my $usera_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{UserA} );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'UserA',
        Foswiki::Func::getWikiUserName($usera_cUID)
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'UserA',
        Foswiki::Func::getWikiUserName( $loginname{UserA} )
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'UserA',
        Foswiki::Func::getWikiUserName('UserA')
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'UserA',
        Foswiki::Func::getWikiUserName(
            $Foswiki::cfg{UsersWebName} . '.' . 'UserA'
        )
    );

#            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
    my $usera86_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{UserA86} );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'UserA86',
        Foswiki::Func::getWikiUserName($usera86_cUID)
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'UserA86',
        Foswiki::Func::getWikiUserName( $loginname{UserA86} )
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'UserA86',
        Foswiki::Func::getWikiUserName('UserA86')
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'UserA86',
        Foswiki::Func::getWikiUserName(
            $Foswiki::cfg{UsersWebName} . '.' . 'UserA86'
        )
    );

#            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{User86A} );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'User86A',
        Foswiki::Func::getWikiUserName($user86a_cUID)
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'User86A',
        Foswiki::Func::getWikiUserName( $loginname{User86A} )
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'User86A',
        Foswiki::Func::getWikiUserName('User86A')
    );
    $this->assert_str_equals(
        $Foswiki::cfg{UsersWebName} . '.' . 'User86A',
        Foswiki::Func::getWikiUserName(
            $Foswiki::cfg{UsersWebName} . '.' . 'User86A'
        )
    );

#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

#TODO: consider how to render unknown users
#my $AandBGroup_cUID = $this->{session}->{users}->getCanonicalUserID('AandBGroup');
#$this->annotate($AandBGroup_cUID);
#$this->assert_str_equals($Foswiki::cfg{UsersWebName}.'.'.'AandBGroup', Foswiki::Func::getWikiUserName($AandBGroup_cUID));
#$this->assert_str_equals($Foswiki::cfg{UsersWebName}.'.'.'AandBGroup', Foswiki::Func::getWikiUserName('AandBGroup'));
#$this->assert_str_equals($Foswiki::cfg{UsersWebName}.'.'.'AandBGroup', Foswiki::Func::getWikiUserName('AandBGroup'));
#$this->assert_str_equals($Foswiki::cfg{UsersWebName}.'.'.'AandBGroup', Foswiki::Func::getWikiUserName($Foswiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}

sub verify_wikiToUserName_extended {
    my $this = shift;

    #TODO: not sure that this method needs to be able to convert _any_ to login
    my $guest_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} );
    $this->assert_str_equals( $Foswiki::cfg{DefaultUserLogin},
        Foswiki::Func::wikiToUserName($guest_cUID) );
    $this->assert_str_equals( $Foswiki::cfg{DefaultUserLogin},
        Foswiki::Func::wikiToUserName( $Foswiki::cfg{DefaultUserLogin} ) );
    $this->assert_str_equals( $Foswiki::cfg{DefaultUserLogin},
        Foswiki::Func::wikiToUserName( $Foswiki::cfg{DefaultUserWikiName} ) );
    $this->assert_str_equals(
        $Foswiki::cfg{DefaultUserLogin},
        Foswiki::Func::wikiToUserName(
                $Foswiki::cfg{UsersWebName} . '.'
              . $Foswiki::cfg{DefaultUserWikiName}
        )
    );

    my $admin_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $Foswiki::cfg{AdminUserLogin} );
    $this->assert_str_equals( $Foswiki::cfg{AdminUserLogin},
        Foswiki::Func::wikiToUserName($admin_cUID) );
    $this->assert_str_equals( $Foswiki::cfg{AdminUserLogin},
        Foswiki::Func::wikiToUserName( $Foswiki::cfg{AdminUserLogin} ) );
    $this->assert_str_equals( $Foswiki::cfg{AdminUserLogin},
        Foswiki::Func::wikiToUserName( $Foswiki::cfg{AdminUserWikiName} ) );
    $this->assert_str_equals(
        $Foswiki::cfg{AdminUserLogin},
        Foswiki::Func::wikiToUserName(
            $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{AdminUserWikiName}
        )
    );

    #TODO: consider how to render unkown user's
    $this->assert_null(
        Foswiki::Func::wikiToUserName('TopicUserMapping_NonExistantUser') );
    $this->assert_null(
        Foswiki::Func::wikiToUserName( $loginname{NonExistantuser} ) );
    $this->assert_null( Foswiki::Func::wikiToUserName('NonExistantUser') );
    $this->assert_null(
        Foswiki::Func::wikiToUserName(
            $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUser'
        )
    );
    $this->assert_null(
        Foswiki::Func::wikiToUserName(
            $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUser86'
        )
    );

    return if ( $this->noUsersRegistered() );
    my $usera_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{UserA} );
    $this->assert_str_equals( $loginname{UserA},
        Foswiki::Func::wikiToUserName($usera_cUID) );
    $this->assert_str_equals( $loginname{UserA},
        Foswiki::Func::wikiToUserName( $loginname{UserA} ) );
    $this->assert_str_equals( $loginname{UserA},
        Foswiki::Func::wikiToUserName('UserA') );
    $this->assert_str_equals(
        $loginname{UserA},
        Foswiki::Func::wikiToUserName(
            $Foswiki::cfg{UsersWebName} . '.' . 'UserA'
        )
    );

#            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
    my $usera86_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{UserA86} );
    $this->assert_str_equals( $loginname{UserA86},
        Foswiki::Func::wikiToUserName($usera86_cUID) );
    $this->assert_str_equals( $loginname{UserA86},
        Foswiki::Func::wikiToUserName( $loginname{UserA86} ) );
    $this->assert_str_equals( $loginname{UserA86},
        Foswiki::Func::wikiToUserName('UserA86') );
    $this->assert_str_equals(
        $loginname{UserA86},
        Foswiki::Func::wikiToUserName(
            $Foswiki::cfg{UsersWebName} . '.' . 'UserA86'
        )
    );

#            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{User86A} );
    $this->assert_str_equals( $loginname{User86A},
        Foswiki::Func::wikiToUserName($user86a_cUID) );
    $this->assert_str_equals( $loginname{User86A},
        Foswiki::Func::wikiToUserName( $loginname{User86A} ) );
    $this->assert_str_equals( $loginname{User86A},
        Foswiki::Func::wikiToUserName('User86A') );
    $this->assert_str_equals(
        $loginname{User86A},
        Foswiki::Func::wikiToUserName(
            $Foswiki::cfg{UsersWebName} . '.' . 'User86A'
        )
    );

#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

#TODO: consider how to render unkown user's
#my $AandBGroup_cUID = $this->{session}->{users}->getCanonicalUserID('AandBGroup');
#$this->annotate($AandBGroup_cUID);
#$this->assert_str_equals('AandBGroup', Foswiki::Func::wikiToUserName($AandBGroup_cUID));
#$this->assert_str_equals('AandBGroup', Foswiki::Func::wikiToUserName('AandBGroup'));
#$this->assert_str_equals('AandBGroup', Foswiki::Func::wikiToUserName('AandBGroup'));
#$this->assert_str_equals('AandBGroup', Foswiki::Func::wikiToUserName($Foswiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}

sub verify_isAnAdmin_extended {
    my $this = shift;

    #TODO: not sure that this method needs to be able to convert _any_ to login
    my $guest_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} );
    $this->assert(
        !Foswiki::Func::isAnAdmin( $Foswiki::cfg{DefaultUserLogin} ) );
    $this->assert( !Foswiki::Func::isAnAdmin($guest_cUID) );
    $this->assert(
        !Foswiki::Func::isAnAdmin( $Foswiki::cfg{DefaultUserWikiName} ) );
    $this->assert(
        !Foswiki::Func::isAnAdmin(
                $Foswiki::cfg{UsersWebName} . '.'
              . $Foswiki::cfg{DefaultUserWikiName}
        )
    );

    my $admin_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $Foswiki::cfg{AdminUserLogin} );
    $this->assert( Foswiki::Func::isAnAdmin($admin_cUID) );
    $this->assert( Foswiki::Func::isAnAdmin( $Foswiki::cfg{AdminUserLogin} ) );
    $this->assert(
        Foswiki::Func::isAnAdmin( $Foswiki::cfg{AdminUserWikiName} ) );
    $this->assert(
        Foswiki::Func::isAnAdmin(
            $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{AdminUserWikiName}
        )
    );

    return if ( $this->noUsersRegistered() );

    #TODO: consider how to render unkown user's
    $this->assert(
        !Foswiki::Func::isAnAdmin('TopicUserMapping_NonExistantUser') );
    my $nonexistantuser_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $loginname{NonExistantuser} );
    $this->annotate($nonexistantuser_cUID);
    $this->assert( !Foswiki::Func::isAnAdmin($nonexistantuser_cUID) );
    $this->assert( !Foswiki::Func::isAnAdmin( $loginname{NonExistantuser} ) );
    $this->assert( !Foswiki::Func::isAnAdmin('NonExistantUser') );
    $this->assert(
        !Foswiki::Func::isAnAdmin(
            $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUser'
        )
    );

    my $usera_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{UserA} );
    $this->assert( Foswiki::Func::isAnAdmin($usera_cUID) );
    $this->assert( Foswiki::Func::isAnAdmin( $loginname{UserA} ) );
    $this->assert( Foswiki::Func::isAnAdmin('UserA') );
    $this->assert(
        Foswiki::Func::isAnAdmin( $Foswiki::cfg{UsersWebName} . '.' . 'UserA' )
    );

    $this->assert(
        !Foswiki::Func::isAnAdmin(
            $Foswiki::cfg{UsersWebName} . '.' . 'UserB'
        )
    );
    my $userb_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{UserB} );
    $this->assert( !Foswiki::Func::isAnAdmin($userb_cUID) );
    $this->assert( !Foswiki::Func::isAnAdmin( $loginname{UserB} ) );
    $this->assert( !Foswiki::Func::isAnAdmin('UserB') );

#TODO: consider how to render unkown user's
#my $AandBGroup_cUID = $this->{session}->{users}->getCanonicalUserID('AandBGroup');
#$this->annotate($AandBGroup_cUID);
#$this->assert(!Foswiki::Func::isAnAdmin($AandBGroup_cUID));
#$this->assert(!Foswiki::Func::isAnAdmin('AandBGroup'));
#$this->assert(!Foswiki::Func::isAnAdmin('AandBGroup'));
#$this->assert(!Foswiki::Func::isAnAdmin($Foswiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}

sub verify_isGroupMember_extended {
    my $this = shift;

    my $guest_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} );
    my $admin_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $Foswiki::cfg{AdminUserLogin} );

    $this->assert(
        !Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup},
            $Foswiki::cfg{DefaultUserLogin}
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup}, $guest_cUID
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup},
            $Foswiki::cfg{DefaultUserWikiName}
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup},
            $Foswiki::cfg{UsersWebName} . '.'
              . $Foswiki::cfg{DefaultUserWikiName}
        )
    );

    $this->assert(
        Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup}, $admin_cUID
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup},
            $Foswiki::cfg{AdminUserLogin}
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup},
            $Foswiki::cfg{AdminUserWikiName}
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup},
            $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{AdminUserWikiName}
        )
    );

    return if ( $this->noUsersRegistered() );

    #TODO: not sure that this method needs to be able to convert _any_ to login
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandBGroup', $Foswiki::cfg{DefaultUserLogin}
        )
    );
    $this->assert( !Foswiki::Func::isGroupMember( 'AandBGroup', $guest_cUID ) );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandBGroup', $Foswiki::cfg{DefaultUserWikiName}
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandBGroup',
            $Foswiki::cfg{UsersWebName} . '.'
              . $Foswiki::cfg{DefaultUserWikiName}
        )
    );

    $this->assert( Foswiki::Func::isGroupMember( 'AandBGroup', $admin_cUID ) );
    $this->assert(
        Foswiki::Func::isGroupMember(
            'AandBGroup', $Foswiki::cfg{AdminUserLogin}
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            'AandBGroup', $Foswiki::cfg{AdminUserWikiName}
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            'AandBGroup',
            $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{AdminUserWikiName}
        )
    );

    $this->assert( !Foswiki::Func::isGroupMember( 'AandCGroup', $admin_cUID ) );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandCGroup', $Foswiki::cfg{AdminUserLogin}
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandCGroup', $Foswiki::cfg{AdminUserWikiName}
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandCGroup',
            $Foswiki::cfg{UsersWebName} . '.' . $Foswiki::cfg{AdminUserWikiName}
        )
    );

    my $usera_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{UserA} );
    $this->assert( Foswiki::Func::isGroupMember( 'AandBGroup', $usera_cUID ) );
    $this->assert(
        Foswiki::Func::isGroupMember( 'AandBGroup', $loginname{UserA} ) );
    $this->assert( Foswiki::Func::isGroupMember( 'AandBGroup', 'UserA' ) );
    $this->assert(
        Foswiki::Func::isGroupMember(
            'AandBGroup', $Foswiki::cfg{UsersWebName} . '.' . 'UserA'
        )
    );

    #TODO: consider how to render unkown user's
    my $nonexistantuser_cUID =
      $this->{session}->{users}
      ->getCanonicalUserID( $loginname{NonExistantuser} );
    $this->annotate($nonexistantuser_cUID);
    $this->assert(
        !Foswiki::Func::isGroupMember( 'AandBGroup', $nonexistantuser_cUID ) );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandBGroup', $loginname{NonExistantuser}
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember( 'AandBGroup', 'NonExistantUser' ) );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandBGroup', $Foswiki::cfg{UsersWebName} . '.' . 'NonExistantUser'
        )
    );

#TODO: consider how to render unkown user's
#my $AandBGroup_cUID = $this->{session}->{users}->getCanonicalUserID('AandBGroup');
#$this->annotate($AandBGroup_cUID);
#$this->assert(!Foswiki::Func::isGroupMember('AandBGroup', $AandBGroup_cUID));
#$this->assert(!Foswiki::Func::isGroupMember('AandBGroup', 'AandBGroup'));
#$this->assert(!Foswiki::Func::isGroupMember('AandBGroup', 'AandBGroup'));
#$this->assert(!Foswiki::Func::isGroupMember('AandBGroup', $Foswiki::cfg{UsersWebName}.'.'.'AandBGroup'));

    #baseusermapping group
    $this->assert(
        Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup}, $usera_cUID
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup},
            $loginname{UserA}
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember( $Foswiki::cfg{SuperAdminGroup}, 'UserA' )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup},
            $Foswiki::cfg{UsersWebName} . '.' . 'UserA'
        )
    );

    $this->assert(
        !Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup},
            $loginname{UserB}
        )
    );
    my $userb_cUID =
      $this->{session}->{users}->getCanonicalUserID( $loginname{UserB} );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup}, $userb_cUID
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup}, 'UserB'
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            $Foswiki::cfg{SuperAdminGroup},
            $Foswiki::cfg{UsersWebName} . '.' . 'UserB'
        )
    );

}

#http://foswiki.org/Tasks/Item6000
# Done here rather than in Fn_META to leverage the test fixture
sub verify_topic_meta_usermapping {
    my $this = shift;

    return if ( $Foswiki::cfg{Register}{AllowLoginName} == 0 );

    my $ret;

    $Foswiki::cfg{RenderLoggedInButUnknownUsers} = 1;

    my $web   = $this->{test_web};
    my $topic = "TestStoreTopic";

    open( FILE, ">$Foswiki::cfg{TempfileDir}/testfile.gif" );
    print FILE "one two three";
    close(FILE);

    my $oldCfg = $Foswiki::cfg{LoginNameFilterIn};
    $Foswiki::cfg{LoginNameFilterIn} = qr/^[^\s\*?~^\$%`"'&;|<>\x00-\x1f]+$/;

    my $login = 'asdf2@example.com';
    $this->registerUser( $login, 'Asdf3', 'Poiu', 'asdf2@example.com' );
    my $cUID = Foswiki::Func::getCanonicalUserID($login);
    $this->{session}->{user} = $cUID;    # OUCH!

    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $web, $topic, $text );
    $topicObject->save();

    $this->assert( $this->{session}->topicExists( $web, $topic ) );
    my $readMeta = Foswiki::Meta->load( $this->{session}, $web, $topic );
    my $info = $readMeta->getRevisionInfo();
    $this->assert_equals( $info->{author}, $cUID, "$info->{author}=$cUID" );
    my $revinfo = Foswiki::Func::expandCommonVariables(
      '%REVINFO{format="$wikiname"}%', $topic, $web, $readMeta );

    #Task:Item6000
    $this->assert_equals( $revinfo, 'Asdf3Poiu', 'Asdf3Poiu' );

    $readMeta->attach(
        name    => "testfile.gif",
        file    => "$Foswiki::cfg{TempfileDir}/testfile.gif",
        comment => "a comment"
    );
    $readMeta = Foswiki::Meta->load( $this->{session}, $web, $topic );

    my @attachments = $readMeta->find('FILEATTACHMENT');
    $this->assert_equals( 1, scalar @attachments );
    foreach my $a (@attachments) {

        #Task:Item6000
        $this->assert_str_equals( $cUID, $a->{user} );
    }

    #META
    my $metainfo = $readMeta->expandMacros('%META{"attachments"}%');

    #Task:Item6000
    $metainfo =~ s/^.*?(\|.*\|).*?$/$1/s;
    $metainfo =~ s/(01 Jan 1970\s*-\s*)[-\d+:]*/${1}TIME/g;
    $this->assert_html_equals( <<HERE, $metainfo );
| *I* | *Attachment* | *Action* | *Size* | *Date* | *Who* | *Comment* |
| <span class=foswikiIcon><img width="16" alt="testfile.gif" src="$Foswiki::cfg{PubUrlPath}/System/DocumentGraphics/gif.png" height="16" /></span><span class="foswikiHidden">gif</span> | <a href="$Foswiki::cfg{PubUrlPath}/TemporaryFuncUsersTestWebFuncUsers/TestStoreTopic/testfile.gif"><noautolink>testfile.gif</noautolink></a> | <a href="$Foswiki::cfg{ScriptUrlPath}/attach$Foswiki::cfg{ScriptSuffix}/TemporaryFuncUsersTestWebFuncUsers/TestStoreTopic?filename=testfile.gif;revInfo=1" title="change, update, previous revisions, move, delete..." rel="nofollow">manage</a> |  0.1&nbsp;K|<span class="foswikiNoBreak">01 Jan 1970 - TIME</span> |TemporaryFuncUsersUsersWeb.Asdf3Poiu  |a comment  |
HERE
}

sub verify_addToGroup {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    my $Zcuid =
      $Foswiki::Plugins::SESSION->{users}
      ->getCanonicalUserID( $loginname{UserZ} );
    $this->assert( $Foswiki::Plugins::SESSION->{user} );

    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );
    $this->assert( !Foswiki::Func::addUserToGroup('UserZ',  'ZeeGroup') );

    # Force a re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );

    #TODO: need to test who the topic was saved by

    $this->assert( Foswiki::Func::addUserToGroup('UserZ',  'ZeeGroup', 1 ) );

    # Force a re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );

    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA' ) );
    $this->assert( Foswiki::Func::addUserToGroup( 'UserA' , 'ZeeGroup') );

    # Force a re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA' ) );

    $this->assert(
        !Foswiki::Func::isGroupMember(
            'ZeeGroup', $Foswiki::cfg{DefaultUserLogin}
        )
    );
    $this->assert(
        Foswiki::Func::addUserToGroup(
            $Foswiki::cfg{DefaultUserLogin}, 'ZeeGroup'
        )
    );

    # Force a re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->assert(
        Foswiki::Func::isGroupMember(
            'ZeeGroup', $Foswiki::cfg{DefaultUserLogin}
        )
    );

    $this->assert(
        !Foswiki::Func::isGroupMember( 'ZeeGroup', 'WiseGuyDoesntExist' ) );
    $this->assert(
        !Foswiki::Func::addUserToGroup('WiseGuyDoesntExist', 'ZeeGroup' ) );

    # Force a re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->assert(
        !Foswiki::Func::isGroupMember('WiseGuyDoesntExist', 'ZeeGroup') );
}

sub DISABLEDverify_addGroupToGroup {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    #test nested groups
    $this->assert( Foswiki::Func::addUserToGroup('UserB', 'TeeGroup',    1 ) );
    $this->assert( Foswiki::Func::addUserToGroup('ZeeGroup', 'TeeGroup', 1 ) );

    # Force a re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->assert( !Foswiki::Func::isGroupMember( 'TeeGroup', 'UserB' ) );
    $this->assert( !Foswiki::Func::isGroupMember( 'TeeGroup', 'UserA' ) );
}

sub verify_removeFromGroup {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );
    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA' ) );
    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserB' ) );
    $this->assert(
        !Foswiki::Func::isGroupMember('WiseGuyDoesntExist' , 'ZeeGroup') );

    $this->assert( Foswiki::Func::addUserToGroup('UserZ',  'ZeeGroup', 1 ) );
    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );
    $this->assert( Foswiki::Func::addUserToGroup('UserA',  'ZeeGroup', 1 ) );
    $this->assert( Foswiki::Func::addUserToGroup('UserB', 'ZeeGroup',  1 ) );

    # Force a re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserB' ) );
    $this->assert(
        !Foswiki::Func::isGroupMember('WiseGuyDoesntExist', 'ZeeGroup' ) );

    $this->assert( Foswiki::Func::removeUserFromGroup('UserA', 'ZeeGroup' ) );
    $this->assert(
        !Foswiki::Func::removeUserFromGroup( 'WiseGuyDoesntExist', 'ZeeGroup' )
    );

    # Force a re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};

    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );
    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserB' ) );
    $this->assert(
        !Foswiki::Func::isGroupMember( 'ZeeGroup', 'WiseGuyDoesntExist' ) );
}

sub DISABLEDverify_removeFromGroup {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    #test nested groups
    $this->assert( Foswiki::Func::addUserToGroup( 'UserB',   'TeeGroup',  1 ) );
    $this->assert( Foswiki::Func::addUserToGroup( 'UserC',    'TeeGroup', 1 ) );
    $this->assert( Foswiki::Func::addUserToGroup('ZeeGroup', 'TeeGroup',  1 ) );

    # Force a re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->assert( Foswiki::Func::isGroupMember( 'TeeGroup', 'UserB' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'TeeGroup', 'UserA' ) );

    $this->assert( !Foswiki::Func::removeUserFromGroup( 'UserA' , 'TeeGroup') )
      ;    #can't remove user as they come from a subgroup..
    $this->assert( Foswiki::Func::removeUserFromGroup( 'UserB', 'TeeGroup' ) );

    # Force a re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->assert( !Foswiki::Func::isGroupMember( 'TeeGroup', 'UserB' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'TeeGroup', 'UserA' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'TeeGroup', 'UserC' ) );

    $this->assert(
        Foswiki::Func::removeUserFromGroup('ZeeGroup' , 'TeeGroup') );

    # Force a re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $Foswiki::Plugins::SESSION = $this->{session};
    $this->assert( !Foswiki::Func::isGroupMember( 'TeeGroup', 'UserB' ) );
    $this->assert( !Foswiki::Func::isGroupMember( 'TeeGroup', 'UserA' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'TeeGroup', 'UserC' ) );

    #TODO: test what happens if there are no users left in the group
}

#http://foswiki.org/Tasks/Item1936
sub verify_topic_meta_usermapping_Item1936 {
    my $this = shift;
    
    my $users = $this->{session}->{users};
    
    #this sort of issue is what this setting was supposed to make more obvious
	#$Foswiki::cfg{RenderLoggedInButUnknownUsers} = 1;

    
	$this->assert_null(Foswiki::Func::getCanonicalUserID('NonExistantUser'));
	$users->getWikiName( 'NonExistantUser' );
	$this->assert_null(Foswiki::Func::getCanonicalUserID('NonExistantUser'));
    
}

#http://foswiki.org/Tasks/
sub verify_unregisteredUser_display {
    my $this = shift;
    
    my $users = $this->{session}->{users};
    
    #this sort of issue is what this setting was supposed to make more obvious
	#$Foswiki::cfg{RenderLoggedInButUnknownUsers} = 1;

	$this->assert_equals(
			$users->getWikiName( 'NonExistantUser' ),
			'NonExistantUser',
			'wikiword wikiname');
	$this->assert_equals(
			$users->getLoginName( 'NonExistantUser' ),
			undef,
			'wikiword wikiname');
	$this->assert_equals(
			$users->getCanonicalUserID( 'NonExistantUser' ),
			undef,
			'wikiword wikiname');
    
	$this->assert_equals(
			$users->getWikiName( 'user_name' ),
			'user_name',
			'wikiword wikiname');
	$this->assert_equals(
			$users->getLoginName( 'user_name' ),
			undef,
			'wikiword wikiname');
	$this->assert_equals(
			$users->getCanonicalUserID( 'user_name' ),
			undef,
			'wikiword wikiname');
}

1;
