package ViewFileScriptTests;

use base qw(FoswikiFnTestCase);

use strict;
use Foswiki;
use Foswiki::UI::Viewfile;
use Unit::Request;
use Error qw( :try );

my $fatwilly;
my $UI_FN;

sub new {

    #$Foswiki::cfg{Engine} = 'Foswiki::Engine::CLI' ;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $self = shift()->SUPER::new( "ViewFileScript", @_ );
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $UI_FN ||= $this->getUIFn('viewfile');

    $fatwilly = $this->{session};
    my $topic = 'TestTopic1';
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic,
        'topci1 text' );
    $topicObject->save();
    $this->sneakAttachmentsToTopic( $this->{test_web}, $topic,
        ( 'one.txt', 'two.txt', 'inc/file.txt' ) );

    $topic = 'SecureTopic';
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $topic,
        "SecureTopic text\n   * Set ALLOWTOPICVIEW=NoOneReal", undef );
    $topicObject->save();
    $this->sneakAttachmentsToTopic( $this->{test_web}, $topic,
        ( 'one.txt', 'two.txt', 'inc/file.txt' ) );

    #set up nested web $this->{test_web}/Nest
    $this->{test_subweb} = $this->{test_web} . '/Nest';
    $topic = 'TestTopic1';

    try {
        $this->{session} = new Foswiki('AdminUser');

        my $webObject =
          Foswiki::Meta->new( $this->{session}, $this->{test_subweb} );
        $webObject->populateNewWeb();
        $this->assert( $this->{session}->webExists( $this->{test_subweb} ) );
        my $topicObject =
          Foswiki::Meta->new( $this->{session}, $this->{test_subweb},
            $Foswiki::cfg{HomeTopicName}, "SMELL" );
        $topicObject->save();
        $this->assert(
            $this->{session}->topicExists(
                $this->{test_subweb}, $Foswiki::cfg{HomeTopicName}
            )
        );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_subweb}, $topic,
        'nested topci1 text', undef );
    $topicObject->save();
    $this->sneakAttachmentsToTopic( $this->{test_subweb}, $topic,
        ( 'one.txt', 'two.txt', 'inc/file.txt' ) );

    $topic = 'SecureTopic';
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_subweb}, $topic,
        "SecureTopic text\n   * Set ALLOWTOPICVIEW=NoOneReal", undef );
    $topicObject->save();
    $this->sneakAttachmentsToTopic( $this->{test_subweb}, $topic,
        ( 'one.txt', 'two.txt', 'inc/file.txt' ) );
}

sub touchFile {
    my ( $dir, $file ) = @_;
    my $filename = "$dir/$file";
    if ( open( my $FILE, '>', $filename ) ) {
        print $FILE "Test attachment $file\n";
        close($FILE);
    }
    else {
        die "failed ($!) to write to $filename\n";
    }
}

sub sneakAttachmentsToTopic {
    my $this = shift;
    my ( $web, $topic, @filenames ) = @_;
    my $dir = $Foswiki::cfg{PubDir};
    $dir = "$dir/$web/$topic";
    {
        my @dirs = split( /\//, $dir );
        my $path = '';
        foreach my $adir (@dirs) {
            $path .= '/' . $adir;
            mkdir($path) unless ( -e $path );
        }
    }

    #print STDERR "DEBUG: dir=$dir\n";

    foreach my $file (@filenames) {
        if ( $file =~ /\// ) {
            my @dirs = split( /\//, $file );
            pop(@dirs);
            my $path = $dir;
            foreach my $adir (@dirs) {
                $path .= '/' . $adir;
                mkdir($path);
            }
        }
        touchFile( $dir, $file );
    }
}

sub viewfile {
    my ( $this, $url ) = @_;
    my $query = new Unit::Request( {} );
    $query->setUrl($url);
    $query->method('GET');
    $fatwilly = new Foswiki( $this->{test_user_login}, $query );
    $this->{request}  = $query;
    $this->{response} = new Unit::Response();
    my ($text) = $this->capture(
        sub {
            try {
                no strict 'refs';
                &$UI_FN($fatwilly);
                use strict 'refs';
            }
            catch Error with {
                $fatwilly->{response}->print( shift->stringify() );
            }
            $Foswiki::engine->finalize( $fatwilly->{response},
                $fatwilly->{request} );
        }
    );

    $fatwilly->finish();
    $text =~ s/^.*\r\n//s;
    return $text;
}

sub test_simpleUrl {
    my $this = shift;

# Note 1: If we decide that trailing / after a topic name and no subweb exists with this name = go for topic name instead
# then we can re-activate these tests marked with Note1. See Foswikitask:Item598

    #simple topic, direct path
    $this->assert_str_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1/one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1/two.txt") );
    $this->assert_equals( "Test attachment inc/file.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1/inc/file.txt") );
}

sub test_oddities {
    my $this = shift;
    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1//one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_web}//TestTopic1/two.txt") );
    $this->assert_equals( "Test attachment inc/file.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1/inc//file.txt") );
}

sub test_simple_topic_filename_param {
    my $this = shift;
    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1?filename=one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1?filename=two.txt") );
    $this->assert_equals( "Test attachment inc/file.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1?filename=inc/file.txt")
    );

#Note1 $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/?filename=one.txt"));
#Note1 $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/?filename=two.txt"));
#Note1 $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/?filename=inc/file.txt"));
}

sub test_nasty_attachment_names {
    my $this = shift;
    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1?filename=/one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1?filename=/two.txt") );
    $this->assert_equals( "Test attachment inc/file.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1?filename=/inc/file.txt")
    );
}

sub test_nested_web_simple_topic_direct_path {
    my $this = shift;
    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1/one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1/two.txt") );
    $this->assert_equals( "Test attachment inc/file.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1/inc/file.txt") );

    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1//one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_subweb}//TestTopic1/two.txt") );
    $this->assert_equals( "Test attachment inc/file.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1/inc//file.txt") );
}

sub test_nested_web_simple_topic_filename_param {
    my $this = shift;
    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=two.txt") );
    $this->assert_equals(
        "Test attachment inc/file.txt\n",
        $this->viewfile(
            "/$this->{test_subweb}/TestTopic1?filename=inc/file.txt")
    );

#Note1 $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/?filename=one.txt"));
#Note1 $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/?filename=two.txt"));
#Note1 $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/?filename=inc/file.txt"));

    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=/one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=/two.txt") );
    $this->assert_equals(
        "Test attachment inc/file.txt\n",
        $this->viewfile(
            "/$this->{test_subweb}/TestTopic1?filename=/inc/file.txt")
    );
}

sub test_simple_web_secured_topic_direct_path {
    my $this = shift;

    $this->assert_equals(
'OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_web}/SecureTopic/one.txt")
    );
    $this->assert_equals(
'OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_web}/SecureTopic/two.txt")
    );
    $this->assert_equals(
'OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_web}/SecureTopic/inc/file.txt")
    );

    $this->assert_equals(
'OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_web}/SecureTopic//one.txt")
    );
    $this->assert_equals(
'OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_web}//SecureTopic/two.txt")
    );
    $this->assert_equals(
'OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_web}/SecureTopic/inc//file.txt")
    );

}

sub test_simple_web_secured_topic_filename_param {
    my $this = shift;
    $this->assert_equals(
'OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_web}/SecureTopic?filename=one.txt")
    );
    $this->assert_equals(
'OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_web}/SecureTopic?filename=two.txt")
    );
    $this->assert_equals(
'OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_web}/SecureTopic?filename=inc/file.txt")
    );

#Note1 $this->assert_equals('OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
#                            $this->viewfile("/$this->{test_web}/SecureTopic/?filename=one.txt"));
#Note1 $this->assert_equals('OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
#                            $this->viewfile("/$this->{test_web}/SecureTopic/?filename=two.txt"));
#Note1 $this->assert_equals('OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
#                            $this->viewfile("/$this->{test_web}/SecureTopic/?filename=inc/file.txt"));

    $this->assert_equals(
'OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_web}/SecureTopic?filename=/one.txt")
    );
    $this->assert_equals(
'OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_web}/SecureTopic?filename=/two.txt")
    );
    $this->assert_equals(
'OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile(
            "/$this->{test_web}/SecureTopic?filename=/inc/file.txt")
    );

}

sub test_nested_web_secured_topic_direct_path {
    my $this = shift;

    $this->assert_equals(
        'OopsException(accessdenied/topic_access web=>'
          . $this->{test_subweb}
          . ' topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_subweb}/SecureTopic/one.txt")
    );
    $this->assert_equals(
        'OopsException(accessdenied/topic_access web=>'
          . $this->{test_subweb}
          . ' topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_subweb}/SecureTopic/two.txt")
    );
    $this->assert_equals(
        'OopsException(accessdenied/topic_access web=>'
          . $this->{test_subweb}
          . ' topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_subweb}/SecureTopic/inc/file.txt")
    );

    $this->assert_equals(
        'OopsException(accessdenied/topic_access web=>'
          . $this->{test_subweb}
          . ' topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_subweb}/SecureTopic//one.txt")
    );
    $this->assert_equals(
        'OopsException(accessdenied/topic_access web=>'
          . $this->{test_subweb}
          . ' topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_subweb}//SecureTopic/two.txt")
    );
    $this->assert_equals(
        'OopsException(accessdenied/topic_access web=>'
          . $this->{test_subweb}
          . ' topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_subweb}/SecureTopic/inc//file.txt")
    );
}

sub test_nested_web_secured_topic_filename_param {
    my $this = shift;
    $this->assert_equals(
        'OopsException(accessdenied/topic_access web=>'
          . $this->{test_subweb}
          . ' topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=one.txt")
    );
    $this->assert_equals(
        'OopsException(accessdenied/topic_access web=>'
          . $this->{test_subweb}
          . ' topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=two.txt")
    );
    $this->assert_equals(
        'OopsException(accessdenied/topic_access web=>'
          . $this->{test_subweb}
          . ' topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile(
            "/$this->{test_subweb}/SecureTopic?filename=inc/file.txt")
    );

#Note1 $this->assert_equals('OopsException(accessdenied/topic_access web=>'.$this->{test_subweb} topic=>'.SecureTopic params=>[VIEW,access not allowed on topic])',
#                            $this->viewfile("/$this->{test_subweb}/SecureTopic/?filename=one.txt"));
#Note1 $this->assert_equals('OopsException(accessdenied/topic_access web=>'.$this->{test_subweb} topic=>'.SecureTopic params=>[VIEW,access not allowed on topic])',
#                            $this->viewfile("/$this->{test_subweb}/SecureTopic/?filename=two.txt"));
#Note1 $this->assert_equals('OopsException(accessdenied/topic_access web=>'.$this->{test_subweb} topic=>'.SecureTopic params=>[VIEW,access not allowed on topic])',
#                            $this->viewfile("/$this->{test_subweb}/SecureTopic/?filename=inc/file.txt"));

    $this->assert_equals(
        'OopsException(accessdenied/topic_access web=>'
          . $this->{test_subweb}
          . ' topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=/one.txt")
    );
    $this->assert_equals(
        'OopsException(accessdenied/topic_access web=>'
          . $this->{test_subweb}
          . ' topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=/two.txt")
    );
    $this->assert_equals(
        'OopsException(accessdenied/topic_access web=>'
          . $this->{test_subweb}
          . ' topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
        $this->viewfile(
            "/$this->{test_subweb}/SecureTopic?filename=/inc/file.txt")
    );

#illegal requests - use .. and funny chars and shell tricks to get access to files outside of life.
#$this->assert_equals("relative path in filename ../SecureTopic/one.txt at /data/home/www/foswiki/trunk/core/lib/Foswiki/Sandbox.pm line 136.\n",
#                    $this->viewfile("/$this->{test_subweb}/TestTopic1/../SecureTopic/one.txt"));
#TODO: add more nasty tricks
}

sub test_MIME_types {
    my $this = shift;

    $this->assert_equals(
        'application/vnd.adobe.air-application-installer-package+zip',
        Foswiki::UI::Viewfile::_suffixToMimeType('blah.air')
    );
    $this->assert_equals( 'text/h323',
        Foswiki::UI::Viewfile::_suffixToMimeType('blah.323') );
    $this->assert_equals( 'application/octet-stream',
        Foswiki::UI::Viewfile::_suffixToMimeType('blah.w02') );
    $this->assert_equals( 'text/plain',
        Foswiki::UI::Viewfile::_suffixToMimeType('blah.wibble') );
}

1;
