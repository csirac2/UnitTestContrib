use strict;

package HTMLValidationTests;

#this has been quickly copied from the UICompilation tests
#TODO: need to pick a list of topics, actions, opps's and add detection of installed skins

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::UI::View;
use Error qw( :try );
use HTML::Tidy;

our $UI_FN;
our $SCRIPT_NAME;
our $SKIN_NAME;
our %expected_status = (
        search  => 302,
        save  => 302
);

#TODO: this is beause we're calling the UI::function, not UI:Execute - need to re-write it to use the full engine
our %expect_non_html = (
        rest  => 1,
        viewfile => 1,
        register => 1,       #TODO: missing action make it throw an exception
        manage => 1,       #TODO: missing action make it throw an exception
        upload => 1,         #TODO: zero size upload   
        resetpasswd => 1,
);


sub new {
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my $self = shift()->SUPER::new( "UIFnCompile", @_ );
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

#see http://tidy.sourceforge.net/docs/quickref.html for parameters - be warned that some cause HTML::Tidy to crash
    $this->{tidy} = HTML::Tidy->new(
        {

            #turn off warnings until we have fixed errors
            'show-warnings' => 1,

            #'accessibility-check'	=> 3,
            'drop-empty-paras' => 0
        }
    );

    #print STDERR "HTML::Tidy Version: ".$HTML::Tidy::VERSION."\n";
    #print STDERR "libtidy Version: ".HTML::Tidy::libtidy_version()."\n";

    $this->SUPER::set_up();
}

sub fixture_groups {
    my @scripts;

    foreach my $script ( keys( %{ $Foswiki::cfg{SwitchBoard} } ) ) {
        push( @scripts, $script );
        next if ( defined(&$script) );

        #print STDERR "defining sub $script()\n";
        my $dispatcher = $Foswiki::cfg{SwitchBoard}{$script};
        if ( ref($dispatcher) eq 'ARRAY' ) {

            # Old-style array entry in switchboard from a plugin
            my @array = @$dispatcher;
            $dispatcher = {
                package  => $array[0],
                function => $array[1],
                context  => $array[2],
            };
        }

        my $package  = $dispatcher->{package} || 'Foswiki::UI';
        my $function = $dispatcher->{function};
        my $sub      = $package . '::' . $function;

        #print STDERR "call $sub\n";

        eval <<SUB;
		sub $script {
			eval "require \$package" if (defined(\$package));
			\$UI_FN = \$sub;
	
			\$SCRIPT_NAME = \$script;
		}
SUB
        die $@ if $@;
    }

    my @skins;

    #TODO: detect installed skins..
    foreach my $skin (qw/default pattern plain print/) {
        push( @skins, $skin );
        next if ( defined(&$skin) );

        #print STDERR "defining sub $skin()\n";
        eval <<SUB;
		sub $skin {
			\$SKIN_NAME = \$skin;
		}
SUB
    }

    my @groups;
    push( @groups, \@scripts );
    push( @groups, \@skins );
    return @groups;
}

sub call_UI_FN {
    my ( $this, $web, $topic, $tmpl ) = @_;
    my $query = new Unit::Request(
        {
            webName   => [$web],
            topicName => [$topic],
   #            template  => [$tmpl],
   #debugenableplugins => 'TestFixturePlugin,SpreadSheetPlugin,InterwikiPlugin',
            skin => $SKIN_NAME
        }
    );
    $query->path_info("/$web/$topic");
    $query->method('GET');

#turn off ASSERTS so we get less plain text erroring - the user should always see html
    $ENV{FOSWIKI_ASSERTS} = 0;
    my $fatwilly = new Foswiki( $this->{test_user_login}, $query );
    my ($responseText, $result, $stdout, $stderr);
    $responseText = "Status: 500";      #errr, boom
    try {
		($responseText, $result, $stdout, $stderr) = $this->captureWithKey( switchboard =>
		    sub {
		        no strict 'refs';
		        &${UI_FN}($fatwilly);
		        use strict 'refs';
		        $Foswiki::engine->finalize( $fatwilly->{response},
		            $fatwilly->{request} );
		    }
		);
	} catch Foswiki::OopsException with {
		my $e = shift;
		$responseText = $e->stringify();
	} catch Foswiki::EngineException with {
		my $e = shift;
		$responseText = $e->stringify();
	};
    $fatwilly->finish();

    $this->assert($responseText);

    # Remove CGI header
    my $CRLF = "\015\012";    # "\r\n" is not portable
    my ($header, $body);
    if ($responseText =~ /^(.*?)$CRLF$CRLF(.*)$/s) {
        $header = $1;      # untaint is OK, it's a test
        $body = $2;
    } else {
        $header = '';
        $body = $responseText;
    }

    my $status = 666;
    if ($header =~ /Status: (\d*)./) {
        $status = $1;
    }
    #aparently we allow the web server to add a 200 status thus risking that an error situation is marked as 200
    #$this->assert_num_not_equals(666, $status, "no response Status set in probably valid reply\nHEADER: $header\n");
    if ($status == 666) {
        $status = 200;
    }
    $this->assert_num_not_equals(500, $status, 'exception thrown');

    return ($status, $header, $body, $stdout, $stderr);
}

#TODO: work out why some 'Use of uninitialised vars' don't crash the test (see preview)
#this verifies that the code called by default 'runs' with ASSERTs on
#which would have been enough to pick up Item2342
#and that the switchboard still works.
sub verify_switchboard_function {
    my $this = shift;

    my $testcase = 'HTMLValidation_' . $SCRIPT_NAME . '_' . $SKIN_NAME;

    my ( $status, $header, $text ) = $this->call_UI_FN( 'Main', 'WebHome' );    #$this->{test_web}, $this->{test_topic} );

    $this->assert_num_equals($expected_status{$SCRIPT_NAME} || 200, $status);
    if ($status != 302) {
        $this->assert($text, "no body for $SCRIPT_NAME\nSTATUS: $status\nHEADER: $header");
        $this->assert_str_not_equals('', $text, "no body for $SCRIPT_NAME\nHEADER: $header");
        $this->{tidy}->parse( $testcase, $text );

        #$this->assert_null($this->{tidy}->messages());
        my $output = join( "\n", $this->{tidy}->messages() );

        #TODO: disable missing DOCTYPE issues - we've been
        if ( defined($expect_non_html{$SCRIPT_NAME}) and ($output =~ /missing <\!DOCTYPE> declaration/) ) {

            #$this->expect_failure();
            $this->annotate(
                "MISSING DOCTYPE - we're returning a messy text error\n$output\n");
        }
        else {
            for ($output) {    # Remove OK warnings
                               # Empty title, no easy fix and harmless
s/^$testcase \(\d+:\d+\) Warning: trimming empty <(?:h1|span)>\n?$//gm;
                s/^\s*$//;
            }
            my $outfile = "${testcase}_run.html";
            if ( $output eq '' ) {
                unlink $outfile;    # Remove stale output file
            }
            else {                  # save the output html..
                open( my $fh, '>', $outfile ) or die "Can't open $outfile: $!";
                print $fh $text;
                close $fh;
            }
            $this->assert_equals( '', $output,
"Script $SCRIPT_NAME, skin $SKIN_NAME gave errors, output in $outfile:\n$output"
            );
        }
    } else {
        #$this->assert_null($text);
    }

    #clean up messages for next run..
    $this->{tidy}->clear_messages();
}

1;
