package ExtenderTests;

use strict;

use base qw(FoswikiTestCase);

use Error qw( :try );
use File::Temp;

# Establish where we are
my @path = ( 'tools', 'extender.pl' );
my $wd = Cwd::cwd();
$wd =~ /^(.*)test.unit$/;    # untaint
unshift( @path, $1 ) if $1;
my $script = File::Spec->catfile(@path);
chdir $1;                    # extender.pl needs this

unless ( my $return = do $script ) {
    my $message = <<MESSAGE;
************************************************************
Could not load $script
MESSAGE

    if ($@) {
        $message .= "There was a compile error: $@\n";
    }
    elsif ( defined $return ) {
        $message .= "There was a file error: $!\n";
    }
    else {
        $message .= "An unspecified error occurred\n";
    }
    $message .= <<MESSAGE;
(if this is a TWiki release prior to 4.2, you can download this
 file from: http://twiki.org/cgi-bin/view/Codev/ExtenderScript
 and place it in
 $wd/tools
 Create the directory if necessary).
************************************************************
MESSAGE
    die $message;    # Propagate
}
chdir $wd;           # Return after loading extender.pl

sub test_check_dep_not_perl {
    my ($this) = @_;

    # Check an external dependency
    # 0, Module is type external, and cannot be automatically checked.
    my ( $ok, $message ) = Foswiki::Extender::check_dep(
        { type => "external", name => "libpcap", version => "1.0.0" } );
    $this->assert_equals( 0, $ok );
    $this->assert_matches( qr/cannot be automatically checked/, $message );
}

sub test_check_dep_carp {
    my ($this) = @_;

    # Check a normal instally dependency
    # 1, Carp v1.03 loaded
    my ( $ok, $message ) =
      Foswiki::Extender::check_dep( { type => "perl", name => "Carp" } );
    $this->assert_equals( 1, $ok );
    $this->assert_matches( qr/Carp v.* loaded/, $message );

}

sub test_check_dep_version_too_high {
    my ($this) = @_;

    # Check a normal installed dependency with an absurd high version number
    # 0, HTML::Parser version 21.1 required--this is only version 1.05
    my ( $ok, $message ) = Foswiki::Extender::check_dep(
        { type => "cpan", name => "HTML::Parser", version => "21.1" } );
    $this->assert_equals( 0, $ok );
    $this->assert_matches(
        qr/HTML::Parser version 21\.1 required--this is only version/,
        $message );

}

sub test_check_dep_version_with_superior {
    my ($this) = @_;

    # Check a normal installed dependency with an absurd high version number
    # 0, HTML::Parser version 21.1 required--this is only version 1.05
    my ( $ok, $message ) = Foswiki::Extender::check_dep(
        { type => "cpan", name => "HTML::Parser", version => ">=21.1" } );
    $this->assert_equals( 0, $ok );
    $this->assert_matches(
        qr/HTML::Parser version 21\.1 required--this is only version/,
        $message );

}

sub test_check_dep_version_with_rev {
    my ($this) = @_;

    # Check a normal installed dependency with an absurd high version number
    # 0, HTML::Parser version 21.1 required--this is only version 1.05
    my ( $ok, $message ) = Foswiki::Extender::check_dep(
        {
            type    => "perl",
            name    => "Foswiki::Contrib::JSCalendarContrib",
            version => ">=0.961"
        }
    );
    $this->assert_equals( 1, $ok );
    $this->assert_matches( qr/Foswiki::Contrib::JSCalendarContrib v.* loaded/,
        $message );

}

1;
