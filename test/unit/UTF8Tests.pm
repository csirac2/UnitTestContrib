package UTF8Tests;
use strict;
use warnings;

# TODO: Exercise
# $Foswiki::cfg{Site}{CharSet}
# $Foswiki::cfg{UseLocale}
# $Foswiki::cfg{Site}{Locale}
# $Foswiki::cfg{Site}{Lang}
# $Foswiki::cfg{Site}{FullLang}
# $Foswiki::cfg{Site}{LocaleRegexes}
# to provide coverage of all the options (bearing in mind that you are going
# to have to work out how to re-initialise Foswiki for each test)
use utf8;
use warnings qw( FATAL utf8 );
use charnames qw( :full :short );

use FoswikiSeleniumTestCase;
our @ISA = qw( FoswikiSeleniumTestCase );

use Foswiki();
use Encode();
use Data::Dumper;

if ( $^V >= 5.12 ) {

    require feature;
    feature->import('unicode_strings');
}


my %loggedin;
# Charsets, with a few representative sample words (in lower-case) for that
# charset. On the latin charsets, tried to choose words which began and ended
# with non-ascii chars, to try to exercise wikiword regex/logic
#
# These are of course stored in the source code here in utf8.
my %utf8words = (

# ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿ
    'iso-8859-1' => {
        'wiki'     => { desc => 'wiki' },
        'âcreté' => { desc => 'french cf. acrete' },
        'çà'     => { desc => 'french cf. ca' }
    },

# Ą˘Ł¤ĽŚ§¨ŠŞŤŹŽŻ°ą˛ł´ľśˇ¸šşťź˝žżŔÁÂĂÄĹĆÇČÉĘËĚÍÎĎĐŃŇÓÔŐÖ×ŘŮÚŰÜÝŢßŕá
# âăäĺćçčéęëěíîďđńňóôőö÷řůúűüýţ˙
    'iso-8859-2' => {
        'wiki'     => { desc => 'wiki' },
        'überaß' => { desc => 'german cf. uberaS' },
        'łódż'  => { desc => 'polish cf. lodz' }
    },

# ‘’£€₯¦§¨©ͺ«¬―°±²³΄΅Ά·ΈΉΊ»Ό½ΎΏΐΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΤΥΦΧΨΩΪΫάέήίΰαβγδ
# εζηθικλμνξοπρςστυφχψωϊϋόύώ
    'iso-8859-7' => {
        'wiki'           => { desc => 'wiki' },
        'φάω'         => { desc => 'greek cf. yaw' },
        'πράσινο' => { desc => 'greek cf. npaolvo' }
    },

# ЂЃ‚ѓ„…†‡€‰Љ‹ЊЌЋЏђ‘’“”•–—™љ›њќћџЎўЈ¤Ґ¦§Ё©Є«¬HY®Ї°±Ііґµ¶·ё№є»јЅѕїА
# ВБГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюя
    'cp-1251' => {
        'wiki'             => { desc => 'wiki' },
        'зеленый'   => { desc => 'russian cf. 3enehbN' },
        'вертолет' => { desc => 'russian cf. beptonet' }
    },

    'utf-8' => {
        'wiki' => { desc => 'wiki' },
        'â日本語é' =>
          { desc => 'â-(\'Japanese language\' [3 chars Japanese kanji])-é' },
        'çमानक हिन्दीà' => {
            desc =>
'ç-(\'Standard Hindi\' [Devanagari script, 3 chars, space, 3 chars])-à'
        }
    },
);

my @charsets = keys %utf8words;

# Some characters of interest, and their ordinal value in various charsets.
# iso-8859-1: Latin-1, Default Foswiki charset
# iso-8859-2: Latin/"Eastern European" (including German)
# iso-8859-7: Latin/Greek
# cp-1251: Cyrillic (MS-Windows encoding for Russian, Ukraine etc.)
# utf-8: everything including klingon! One utf-8-only char from Japanese kanji,
#   another from Devangari (Hindi) script. Remainder representable in iso-8859-*
my %chars = (
    '£' => {
        unicode      => 0x00A3,
        desc         => 'Currency pound',
        'iso-8859-1' => 163,
        'iso-8859-7' => 163,
        'utf-8'      => 0xc2a3
    },
    'Ł' => {
        unicode      => 0x0141,
        desc         => 'L-stroke',
        'iso-8859-2' => 163,
        'utf-8'      => 0xc581
    },
    'Ј' => {
        unicode   => 0x0408,
        desc      => 'Je (cyrillic J)',
        'cp-1251' => 163,
        'utf-8'   => 0xd088
    },
    '¥' => {
        unicode      => 0x00A5,
        desc         => 'Currency yen',
        'iso-8859-1' => 165,
        'utf-8'      => 0xc2a5
    },
    'Ľ' => {
        unicode      => 0x013D,
        desc         => 'L-caron',
        'iso-8859-2' => 165,
        'utf-8'      => 0xc4bd
    },
    'Š' => {
        unicode      => 0x0160,
        desc         => 'S-caron',
        'iso-8859-2' => 169,
        'utf-8'      => 0xc5a0
    },
    '©' => {
        unicode      => 0x00A9,
        desc         => '(c)',
        'cp-1251'    => 169,
        'iso-8859-1' => 169,
        'iso-8859-7' => 169,
        'utf-8'      => 0xc2a9
    },
    '®' => {
        unicode      => 0x00AE,
        desc         => '(r)',
        'iso-8859-1' => 174,
        'utf-8'      => 0xc2ae
    },
    '°' => {
        unicode      => 0x00B0,
        desc         => 'Degree symbol',
        'cp-1251'    => 176,
        'iso-8859-1' => 176,
        'iso-8859-2' => 176,
        'iso-8859-7' => 176,
        'utf-8'      => 0xc2b0
    },
    '±' => {
        unicode      => 0x00B1,
        desc         => 'Plus/minus',
        'cp-1251'    => 177,
        'iso-8859-1' => 177,
        'iso-8859-7' => 177,
        'utf-8'      => 0xc2b1
    },
    'µ' => {
        unicode      => 0x00B5,
        desc         => 'Micro',
        'cp-1251'    => 181,
        'iso-8859-1' => 181,
        'utf-8'      => 0xc2b5
    },
    'μ' => {
        unicode      => 0x03BC,
        desc         => 'Mu',
        'iso-8859-7' => 236,
        'utf-8'      => 0xcebc
    },
    '½' => {
        unicode      => 0x00BD,
        desc         => 'One half',
        'iso-8859-1' => 189,
        'iso-8859-7' => 189,
        'utf-8'      => 0xc2bd
    },
    'Ѕ' => {
        unicode   => 0x0405,
        desc      => 'Dze (cyrillic S)',
        'cp-1251' => 189,
        'utf-8'   => 0xd085
    },
    'Γ' => {
        unicode      => 0x0393,
        desc         => 'Gamma',
        'iso-8859-7' => 195,
        'utf-8'      => 0xce93
    },
    'Г' => {
        unicode   => 0x0413,
        desc      => 'Ghe (cyrillic Gamma)',
        'cp-1251' => 195,
        'utf-8'   => 0xd093
    },
    'é' => {
        unicode      => 0x00E9,
        desc         => 'e-acute',
        'iso-8859-1' => 233,
        'iso-8859-2' => 233,
        'utf-8'      => 0xc3a9
    },
    'й' => {
        unicode   => 0x0439,
        desc      => 'yot (cyrillic, cf. N-caron)',
        'cp-1251' => 233,
        'utf-8'   => 0xd0b9
    },
    'ö' => {
        unicode      => 0x00F6,
        desc         => 'o-umlaut',
        'iso-8859-1' => 246,
        'iso-8859-2' => 246,
        'utf-8'      => 0xc3b6
    },
    'ц' => {
        unicode   => 0x0446,
        desc      => 'Tse (cyrillic, cf. u)',
        'cp-1251' => 246,
        'utf-8'   => 0xd186
    },
    '÷' => {
        unicode      => 0x00F7,
        desc         => 'Division',
        'iso-8859-1' => 247,
        'iso-8859-2' => 247,
        'utf-8'      => 0xc3b7
    },
    'φ' => {
        unicode      => 0x03C6,
        desc         => 'phi',
        'iso-8859-7' => 246,
        'utf-8'      => 0xcf86
    },
    'Χ' => {
        unicode      => 0x03A7,
        desc         => 'Chi',
        'iso-8859-7' => 215,
        'utf-8'      => 0xcea7
    },
    'Я' => {
        unicode   => 0x042F,
        desc      => 'Ya (cyrillic, cf. reverse R)',
        'cp-1251' => 223,
        'utf-8'   => 0xd0af
    },
    'щ' => {
        unicode   => 0x0449,
        desc      => 'Shcha (cyrillic, cf. W)',
        'cp-1251' => 249,
        'utf-8'   => 0xd189
    },
    'ü' => {
        unicode      => 0x00FC,
        desc         => 'u-umlaut',
        'iso-8859-1' => 252,
        'iso-8859-2' => 252,
        'utf-8'      => 0xc3bc
    },
    'ώ' => {
        unicode      => 0x03CE,
        desc         => 'omega-acute',
        'iso-8859-7' => 254,
        'utf-8'      => 0xcf8e
    },
    '日' => {
        unicode => 0x65E5,
        desc    => 'CJK unified ideograph (Kanji cf... square w/horiz. line :)',
        'utf-8' => 0xe697a5
    },
    'क' => {
        unicode => 0x0915,
        desc    => 'Devanagari letter ka (cf... T w/squiggles :)',
        'utf-8' => 0xe0a495
    },
    '–' => {
        unicode => 0x2013,
        desc    => 'En dash (cf. -, but longer)',
        'utf-8' => 0xe28093
    },
    '—' => {
        unicode => 0x2014,
        desc    => 'Em dash (cf. -, but much longer)',
        'utf-8' => 0xe28094
    },
    '♀' => {
        unicode => 0x2640,
        desc    => 'Female sign',
        'utf-8' => 0xe29980
    }
);

sub test_chars_sanity {
    my ($this) = @_;

    while ( my ( $char, $meta ) = each %chars ) {
        my %charsets    = %{$meta};
        my $unicode     = $charsets{unicode};
        my $unicodechar = chr($unicode);
        my $desc        = $charsets{desc};

        $this->assert_equals( $char, $unicodechar,
            "Unicode point for '$char' ($desc) incorrect (got: '$unicodechar')"
        );
        while ( my ( $charset, $value ) = each %charsets ) {
            if ( $charset ne 'desc' and $charset ne 'unicode' ) {

               # SMELL: This is a really, really round about way... but ord() is
               # not suitable for vector values like UTF-8 octets
                my $ordencchar =
                  eval
                  sprintf( '0x%*vX', '', Encode::encode( $charset, $char ) );

                $this->assert_equals( $ordencchar, $value,
"'$charset' => $value incorrect for '$char' (got $ordencchar)"
                );
            }
        }
    }

    return;
}

sub _gen_test_topic_name {
    my ($this) = @_;

    return join( '_', values %{$this->{fixfuncs}} );
}

sub _gen_text_for_charset {
    my ( $this, $charset ) = @_;
    my $text = "---++ Scenario\n";
    my @fixgroups = keys %{$this->{fixfuncs}};
    my @fixtures;

    $this->assert($charset);
    $this->assert($charset eq $this->{fixfuncs}{charset}, "Expected $charset but fixfunc was $this->{fixfuncs}{charset}");
    foreach my $group (@fixgroups) {
        if (not $group =~ /_fn$/) {
            $text .= "   * $group: =$this->{fixfuncs}{$group}=\n";
        }
    }
    $text .= <<"HERE";

---++ Chars
| *Native* | *HTML* | *Unicode* | *$charset* | *Desc* |
HERE

    while ( my ( $char, $meta ) = each %chars ) {
        if ( exists $meta->{$charset} ) {
            $text .=
              "| $char | &#$meta->{unicode}; | U+" . uc( $meta->{unicode} ) . " | " . sprintf( '0x%X', $meta->{$charset}) . " | $meta->{desc} |\n";
        }
    }
    $this->assert( exists $utf8words{$charset}, Dumper(\%utf8words) );
    $text .= <<"HERE";

---++ Words
| *Native* | *HTML* | *Desc* |
HERE
    while ( my ( $word, $meta ) = each %{ $utf8words{$charset} } ) {
        my $html = $word;

        $html =~ s/(.)/'&#' . ord($1) . ';'/ge;
        $text .= "| $word | $html | $meta->{desc} |\n";
    }

    return $text;
}

sub set_up {
    my ($this, $test, %args) = @_;
    my $query;
    my $testTopicName = $this->{test_topic};

    $this->{test_topic} = $testTopicName;
    if ($args{from_test}) {
        $this->{FoswikiCfg} = undef;
    } else {
        $this->SUPER::set_up();
        $this->{test_topic} = $testTopicName;
    }
    $query = Unit::Request->new("");
    $query->path_info( "/$this->{test_web}/" . $testTopicName );

    $this->{session}  = Foswiki->new( undef, $query );
    $this->{request}  = $query;
    $this->{response} = Unit::Response->new();

    $this->{test_topicObject} =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, $testTopicName,
        'empty');
}

sub tear_down {
    my ($this) = @_;

    $this->SUPER::tear_down();
    $this->{FoswikiCfg} = undef;

    return;
}

sub fixture_groups {
    my ( $this, $suite ) = @_;

    return (
        $this->SUPER::fixture_groups(),
        [ $this->fixgroup_foswikis() ],
        [ $this->fixgroup_charsets() ]
    );
}

sub _set_config {
    my ($this, $config) = @_;
    my %FoswikiCfg;
    
    if (not $this->{FoswikiCfg}) {
        $this->{FoswikiCfg} = {};
    }
    $this->assert(ref($this->{FoswikiCfg}) eq 'HASH', ref($this->{FoswikiCfg}));
    %FoswikiCfg = (%{$this->{FoswikiCfg}}, %{$config});
    $this->{FoswikiCfg} = \%FoswikiCfg;

    return;
}

sub _mangle_server_config {
    my ($this, $cfg) = @_;

    return;
}

sub _apply_config {
    my ($this) = @_;
    my $done;

    if ($this->_cfgeq($this->{FoswikiCfg}, \%Foswiki::cfg)) {
        # Foswiki config already matches desired config for the test
        $done = 1;
    } else {
        my $can_mangle = $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{MangleLocalSiteCfg};

        if ($can_mangle) {
            if (not exists $this->{OrigFoswikiCfg}) {
                # Backup the config
                %{$this->{OrigFoswikiCfg}} = %Foswiki::cfg;
            } else {
                $this->assert($Foswiki::cfg{Site}{CharSet});
            }
            # Mangle our Foswiki::cfg for this process.. not sure it's useful
            $this->assert($this->{OrigFoswikiCfg}{Site}{CharSet});
            %Foswiki::cfg = (%{$this->{OrigFoswikiCfg}}, %{$this->{FoswikiCfg}});
            # Selenium accesses the webserver, not this Unit::Request thing...
            $this->_mangle_server_config(\%Foswiki::cfg);
            $this->_reload_webserver();
        } else {
            $this->expect_failure();
        }
        $this->assert($can_mangle, <<"HERE");
\$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{MangleLocalSiteCfg} not set, so
could't apply config for this test which $this->{_cfgeq_msg}
HERE
    }

    return $done;
}

sub _cfgeq {
    my ($this, $partcfg, $cfg) = @_;
    my $partref = ref($partcfg);
    my $eq = 1;

    if ($partref) {
        while (my ($key, $value) = each %{$partcfg}) {
            if ($eq) {
                $eq = $this->_cfgeq($partcfg->{$key}, $cfg->{$key});
            }
        }
    } else {
        $this->assert(ref($cfg) eq $partref);
        if ((defined $partcfg and defined $cfg or not (defined $partcfg or defined $cfg)) and $cfg eq $partcfg) {
            $eq = 1;
        } else {
            $eq = 0;
            $this->{_cfgeq_msg} = "wanted '$partcfg' but Foswiki::cfg had '$cfg'"
        }
    }

    return $eq;
}

sub fixgroup_charsets {
    my ($this) = @_;
    my @groups;

    foreach my $charset (@charsets) {
        my $fn = 'SiteCharSet_' . $charset;

        $fn =~ s/-/_/g;
        push( @groups, $fn );
        no strict 'refs';
        *{$fn} = sub {
            $this->{fixfuncs}{charset_fn} = $fn;
            $this->{fixfuncs}{charset} = $charset;
            $this->_set_config({Site => {CharSet => $charset}});
        };
        use strict 'refs';
    }

    return @groups;
}

sub fixgroup_foswikis {
    my ($this) = @_;
    my @groups;
    my $foswikis = $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Foswikis};

    if ( not( defined $foswikis and scalar( keys( %{$foswikis} ) ) ) ) {
        $foswikis = {};
    }
    if (
        not( defined $foswikis->{default}
            and scalar( keys( %{ $foswikis->{default} } ) ) )
      )
    {
        $foswikis->{default} = {};
        foreach my $key (
            qw(DefaultUrlHost PermittedRedirectHostUrls ScriptUrlPath ScriptUrlPaths PubUrlPath)
          )
        {
            $foswikis->{default}->{$key} = $Foswiki::cfg{$key};
        }
    }
    foreach my $foswiki ( keys %{$foswikis} ) {
        my $fn = "Foswiki_$foswiki";

        push( @groups, $fn );
        no strict 'refs';
        *{$fn} = sub {
            $this->{fixfuncs}{foswiki_fn} = $fn;
            $this->{fixfuncs}{foswiki} = $foswiki;
            $this->_set_config($foswikis->{$foswiki});
        };
        use strict 'refs';
    }

    return @groups;
}

# Avoid Error 414 Request URI Too large. Inspired by
# http://groups.google.com/group/selenium-users/msg/669560194d07734e
sub _type_lots {
    my ($this, $Locator, $Value) = @_;
    my $MaxChars = 1000;
    my $ValLen = length $Value;
    if ($ValLen > $MaxChars) {
        my $Pos = 0;
        $Locator =~ s/\"/\\\"/g;
        while ($Pos < $ValLen) {
            my $Chunk = substr($Value, $Pos, $MaxChars);
            $Chunk =~ s/\"/\\\"/g;
            $Chunk =~ s/\n/\\n/g;
            $Pos += $MaxChars;
            my $JSCall = 'selenium.browserbot.findElement("' . $Locator . '").value += "' . $Chunk . '";';
            $this->selenium->do_command("getEval", $JSCall);
            $this->selenium->pause(200);
        }
    }
    else {
        $this->selenium->type($Locator, $Value);
    }

    return;
}

sub _ensureLoggedIn {
    my ($this) = @_;
    my $foswiki = $this->{fixfuncs}{foswiki};

    $this->assert($foswiki);
    if (not exists $loggedin{$foswiki}) {
        $this->assert(not $loggedin{$foswiki});
        $this->login();
        $loggedin{$foswiki} = 1;
    }

    return;
}

sub _count {
    my ($this) = @_;

    $this->{count} = ($this->{count} || 0) + 1;

    return $this->{count};
}

sub verify_text_inrange_roundtrip {
    my ($this) = @_;
    my $timeout = 5000;
    my $expected;
    my $topicObj;

    $this->_apply_config();
    $this->set_up(from_test => 1);
    $expected = $this->_gen_text_for_charset( $Foswiki::cfg{Site}{CharSet} );
    $this->_ensureLoggedIn();
    $this->selenium->open_ok(
        Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic},
            'edit' )
          . '?nowysiwyg=1;t='
          . time() . $this->_count()
    );
    $this->selenium->wait_for_page_to_load($timeout);
    $this->_type_lots( 'id=topic', $expected);
    $this->selenium->pause(200);
    $this->selenium->click('id=save');
    $this->selenium->wait_for_page_to_load($timeout);
    ($topicObj) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->assert_equals( $expected, $topicObj->text() );

    return;
}

sub DISABLEtest_urlEncodeDecode {
    my $this = shift;
    my $s    = '';
    my $t    = '';

    for ( my $i = 0 ; $i < 256 ; $i++ ) {
        $s .= chr($i);
    }
    $t = Foswiki::urlEncode($s);
    $this->assert( $s eq Foswiki::urlDecode($t) );

    $s = Foswiki::urlDecode('%u7FFF%uA1EE');
    $this->assert_equals( chr(0x7FFF) . chr(0xA1EE), $s );

    $s = Foswiki::urlDecode('%ACTION{}%');
    $this->assert_equals( chr(0xAC) . 'TION{}%', $s );
}

sub test_segfault1 {
    my $this = shift;
    my $s    = <<'EOS';
---+!! %TOPIC%

i spoke with Spum Garbo on IRC today (transcript enclosed).  it didn't start out as a long chat, but evolved into one.  

in the short term, 


<verbatim>
*** Logfile started
*** on Thu Mar 16 14:05:04 2006

zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz?
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zz zz TODO zzzz
[Tzz Mzz 16 2006] [14:42:10] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zzzz zzzzzz :)
[Tzz Mzz 16 2006] [14:42:31] *RzzRzzzzz*    zzz zzzzz zzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:42:44] *zzzzz*zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
[Tzz Mzz 16 2006] [14:42:55] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:43:01] *RzzRzzzzz*    zzzzzzzzzzz zzzzzz
[Tzz Mzz 16 2006] [14:43:03] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zzzzzz
[Tzz Mzz 16 2006] [14:43:39] *zzzzz*    zzzzz zzz
[Tzz Mzz 16 2006] [14:44:02] *zzzzz*    zz zzzzz zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:44:18] *zzzzz*    zzzzzz z zzzzz zzzzz
[Tzz Mzz 16 2006] [14:44:25] *RzzRzzzzz*    zzz zzz zz zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:44:35] *zzzzz*    zzz
[Tzz Mzz 16 2006] [14:44:53] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:45:21] *zzzzz*    (zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [14:45:39] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:45:46] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:45:52] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [14:46:09] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz, zzz), zzz, zzz, zzz
[Tzz Mzz 16 2006] [14:46:24] *zzzzz*    z zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:46:33] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:46:58] *zzzzz*    (zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz...)
[Tzz Mzz 16 2006] [14:47:05] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:48:01] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
[Tzz Mzz 16 2006] [14:48:09] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:48:15] *zzzzz*    zz zzzzzzzz
[Tzz Mzz 16 2006] [14:48:23] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz?
[Tzz Mzz 16 2006] [14:49:01] *zzzzz*    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;z
[Tzz Mzz 16 2006] [14:49:06] *RzzRzzzzz*    zz''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''zzz
[Tzz Mzz 16 2006] [14:49:20] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz?
[Tzz Mzz 16 2006] [14:49:21] *RzzRzzzzz*    z00000000000000000000000000000000000000000000000000000000000000000000000000000000000zz
[Tzz Mzz 16 2006] [14:49:28] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:49:32] *RzzRzzzzz*    zzzzzzzzz zzzz zzzzzzz
[Tzz Mzz 16 2006] [14:49:41] *zzzzz*    zzzzzzzzzz?
[Tzz Mzz 16 2006] [14:49:43] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:49:51] *RzzRzzzzz*    zzzzzzzz zzzz
[Tzz Mzz 16 2006] [14:49:53] *zzzzz*    zz
[Tzz Mzz 16 2006] [14:50:02] *zzzzz*    zzzzzzzzzzzzzzzzzzz6666666666666666zz
[Tzz Mzz 16 2006] [14:50:05] *RzzRzzzzz*    z666666666666666666666666666666666666666666666666z zzz zz zz
[Tzz Mzz 16 2006] [14:50:09] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz" :)
[Tzz Mzz 16 2006] [14:50:16] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:50:27] *zzzzz*    1333333333333333333333333333333333333333333333333333333333zzzz
[Tzz Mzz 16 2006] [14:50:34] *zzzzz*    2zzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:50:59] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:51:06] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:51:10] *zzzzz*    z2222222222222zz 
[Tzz Mzz 16 2006] [14:51:15] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:51:17] *zzzzz*    zzzz
[Tzz Mzz 16 2006] [14:51:25] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:51:38] *zzzzz*    (zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [14:51:58] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:52:31] *zzzzz*    (z66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666zzz
[Tzz Mzz 16 2006] [14:52:36] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:52:47] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:53:01] *zzzzz*    88888888888888888888888888888888888888888888888888888888zzzz
[Tzz Mzz 16 2006] [14:53:09] *zzzzz*    z666666666666666666666666666666666666zz
[Tzz Mzz 16 2006] [14:53:17] *RzzRzzzzz*    :)
[Tzz Mzz 16 2006] [14:53:34] *RzzRzzzzz*    z6666666666666666666666666666666666666666666666666666666zz :)
[Tzz Mzz 16 2006] [14:53:43] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz),
[Tzz Mzz 16 2006] [14:54:13] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:54:21] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:54:27] *RzzRzzzzz*    zzzz
[Tzz Mzz 16 2006] [14:54:30] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:54:45] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:54:57] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:55:10] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz?
[Tzz Mzz 16 2006] [14:55:34] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz...
[Tzz Mzz 16 2006] [14:55:43] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:55:47] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzz :)
[Tzz Mzz 16 2006] [14:55:58] *zzzzz*    zzzzzz = zzzzzzz
[Tzz Mzz 16 2006] [14:56:11] *RzzRzzzzz*    zzz
[Tzz Mzz 16 2006] [14:56:16] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:56:23] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz :)
[Tzz Mzz 16 2006] [14:56:38] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:56:49] *zzzzz*    zzzzzzzzzz!
[Tzz Mzz 16 2006] [14:56:57] *zzzzz*    zzz zzzzzzzzzzzzzzzzzzzzzzzzzzzzz ;-(
[Tzz Mzz 16 2006] [14:57:15] *RzzRzzzzz*    zzz zz zzz zzzz zzzzzzzzzzzzzzzzzzzzzz?
[Tzz Mzz 16 2006] [14:57:19] *zzzzz*    HORRIBLE
[Tzz Mzz 16 2006] [14:57:31] *RzzRzzzzz*    z zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:57:33] *zzzzz*    zz zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'z zzzzz zz zzzzzzz
[Tzz Mzz 16 2006] [14:57:41] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zzzzzz
[Tzz Mzz 16 2006] [14:57:47] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:57:56] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zzzzz
[Tzz Mzz 16 2006] [14:58:08] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [14:58:12] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzz :)
[Tzz Mzz 16 2006] [14:58:17] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:58:31] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:58:35] *zzzzz*    (zzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [14:58:50] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:58:53] *zzzzz*    zzzzz, zzzz
[Tzz Mzz 16 2006] [14:59:08] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:59:24] *zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz :)
[Tzz Mzz 16 2006] [14:59:26] *zzzzz*    zzzz, zzzzzz
[Tzz Mzz 16 2006] [14:59:31] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzD
[Tzz Mzz 16 2006] [14:59:44] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [14:59:58] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:00:02] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:00:09] *RzzRzzzzz*    zzzz
[Tzz Mzz 16 2006] [15:00:21] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:01:47] *RzzRzzzzz*    zz55554zzzzzzzzzzzzz3zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:02:00] *RzzRzzzzz*    zzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:03:26] *RzzRzzzzz*    zzz zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:03:41] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:07:10] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
[Tzz Mzz 16 2006] [15:07:21] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zzzz 
[Tzz Mzz 16 2006] [15:07:23] *zzzzz*    zzzzzzzzzz
[Tzz Mzz 16 2006] [15:07:31] *RzzRzzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zzz
[Tzz Mzz 16 2006] [15:07:38] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [15:07:40] *RzzRzzzzz*    z zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zz
[Tzz Mzz 16 2006] [15:07:48] *zzzzz*    z zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:07:56] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:08:08] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz :)
[Tzz Mzz 16 2006] [15:08:26] *zzzzz*    zzzzzzzzzzzzzzzzzzzzz zz zzz
[Tzz Mzz 16 2006] [15:08:46] *zzzzz*    zz zzzzzzzzz zzzz z zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz zz
[Tzz Mzz 16 2006] [15:09:00] *zzzzz*    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:09:08] *zzzzz*    zzzz z zzzz zzzzzz
[Tzz Mzz 16 2006] [15:09:25] *zzzzz*    zzz z zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [15:09:32] *zzzzz*    zzzz zzz zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:10:01] *zzzzz*    (zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz)
[Tzz Mzz 16 2006] [15:10:04] *RzzRzzzzz*    zzzz zzzz, zzzz z zzz zzz zzzzzzzzz z zzz zzzzz, zzz z'z zzzzzzzzz zz zzzzzzzzzz zzzzzzz
[Tzz Mzz 16 2006] [15:10:59] *zzzzz*    zzzzzzz zz zz zzzzz zzzzzzz zzzz zzzzz z zzz zzzzzzzzzzz zzz zzz zzzzzzz zzzzz zzzzz zzzzzzz zzz zzzzzzz zzzz zzz zzzzzzzzz
[Tzz Mzz 16 2006] [15:11:05] *RzzRzzzzz*    zzz zz zzz zzz zzz zz zz z zzzzzz zzzzzzz zzzzzzz, z zzzzz z zzzzzzzzzz zzzzzzz zzzzz zz z zzz zzzz zzzzzzzzzzz
[Tzz Mzz 16 2006] [15:11:09] *zzzzz*    zz zzz zz zzzzzzzz zzzzzzz, zzzz zzzzzzz 
[Tzz Mzz 16 2006] [15:11:22] *RzzRzzzzz*    zzzzzzz = PXE?
[Tzz Mzz 16 2006] [15:11:32] *zzzzz*    PXE zz zzzzzz, zzz
[Tzz Mzz 16 2006] [15:11:37] *zzzzz*    zzzzz zz zzzzzz
[Tzz Mzz 16 2006] [15:11:58] *RzzRzzzzz*    zzz.. zzz zzzz zzzzzzz zzzz zzzzz zzzz zzzz zz zzzzzzzz zzz z zzzzzz zzzz
[Tzz Mzz 16 2006] [15:12:08] *RzzRzzzzz*    zzzzz zzz
[Tzz Mzz 16 2006] [15:12:22] *zzzzz*    zz, zzz zzzz zzzzzzz zzz zzzzz zzzz zzz zzzzzzzz zzz, zz zzzzz zzzz zzzz zzz "zzzzzzz zzzzzz", zzzzz zzzzz zzzzzzz zzz zzzzzzz zzzz zzz zzz zzz zzzz zzz zzzzzzz86 zzz zz zzzz zz zzzz zzzzzz zz "zzzz zz" zzz zzzzzzz
[Tzz Mzz 16 2006] [15:12:38] *zzzzz*    zz zzz zzzzzz zzzzz, zz z zz zzz zz zzzzzz ;-)
[Tzz Mzz 16 2006] [15:12:48] *RzzRzzzzz*    zzzzzz zzzzzz zzzz
[Tzz Mzz 16 2006] [15:13:20] *zzzzz*    zzzz, z'z z zzzz, z zzzzzzzz zzzzzz zzzz zzzz zzz :)
[Tzz Mzz 16 2006] [15:13:27] *RzzRzzzzz*    zz zzz
[Tzz Mzz 16 2006] [15:13:31] *zzzzz*    :)
[Tzz Mzz 16 2006] [15:13:53] *RzzRzzzzz*    zz zzz zzzz zzzz zzzzzzzz zz zzzzz zzzz zzz'zz zzzz?
[Tzz Mzz 16 2006] [15:14:25] *zzzzz*    zzz zzzzzzzzzz zzzzz z zzzzzzzzzz zzzz zz zzzzz (zz z zz, zzzzzzzzz zzzzzzz) zz zzz (zz) zzzzzzz zzzzzzzzzzz
[Tzz Mzz 16 2006] [15:14:34] *zzzzz*    zzz zzz ;-) ?
[Tzz Mzz 16 2006] [15:14:37] *zzzzz*    zzz zzzzzzzzz,
[Tzz Mzz 16 2006] [15:14:59] *zzzzz*    z'zz zzzzzz zzzz zzzz zzzzzzz zzzz zz zzzzz
[Tzz Mzz 16 2006] [15:15:03] *zzzzz*    (zzzzzzz zz zzz zzzz zzzz zz zz)
[Tzz Mzz 16 2006] [15:15:05] *zzzzz*    zzz
[Tzz Mzz 16 2006] [15:15:40] *zzzzz*    z'z zzz zzzzzzzzzz zzz TWzzzIzzzzzzzzCzzzzzz zzz TWzzzPzzzzzIzzzzzzzzCzzzzzz
[Tzz Mzz 16 2006] [15:15:56] *zzzzz*    z'zz zzz zzzz zzzzzz "zzzzzzzz" zzzzz zzzz, zzzzzz zzzzzzz zzz zzz zzzzzzz
[Tzz Mzz 16 2006] [15:15:58] *RzzRzzzzz*    z, zzzzz zzzz zz 2 zzzz zzzzzzzzz zzzzzzzz zz zzzz zzzzzzz
[Tzz Mzz 16 2006] [15:16:13] *RzzRzzzzz*    zzzzzzz zzz zzzzzzzzz zzzz zzzz z zzzz zzzzzz zzzzzzzzz zz zzzzzzz zzzzzzz
[Tzz Mzz 16 2006] [15:16:16] *zzzzz*    z zzz zzz zzzzzzzz z zzzz zzzzzzzz zzzz zzz zzz zzzz zzzzzzz, zzz
[Tzz Mzz 16 2006] [15:16:20] *RzzRzzzzz*    zzz zzzzzz zzzzzzz zzz zzz zzz
[Tzz Mzz 16 2006] [15:16:21] *zzzzz*    (zzz zzzzz, zzz)
[Tzz Mzz 16 2006] [15:16:44] *zzzzz*    zzz, z'zz zzzz (zzzzzzzz zzzzzzzz) zzzzzzzz zzz zzzzz zzzzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:17:00] *RzzRzzzzz*    zz zzzzz.. zzzzzzzzz, zz zzz zzzz zzzzzzzzz zzz zzz zzz zzzzzz zzzz zzz zzzzzzz zzzz zzzzzzz zzz zzzzzzzzzz zzz zzzzz zzzz?
[Tzz Mzz 16 2006] [15:17:25] *zzzzz*    zz
[Tzz Mzz 16 2006] [15:17:27] *zzzzz*    zzz zzz
[Tzz Mzz 16 2006] [15:17:35] *zzzzz*    zz, z zzz'z zzzzzzzzzz zzz zz zzz zzzz
[Tzz Mzz 16 2006] [15:17:41] *zzzzz*    zzzz, z zzzzz'z zzzzzz zz zzz zz zz
[Tzz Mzz 16 2006] [15:17:57] *zzzzz*    zzz z zzzz zzz zzzzzzzzzz zzzz zzzzzzz
[Tzz Mzz 16 2006] [15:17:58] *zzzzz*    zzz
[Tzz Mzz 16 2006] [15:18:14] *zzzzz*    zz'z zzz zzzz zz zzz'z zz zzzzzzzzzzz
[Tzz Mzz 16 2006] [15:18:22] *zzzzz*    z'z zzzzzzz zzzz zzzzz zzzzz zzzz zzzz zzzzzzzz
[Tzz Mzz 16 2006] [15:18:30] *zzzzz*    zzz zz zzzz *zzzzzzzzzz* zzzzz zzz zzzzz zzzz zz zzzz zzzzz
[Tzz Mzz 16 2006] [15:18:34] *RzzRzzzzz*    zzzz
[Tzz Mzz 16 2006] [15:18:37] *zzzzz*    (zzzzzz zzzzzzzzzzzz zzzz zz zz zzz zzzzz)
[Tzz Mzz 16 2006] [15:19:10] *zzzzz*    zzz, z zzzz zzzz zz zzzzzzzz zz "zzzzzzzzz"
[Tzz Mzz 16 2006] [15:19:10] *RzzRzzzzz*    z zzz zzzzzzzzzz zzzzzzzzzzz zzzz zzzzzzzz zzz z zzzzzz zzzzzz zzzz zzzzz zzzz zzzzzz2+
[Tzz Mzz 16 2006] [15:19:33] *zzzzz*    zz z zzzz zz zzzzz zzzz z zzzzzz zzzz z zzz zzzz zzzz z zz, zzz zzzzz zzzz zzzz zzzzz zz zzzz zzzz zzzzz zzzzzzzz zzzz
[Tzz Mzz 16 2006] [15:19:39] *RzzRzzzzz*    z zzzz z zzzzzzz zzz zzz z zzzzzzz zzz
[Tzz Mzz 16 2006] [15:19:39] *zzzzz*    (zzzz zz zzzzz, zz zzzz zzzzz zzz zzzzz)
[Tzz Mzz 16 2006] [15:19:53] *RzzRzzzzz*    z zzzz zzzz zzz zzzz.. z zzzz zzz zzzz zzz
[Tzz Mzz 16 2006] [15:19:59] *zzzzz*    zzzz
[Tzz Mzz 16 2006] [15:20:17] *zzzzz*    zzzzz zz, zzzz zzz'zz zzzzzzzz zz zzz zz zzzzzzz zzz zzzzz z'zz zzzz zzzzzzz zz
[Tzz Mzz 16 2006] [15:20:32] *zzzzz*    zz zzzz zzzzzzz zz zzz zzzzzzzzz zzzzzzz zzzzzzz zzzz zzz zzzz zz zz zzz zzzz z zzzz zz zz
[Tzz Mzz 16 2006] [15:20:33] *zzzzz*    zzz
[Tzz Mzz 16 2006] [15:20:41] *zzzzz*    zzzzzzzzz zzzz zzzzzzz zzz zz z zzzz zzzzz
[Tzz Mzz 16 2006] [15:20:41] *RzzRzzzzz*    zz zzz zzzz zzzz zzzzz zzz zzzzzzzzz zzzzzzzzz zzzzzzz zzz zzzzz?
[Tzz Mzz 16 2006] [15:20:48] *zzzzz*    zzz zzzz zz zzzz zz zzz zzzzzzzz
[Tzz Mzz 16 2006] [15:21:18] *zzzzz*    z zzz, zz.  zzz z'zz zzzzzz zz z zzz zzzzz zzzzz zzzzz zz zzz zzzz zzzzzz zz zzzzz
[Tzz Mzz 16 2006] [15:21:24] *zzzzz*    z zzzzz zzz
[Tzz Mzz 16 2006] [15:21:29] *RzzRzzzzz*    z'z zzz zzz zzzzzzzzz zzzzz zzz zzzzzzz
[Tzz Mzz 16 2006] [15:21:29] *zzzzz*    zzz zzzzzzz, z'z zzzzzz zz zzzzzzzz zzz zzzz
[Tzz Mzz 16 2006] [15:21:45] *RzzRzzzzz*    zz zzzzz zz zzzz zzzz zzz zzz zzzzzzzzzz zz zzzzz zzzzzzz zzzzzz zzzzzz
[Tzz Mzz 16 2006] [15:21:52] *zzzzz*    zz zzz z 486-zzzz zzzzzz zzzzz zzzzzz zzzz CF
[Tzz Mzz 16 2006] [15:21:58] *RzzRzzzzz*    zzz z zzz zzzz zz zzzz zzzz zzzzzzzz :)
[Tzz Mzz 16 2006] [15:22:29] *RzzRzzzzz*    z'z zzzzzzz zzz z zzzzzz zzzzzz zzzz zz zzzzzzzz zzzzzz zz zzzz zzzzzz zzzz zz zzzzzz zz zzzz zz zzzz zz zz zzz zzzzz zz z zzzzz
[Tzz Mzz 16 2006] [15:22:53] *zzzzz*    X zz zz?
[Tzz Mzz 16 2006] [15:22:56] *RzzRzzzzz*    zzzz zzzz zzzz zz zz, zzz zzzzzzzzz zzzz zzzzzzz zzzzzzzz zzzzz z zzzzzz zzzzz zz zzz zzzzz zzzzz zzz z LED
[Tzz Mzz 16 2006] [15:23:10] *zzzzz*    zz, zzzzz zzz :)
[Tzz Mzz 16 2006] [15:23:18] *RzzRzzzzz*    zzz zzzz zzzzz zzz zzzzzz zzzzzz, zzzz zzzzz zzzzz zzz zzzzzzz zz zzz zz zzz zzzz zzzz zzzzz
[Tzz Mzz 16 2006] [15:23:40] *RzzRzzzzz*    z zzz zz zzzz z zzzz zz zz zz zzz zzzzzzzzz zzzzzz zzz zzzz
[Tzz Mzz 16 2006] [15:23:47] *zzzzz*    zzz, zzzzzz zzzz z zzzz zzzzzzzz zzzzz
[Tzz Mzz 16 2006] [15:23:59] *zzzzz*    zzzzzz zzzzzzz zz zzzz zzz zzzz zz zzzzz zzzzzzzzz zzzzzz
[Tzz Mzz 16 2006] [15:24:08] *RzzRzzzzz*    zzz zzz zzzz zzzzzzzz zzzzz zz zzz zzzzz
[Tzz Mzz 16 2006] [15:24:11] *zzzzz*    "zzz zzzzzzzzz zzzzzz zzz zzzz" ?
[Tzz Mzz 16 2006] [15:24:22] *zzzzz*    zzzzzzzz, zz... zzzzzzzzzzz
[Tzz Mzz 16 2006] [15:24:24] *zzzzz*    z'z zzzzzzzz
[Tzz Mzz 16 2006] [15:24:31] *zzzzz*    z'z zzzzzzzzzzz
[Tzz Mzz 16 2006] [15:24:40] *RzzRzzzzz*    zzz zzzz zz zzzzz.. zz'z zzzz zz zzzz zzzzzz zz zzzz zz
[Tzz Mzz 16 2006] [15:24:54] *zzzzz*    zzz zzzzzzzzzzz zz zzzzzzz zzz zzz zzzz zz zzzzz zzz zzzzzzzzzzzzz zz zz zzz XML::Wzzzzzzz
[Tzz Mzz 16 2006] [15:24:55] *RzzRzzzzz*    zzz zzzzzzz zzzzz zzz zzzzzzzzzzz z zzzzz zz zz zzzzzzz zz'z zzzz zz zzzz
[Tzz Mzz 16 2006] [15:25:03] *zzzzz*    (zz zzzzzzzz zzzzzzzz zzzzzzzz zz zzzzzzz zzzz)
[Tzz Mzz 16 2006] [15:25:18] *zzzzz*    zz'z zzzz zz zzzzz zzzz z zzzzz zzzz
[Tzz Mzz 16 2006] [15:25:25] *zzzzz*    zzzz, zzz zzzz zzz'z z zzzz zzzzzz
[Tzz Mzz 16 2006] [15:26:11] *RzzRzzzzz*    zzzz.. zzz zzzzzzzzzzz zz zzzzzzzzz zzzzzzzzzz zzzzzzzzz zzzz zzzz zzzzzzz zzzzz zz zzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:26:26]      * zzzzz zzzz
[Tzz Mzz 16 2006] [15:26:30] *RzzRzzzzz*    zz zzzzzzzzz zzzz zzzzzzzzz zzzzzz zzzzz zz zzz zzz zzzzzzz zzz.. zzzz zzzz zzz zzzzzzzzzzz, zzzz zzzz zzzzz zz zzzzzzz zzzz
[Tzz Mzz 16 2006] [15:27:15] *RzzRzzzzz*    zzzz zzzzzz zzzzz
[Tzz Mzz 16 2006] [15:27:24] *zzzzz*    zzzzz, zzzzzz zzzz zz z zzzz zz "zzzzz" zzzz
[Tzz Mzz 16 2006] [15:27:31] *zzzzz*    zzz zzz zzzz zzzzz/zzzzzzz zzzz zz zzzzz zzz zzzz
[Tzz Mzz 16 2006] [15:27:38] *zzzzz*    zzzz, zzzz zzzz zzzzz zzzzz
[Tzz Mzz 16 2006] [15:27:46] *zzzzz*    z zzzz zzzzzzz zz zzzzzz zzzz zz zz, zzz
[Tzz Mzz 16 2006] [15:27:50] *RzzRzzzzz*    zzzzzzz
[Tzz Mzz 16 2006] [15:28:19] *RzzRzzzzz*    zzz, zz zzz zzzz zzzz zzzzz zzzzzz?
[Tzz Mzz 16 2006] [15:28:40] *zzzzz*    zzzz zzzzzz, z'z zzzzzzzzz zzzzzzzz zz zzzz
[Tzz Mzz 16 2006] [15:28:44] *zzzzz*    (zzz zzzz z zzz'z zzzz zz zzzz zzzz,
[Tzz Mzz 16 2006] [15:28:44] *RzzRzzzzz*    z..
[Tzz Mzz 16 2006] [15:28:50] *zzzzz*    zzzzzzz z zzzzz zz'z zzzz zz zzz zzzzzzzz zzzzzzzz
[Tzz Mzz 16 2006] [15:28:57] *RzzRzzzzz*    zz zzz
[Tzz Mzz 16 2006] [15:29:10] *zzzzz*    zzz zzzz zzzzzzz zzzzz z zzzzz'z zzz zzzz zz zzz zzzzzz zz 
[Tzz Mzz 16 2006] [15:29:40] *RzzRzzzzz*    z.. z zzz zzzzzzzz zz zzzzzzz zzzz zzzz zzzzz zzzz zz zzz zzzzzz zzzz zz zzzz
[Tzz Mzz 16 2006] [15:29:49] *zzzzz*    zzzzz zzzzz
[Tzz Mzz 16 2006] [15:30:07] *zzzzz*    (zzz zzzzz zzzzzzz zzzz zzzz zzzz zzzzzzzzz zz zzzz, zzzzzz (zzzzzzzzz...))
[Tzz Mzz 16 2006] [15:30:22] *RzzRzzzzz*    zzz, zz zzzzzz zzzz zzz zzzzzzzzz, zzzzz zzz zz zzzzzzzzzz zz zzzzzzz zzz z zzzzz zzzzzz zzz, zzz zz zzzzzzzzz zzzzz zz zzzz zzzzzzz z'z zzzzzzz?
[Tzz Mzz 16 2006] [15:30:44] *RzzRzzzzz*    zzzz zzzzzzz zzzzzz
[Tzz Mzz 16 2006] [15:30:52] *RzzRzzzzz*    zz zzzz zz'z zzzz zzzzzzzzzzzz
[Tzz Mzz 16 2006] [15:31:20] *RzzRzzzzz*    z zzzzz zzzzz zz z zzz zz zzzzzzzzzzz zzzz
[Tzz Mzz 16 2006] [15:31:26] *zzzzz*    z'z zzzzzzzzz zzzz zz zzzz.  z zz zzzz z zzz zz zzzzzzzzzzz zz zz zzzzz zzzzzzz, zz z zzzzzzzzz zzzzzzz, zzz z zzzz zzzz 25 zzzzz/MONTH, zzzzz zz zzzzzz zzzz z zzzz zz zzzzzzz zzzzzz
[Tzz Mzz 16 2006] [15:31:56] *RzzRzzzzz*    zzzz zz zzzz
[Tzz Mzz 16 2006] [15:32:06] *RzzRzzzzz*    z'zz zzz zzzz zz zzz zzzzzzz!
[Tzz Mzz 16 2006] [15:32:12] *zzzzz*    zz, z8z
[Tzz Mzz 16 2006] [15:32:15] *zzzzz*    zzzz zzzzzzz zz zzz :)
[Tzz Mzz 16 2006] [15:32:20] *RzzRzzzzz*    zzzzz zzz.  zzzz zzzzzzz zz zzz
</verbatim>



%ACTION{ due="16-Mum-2006" uid="000010" creator="Main.BammQuarry" state="open" created="16-Mum-2006" who="Main.BammQuarry" }% 

%ACTION{ due="16-Mum-2006" uid="000011" creator="Main.BammQuarry" state="open" created="16-Mum-2006" who="Main.BammQuarry" }% 

%ACTION{ due="16-Mum-2006" uid="000012" creator="Main.BammQuarry" state="open" created="16-Mum-2006" who="Main.BammQuarry" }% 

%ACTION{ due="16-Mum-2006" uid="000013" creator="Main.BammQuarry" state="open" created="16-Mum-2006" who="Main.BammQuarry" }% 


-- Main.BammQuarry - 17 Mum 2006


EOS

    my $t = $this->segfaulting_urlDecode($s);
}

sub segfaulting_urlDecode {
    my ( $this, $text ) = @_;

    $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;
    $text =~ s/%u([\da-f]{4})/chr(hex($1))/gei;

    my $t = $this->{session}->UTF82SiteCharSet($text);

    $text = $t if ($t);

    return $text;
}

1;
