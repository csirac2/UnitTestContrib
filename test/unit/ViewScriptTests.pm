use strict;

package ViewScriptTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::UI::View;
use Error qw( :try );

my $fatwilly;
my $UI_FN;

my $topic1 = <<'HERE';
CONTENT
HERE

my $topic2 = <<'HERE';
----
WikiWord %BR%
!ExclamationEscape <br />
<nop>NopEscape 
%RED% <pre> adsf </pre> <verbatim> qwerty </verbatim
<p>A Paragraph </p>
#anchor
<a href="http://blah.com/">asdf</a>
<noautolink>
NotTOAutoLink
</noautolink>
----
HERE

my $topic2meta = '%META:TOPICINFO{author="BaseUserMapping_666" comment="" date="[0-9]{10,10}" format="1.1" version="1"}%\n'; 
my $topic2metaQ = $topic2meta; 
$topic2metaQ =~ s/"/&quot;/g; 

my $topic2txtarea = '<textarea name=""  rows="22" cols="70" readonly="readonly" style="width:99%" id="topic" class="foswikiTextarea foswikiTextareaRawView">';

my $topic2rawON = $topic2;
$topic2rawON =~ s/</&lt;/g;
$topic2rawON =~ s/>/&gt;/g;
$topic2rawON =~ s/"/&quot;/g;
$topic2rawON .= '</textarea>';

my $templateTopicContent1 = <<'HERE';
pretemplate%STARTTEXT%pre%TEXT%post%ENDTEXT%posttemplate
HERE

my $templateTopicContent2 = <<'HERE';
pretemplate%TEXT%post%ENDTEXT%posttemplate
HERE

my $templateTopicContent3 = <<'HERE';
pretemplate%STARTTEXT%pre%TEXT%posttemplate
HERE

my $templateTopicContent4 = <<'HERE';
pretemplate%TEXT%posttemplate
HERE

my $templateTopicContent5 = <<'HERE';
pretemplate%STARTTEXT%posttemplate
HERE

## Should this be supported?
my $templateTopicContentX = <<'HERE';
pretemplate%STARTTEXT%pre%ENDTEXT%posttemplate
HERE

sub new {
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my $self = shift()->SUPER::new( "ViewScript", @_ );
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $UI_FN ||= $this->getUIFn('view');

    $fatwilly = $this->{session};

    #set up nested web $this->{test_web}/Nest
    $this->{test_subweb} = $this->{test_web} . '/Nest';
    my $topic = 'TestTopic1';
    my $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestTopic1',
        $topic1, undef );
    $meta->save();

    $topic = 'TestTopic2';
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'TestTopic2',
        $topic2, undef );
    $meta->save();

    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'ViewoneTemplate', $templateTopicContent1, undef );
    $meta->save( user => $this->{test_user_wikiname} );
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'ViewtwoTemplate', $templateTopicContent2, undef );
    $meta->save( user => $this->{test_user_wikiname} );
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'ViewthreeTemplate', $templateTopicContent3, undef );
    $meta->save( user => $this->{test_user_wikiname} );
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'ViewfourTemplate', $templateTopicContent4, undef );
    $meta->save( user => $this->{test_user_wikiname} );
    $meta =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'ViewfiveTemplate', $templateTopicContent5, undef );
    $meta->save( user => $this->{test_user_wikiname} );

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
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_subweb}, $topic,
        'nested topci1 text', undef );
    $topicObject->save();

    #set up nested web _and_ topic called $this->{test_web}/ThisTopic
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'ThisTopic',
        'nested ThisTopic text', undef );
    $topicObject->save();
    $this->{test_clashingsubweb} = $this->{test_web} . '/ThisTopic';
    $topic = 'TestTopic1';

    try {
        $this->{session} = new Foswiki('AdminUser');

        my $webObject =
          Foswiki::Meta->new( $this->{session}, $this->{test_clashingsubweb} );
        $webObject->populateNewWeb();
        $this->assert(
            $this->{session}->webExists( $this->{test_clashingsubweb} ) );
        my $topicObject = Foswiki::Meta->new(
            $this->{session},
            $this->{test_clashingsubweb},
            $Foswiki::cfg{HomeTopicName}, "SMELL"
        );
        $topicObject->save();
        $this->assert(
            $this->{session}->topicExists(
                $this->{test_clashingsubweb},
                $Foswiki::cfg{HomeTopicName}
            )
        );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_clashingsubweb},
        $topic, 'nested topci1 text', undef );
    $topicObject->save();
}

sub setup_view {
    my ( $this, $web, $topic, $tmpl, $parm ) = @_;
    my $query = new Unit::Request(
        {
            webName   => [$web],
            topicName => [$topic],
            template  => [$tmpl],
        }
    );
    $query->path_info("/$web/$topic");
    $query->method('POST');
    $fatwilly = new Foswiki( $this->{test_user_login}, $query );
    my ($text) = $this->capture(
        sub {
            no strict 'refs';
            &$UI_FN($fatwilly);
            use strict 'refs';
            $Foswiki::engine->finalize( $fatwilly->{response},
                $fatwilly->{request} );
        }
    );

    $fatwilly->finish();
    $text =~ s/\r//g;
    $text =~ s/^.*?\n\n+//s;    # remove CGI header
    return $text;
}

sub setup_rawview {
    my ( $this, $web, $topic, $tmpl, $raw ) = @_;
    my $query = new Unit::Request(
        {
            webName   => [$web],
            topicName => [$topic],
            template  => [$tmpl],
            raw       => [$raw],
        }
    );
    $query->path_info("/$web/$topic");
    $query->method('POST');
    $fatwilly = new Foswiki( $this->{test_user_login}, $query );
    my ($text) = $this->capture(
        sub {
            no strict 'refs';
            &$UI_FN($fatwilly);
            use strict 'refs';
            $Foswiki::engine->finalize( $fatwilly->{response},
                $fatwilly->{request} );
        }
    );

    $fatwilly->finish();
    $text =~ s/\r//g;
    $text =~ s/(^.*?\n\n+)//s;    # remove CGI header
    return ($text, $1);
}

# This test verifies the rendering of the various raw views      
sub test_render_raw {
    my $this = shift;
    my $text;
    my $hdr;

    ($text, $hdr) = $this->setup_rawview( $this->{test_web}, 'TestTopic2', 'viewfour', 'text');
    $this->assert_equals( "$topic2", $text, "Unexpected output from raw=text"  );
    $this->assert_matches( qr#text/plain;#, $hdr, "raw=text should return text/plain - got $hdr");

    ($text, $hdr) = $this->setup_rawview( $this->{test_web}, 'TestTopic2', 'viewfour', 'all');
    $this->assert_matches( qr#$topic2meta$topic2#, $text, "Unexpected output from raw=all"  );
    $this->assert_matches( qr#text/plain;#, $hdr, "raw=all should return text/plain - got $hdr");

    ($text,$hdr) = $this->setup_rawview( $this->{test_web}, 'TestTopic2', 'viewfour', 'on');
    $this->assert_matches( qr#.*$topic2txtarea$topic2rawON.*#, $text, "Unexpected output from raw=on"  );
    $this->assert_matches( qr#text/html;#, $hdr, "raw=on should return text/html - got $hdr");

    ($text, $hdr) = $this->setup_rawview( $this->{test_web}, 'TestTopic2', 'viewfour', 'debug');
    $this->assert_matches( qr#.*$topic2txtarea$topic2metaQ$topic2rawON.*#, $text, "Unexpected output from raw=debug" );
    $this->assert_matches( qr#text/html;#, $hdr, "raw=debug should return text/html - got $hdr");
}

# This test verifies the handling of preamble (the text following
# %STARTTEXT%) and postamble (the text between %TEXT% and %ENDTEXT%).
sub test_prepostamble {
    my $this = shift;
    my $text;

    $text = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewone' );
    $text =~ s/\n+$//s;
    $this->assert_equals(
        'pretemplatepreCONTENT
postposttemplate', $text
    );

    $text = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewtwo' );
    $this->assert_equals(
        'pretemplateCONTENT
postposttemplate', $text
    );

    $text = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewthree' );
    $this->assert_equals( 'pretemplatepreCONTENTposttemplate', $text );

    $text = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewfour' );
    $this->assert_equals( 'pretemplateCONTENTposttemplate', $text );

    $text = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewfive' );
    $this->assert_equals( 'pretemplateposttemplate', $text );
}

sub urltest {
    my ( $this, $url, $web, $topic ) = @_;
    my $query = new Unit::Request( {} );
    $query->setUrl($url);
    $query->method('GET');
    my $fatwilly = new Foswiki( $this->{test_user_login}, $query );
    $this->assert_equals( $web,   $fatwilly->{webName} );
    $this->assert_equals( $topic, $fatwilly->{topicName} );

    $fatwilly->finish();
}

sub test_urlparsing {
    my $this = shift;

    $this->urltest( '',  $this->{users_web}, 'WebHome' );
    $this->urltest( '/', $this->{users_web}, 'WebHome' );

    #    $this->urltest('Sandbox', 'Sandbox', 'WebHome');
    $this->urltest( '/Sandbox',           'Sandbox',         'WebHome' );
    $this->urltest( '/Sandbox/',          'Sandbox',         'WebHome' );
    $this->urltest( '//Sandbox',          'Sandbox',         'WebHome' );
    $this->urltest( '///Sandbox',         'Sandbox',         'WebHome' );
    $this->urltest( '/Sandbox//',         'Sandbox',         'WebHome' );
    $this->urltest( '/Sandbox///',        'Sandbox',         'WebHome' );
    $this->urltest( '/Sandbox/WebHome',   'Sandbox',         'WebHome' );
    $this->urltest( '/Sandbox//WebHome',  'Sandbox',         'WebHome' );
    $this->urltest( '/Sandbox/WebHome/',  'Sandbox/WebHome', 'WebHome' );
    $this->urltest( '/Sandbox/WebHome//', 'Sandbox/WebHome', 'WebHome' );

    $this->urltest( '/Sandbox/WebIndex',    'Sandbox',          'WebIndex' );
    $this->urltest( '/Sandbox//WebIndex',   'Sandbox',          'WebIndex' );
    $this->urltest( '/Sandbox///WebIndex',  'Sandbox',          'WebIndex' );
    $this->urltest( '/Sandbox/WebIndex/',   'Sandbox/WebIndex', 'WebHome' );
    $this->urltest( '/Sandbox/WebIndex//',  'Sandbox/WebIndex', 'WebHome' );
    $this->urltest( '/Sandbox/WebIndex///', 'Sandbox/WebIndex', 'WebHome' );

    $this->urltest( '/Sandbox/WebIndex?asd=w',    'Sandbox', 'WebIndex' );
    $this->urltest( '/Sandbox//WebIndex?asd=qwe', 'Sandbox', 'WebIndex' );
    $this->urltest( '/Sandbox/WebIndex/?asd=qwe', 'Sandbox/WebIndex',
        'WebHome' );
    $this->urltest( '/Sandbox/WebIndex//?asd=ewr', 'Sandbox/WebIndex',
        'WebHome' );

    $this->urltest( '/Sandbox/WebIndex?topic=WebChanges',
        'Sandbox', 'WebChanges' );
    $this->urltest( '/Sandbox//WebIndex?topic=WebChanges',
        'Sandbox', 'WebChanges' );
    $this->urltest( '/Sandbox/WebIndex/?topic=WebChanges',
        'Sandbox/WebIndex', 'WebChanges' );
    $this->urltest( '/Sandbox/WebIndex//?topic=WebChanges',
        'Sandbox/WebIndex', 'WebChanges' );

    $this->urltest( '/Sandbox?topic=WebChanges',   'Sandbox', 'WebChanges' );
    $this->urltest( '/Sandbox/?topic=WebChanges',  'Sandbox', 'WebChanges' );
    $this->urltest( '/Sandbox//?topic=WebChanges', 'Sandbox', 'WebChanges' );

    $this->urltest( '/Sandbox/WebIndex?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest( '/Sandbox//WebIndex?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest( '/Sandbox/WebIndex/?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest( '/Sandbox/WebIndex//?topic=System.WebChanges',
        'System', 'WebChanges' );

    $this->urltest( '/Sandbox?topic=System.WebChanges', 'System',
        'WebChanges' );
    $this->urltest( '/Sandbox/?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest( '/Sandbox//?topic=System.WebChanges',
        'System', 'WebChanges' );

#nested
#    $this->urltest($this->{test_subweb}, $this->{test_subweb}, 'WebHome');
#    $this->urltest('/'.$this->{test_subweb}, $this->{test_subweb}, 'WebHome');
#    $this->urltest('/'.$this->{test_subweb}.'/', $this->{test_subweb}, 'WebHome');
#    $this->urltest('//'.$this->{test_subweb}, $this->{test_subweb}, 'WebHome');
#    $this->urltest('///'.$this->{test_subweb}, $this->{test_subweb}, 'WebHome');
#    $this->urltest('/'.$this->{test_subweb}.'$this->{test_subweb}//', $this->{test_subweb}, 'WebHome');
#    $this->urltest('/'.$this->{test_subweb}.'///', $this->{test_subweb}, 'WebHome');
    $this->urltest( '/' . $this->{test_subweb} . '/WebHome',
        $this->{test_subweb}, 'WebHome' );
    $this->urltest( '/' . $this->{test_subweb} . '//WebHome',
        $this->{test_subweb}, 'WebHome' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebHome/',
        $this->{test_subweb} . '/WebHome', 'WebHome' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebHome//',
        $this->{test_subweb} . '/WebHome', 'WebHome' );

    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex',
        $this->{test_subweb}, 'WebIndex' );
    $this->urltest( '/' . $this->{test_subweb} . '//WebIndex',
        $this->{test_subweb}, 'WebIndex' );
    $this->urltest( '/' . $this->{test_subweb} . '///WebIndex',
        $this->{test_subweb}, 'WebIndex' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex/',
        $this->{test_subweb} . '/WebIndex', 'WebHome' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex//',
        $this->{test_subweb} . '/WebIndex', 'WebHome' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex///',
        $this->{test_subweb} . '/WebIndex', 'WebHome' );

    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex?asd=w',
        $this->{test_subweb}, 'WebIndex' );
    $this->urltest( '/' . $this->{test_subweb} . '//WebIndex?asd=qwe',
        $this->{test_subweb}, 'WebIndex' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex/?asd=qwe',
        $this->{test_subweb} . '/WebIndex', 'WebHome' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex//?asd=ewr',
        $this->{test_subweb} . '/WebIndex', 'WebHome' );

    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex?topic=WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest( '/' . $this->{test_subweb} . '//WebIndex?topic=WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex/?topic=WebChanges',
        $this->{test_subweb} . '/WebIndex', 'WebChanges' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex//?topic=WebChanges',
        $this->{test_subweb} . '/WebIndex', 'WebChanges' );

#    $this->urltest('/'.$this->{test_subweb}.'?topic=WebChanges', $this->{test_subweb}, 'WebChanges');
#    $this->urltest('/'.$this->{test_subweb}.'/?topic=WebChanges', $this->{test_subweb}, 'WebChanges');
#    $this->urltest('/'.$this->{test_subweb}.'//?topic=WebChanges', $this->{test_subweb}, 'WebChanges');

    $this->urltest(
        '/' . $this->{test_subweb} . '/WebIndex?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest(
        '/' . $this->{test_subweb} . '//WebIndex?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest(
        '/' . $this->{test_subweb} . '/WebIndex/?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest(
        '/' . $this->{test_subweb} . '/WebIndex//?topic=System.WebChanges',
        'System', 'WebChanges' );

    $this->urltest( '/' . $this->{test_subweb} . '?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest( '/' . $this->{test_subweb} . '/?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest( '/' . $this->{test_subweb} . '//?topic=System.WebChanges',
        'System', 'WebChanges' );

    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '/WebIndex?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );
    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '//WebIndex?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );
    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '/WebIndex/?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );
    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '/WebIndex//?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );

    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );
    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '/?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );
    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '//?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );

    $this->urltest(
        '/System/WebIndex?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest(
        '/System//WebIndex?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest(
        '/System/WebIndex/?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest(
        '/System/WebIndex//?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );

    $this->urltest( '/System?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest( '/System/?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest( '/System//?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );

    #nonexistant webs
    #noneexistant topics (Item598)
    $this->urltest( '/Sandbox/ThisTopicShouldNotExist',
        'Sandbox', 'ThisTopicShouldNotExist' );
    $this->urltest(
        '/Sandbox/ThisTopicShouldNotExist/',
        'Sandbox/ThisTopicShouldNotExist',
        'WebHome'
    );

    $this->urltest( '/' . $this->{test_subweb} . '/ThisTopicShouldNotExist',
        $this->{test_subweb}, 'ThisTopicShouldNotExist' );
    $this->urltest( '/' . $this->{test_subweb} . '/ThisTopicShouldNotExist/',
        $this->{test_subweb} . '/ThisTopicShouldNotExist', 'WebHome' );

    #both topic and subweb of same name exists (Item598)
    #$this->{test_web}/ThisTopic is both a web and a topic
    $this->urltest( '/' . $this->{test_web} . '/ThisTopic',
        $this->{test_web}, 'ThisTopic' );    #the only way yo get to the topic
    $this->urltest( '/' . $this->{test_web} . '/ThisTopic/',
        $this->{test_web} . '/ThisTopic', 'WebHome' );
    $this->urltest( '/' . $this->{test_web} . '/ThisTopic/WebHome',
        $this->{test_web} . '/ThisTopic', 'WebHome' );
    $this->urltest( '/' . $this->{test_web} . '/ThisTopic/WebHome/',
        $this->{test_web} . '/ThisTopic/WebHome', 'WebHome' );

    #invalid..

    # - Invalid web name - Tasks.Item8713
    $this->urltest( '/A:B/WebPreferences',
        '', 'WebPreferences' );

}

1;
