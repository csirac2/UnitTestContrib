# tests for Foswiki::Logger

package LoggerTests;
use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use strict;
use File::Temp;
use File::Path;
use Foswiki::Logger::PlainFile;

# NOTE: Test logs are created in the test web so they get torn down when the
# web is torn down in the superclass.
our $logDir;

sub set_up {
    my $this = shift;
    delete $Foswiki::cfg{LogFileName};
    delete $Foswiki::cfg{DebugFileName};
    delete $Foswiki::cfg{WarningFileName};
    $this->SUPER::set_up();
    $logDir = "logDir$$";
    $Foswiki::cfg{Log}{Dir} = "$logDir";
    mkdir $Foswiki::cfg{Log}{Dir};
}

sub tear_down {
    my $this = shift;

    File::Path::rmtree($logDir);
    $this->SUPER::tear_down();
}

sub CompatibilityLogger {
    my $this = shift;
    require Foswiki::Logger::Compatibility;
    $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::Compatibility';
    $this->{logger}                    = new Foswiki::Logger::Compatibility();
    $Foswiki::cfg{LogFileName}         = "$logDir/logfile%DATE%";
    $Foswiki::cfg{DebugFileName}       = "$logDir/debug%DATE%";
    $Foswiki::cfg{WarningFileName}     = "$logDir/warn%DATE%!!";
}

sub PlainFileLogger {
    my $this = shift;
    require Foswiki::Logger::PlainFile;
    $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::PlainFile';
    $this->{logger} = new Foswiki::Logger::PlainFile();
}

sub ObfuscatingLogger {
    my $this = shift;
    require Foswiki::Logger::PlainFile::Obfuscating;
    $Foswiki::cfg{Log}{Implementation} =
      'Foswiki::Logger::PlainFile::Obfuscating';
    $Foswiki::cfg{Log}{Obfuscating}{MaskIP} = 1;
    $this->{logger} = new Foswiki::Logger::PlainFile::Obfuscating();
}

sub fixture_groups {
    my %algs;
    foreach my $dir (@INC) {
        if ( opendir( D, "$dir/Foswiki/Logger" ) ) {
            foreach my $alg ( readdir D ) {
                next unless $alg =~ /^(\w+)\.pm$/;
                $algs{$1} = 1;
            }
            closedir(D);
        }
        if ( opendir( D, "$dir/Foswiki/Logger/PlainFile" ) ) {
            foreach my $alg ( readdir D ) {
                next unless $alg =~ /^(\w+)\.pm$/;
                $algs{$1} = 1;
            }
            closedir(D);
        }
    }
    my @groups;
    foreach my $alg ( keys %algs ) {
        my $fn = $alg . 'Logger';
        push( @groups, $fn );
    }

    return \@groups;
}

sub verify_simpleWriteAndReplay {
    my $this   = shift;
    my $time   = time;
    my $ipaddr = '1.2.3.4';
    my $tmpIP  = $ipaddr;

    # Verify the three levels used by Foswiki; debug, info and warning
    foreach my $level (qw(debug info warning)) {

      #  For the obfuscating logger,  have the warning record hash the IP addrss
        if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::PlainFile::Obfuscating'
            && $level eq 'warning' )
        {
            $Foswiki::cfg{Log}{Obfuscating}{MaskIP} = 0;
        }

        $this->{logger}->log( $level, $level, "Green", "Eggs", "and", $tmpIP );
    }

    $ipaddr = 'x.x.x.x'
      if ( $Foswiki::cfg{Log}{Implementation} eq
        'Foswiki::Logger::PlainFile::Obfuscating' );

    foreach my $level (qw(debug info warning)) {
        my $it = $this->{logger}->eachEventSince( $time, $level );
        $this->assert( $it->hasNext(), $level );
        my $data = $it->next();
        my $t    = shift(@$data);
        $this->assert( $t >= $time, "$t $time" );
        $ipaddr = '109.104.118.183'
          if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::PlainFile::Obfuscating'
            && $level eq 'warning' );
        $this->assert_str_equals( "$level.Green.Eggs.and.$ipaddr",
            join( '.', @$data ) );
        $this->assert( !$it->hasNext() );
    }

}

sub verify_eachEventSinceOnEmptyLog {
    my $this = shift;
    foreach my $level (qw(debug info warning)) {
        my $it = $this->{logger}->eachEventSince( 0, $level );
        if ( $it->hasNext() ) {
            use Data::Dumper;
            die Data::Dumper->Dump( [ $it->next() ] );
        }
        $this->assert( !$it->hasNext() );
    }
}

my $plainFileTestTime;

sub PlainFileTestTime {
    return $plainFileTestTime;
}

# Test specific to PlainFile logger
sub verify_eachEventSinceOnSeveralLogs {
    my $this   = shift;
    my $logger = new Foswiki::Logger::PlainFile();
    my $cache  = \&Foswiki::Logger::PlainFile::_time;
    no warnings 'redefine';
    *Foswiki::Logger::PlainFile::_time = \&PlainFileTestTime;

    $plainFileTestTime = 3600;
    $logger->log( 'info', "Seal" );
    my $firstTime = time - 2 * 32 * 24 * 60 * 60;
    $plainFileTestTime = $firstTime;    # 2 months ago
    $logger->log( 'info', "Dolphin" );
    $plainFileTestTime += 32 * 24 * 60 * 60;    # 1 month ago
    $logger->log( 'info', "Whale" );
    $plainFileTestTime = time;                  # today
    $logger->log( 'info', "Porpoise" );

    my $it = $logger->eachEventSince( 0, 'info' );
    my $data;
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_equals( 3600, $data->[0] );
    $this->assert_str_equals( "Seal", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_equals( $firstTime, $data->[0] );
    $this->assert_str_equals( "Dolphin", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_str_equals( "Whale", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_equals( $plainFileTestTime, $data->[0] );
    $this->assert_str_equals( "Porpoise", $data->[1] );
    $this->assert( !$it->hasNext() );

    # Check the date filter
    $it = $logger->eachEventSince( $firstTime, 'info' );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_equals( $firstTime, $data->[0] );
    $this->assert_str_equals( "Dolphin", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_str_equals( "Whale", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_equals( $plainFileTestTime, $data->[0] );
    $this->assert_str_equals( "Porpoise", $data->[1] );
    $this->assert( !$it->hasNext() );

    *Foswiki::Logger::PlainFile::_time = $cache;
    use warnings 'redefine';
}

sub verify_filter {

    # with PlainFile, warning up are all crammed into one logfile
    my $this   = shift;
    my $logger = new Foswiki::Logger::PlainFile();
    $logger->log( 'warning',  "Shark" );
    $logger->log( 'error',    "Dolphin" );
    $logger->log( 'critical', "Injury" );
    $logger->log( 'warning',  "Bite" );
    $logger->log( 'alert',    "Ram" );
    $logger->log( 'warning',  "Hurts" );
    $logger->log( 'critical', "Doctors" );

    my $it = $logger->eachEventSince( 0, 'warning' );
    my $data;
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_str_equals( "Shark", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_str_equals( "Bite", $data->[1] );
    $this->assert( $it->hasNext() );
    $data = $it->next();
    $this->assert_str_equals( "Hurts", $data->[1] );
    $this->assert( !$it->hasNext() );
}

my $mode;     # access mode
my $mtime;    # modify time

sub PlainFileTestStat {
    return ( 0, 0, $mode, 0, 0, 0, 0, 99, 0, $mtime, 0, 0, 0, 0 );
}

sub verify_rotate_events {
    my $this = shift;

    return
      unless $Foswiki::cfg{Log}{Implementation} =~
          '^Foswiki::Logger::PlainFile';

    my $timecache = \&Foswiki::Logger::PlainFile::_time;
    my $statcache = \&Foswiki::Logger::PlainFile::_stat;
    no warnings 'redefine';
    *Foswiki::Logger::PlainFile::_time = \&PlainFileTestTime;
    *Foswiki::Logger::PlainFile::_stat = \&PlainFileTestStat;

    $Foswiki::Logger::PlainFile::dontRotate = 1;

    my $then = Foswiki::Time::parseTime("2000-02-01T00:00Z");

    $plainFileTestTime = $then;
    $mode              = 0777;

    # Don't try to rotate a non-existant log
    my $lfn = "$Foswiki::cfg{Log}{Dir}/events.log";

    my $logger = new Foswiki::Logger::PlainFile();
    $this->assert( !-e $lfn );
    $logger->_rotate($plainFileTestTime);
    $this->assert( !-e $lfn );

    # Create the log, the entry should be stamped at $then - 1000 (last month)
    $plainFileTestTime = Foswiki::Time::parseTime("2000-01-31T23:59Z");
    $logger->log( 'info',      'Nil carborundum illegitami' );
    $logger->log( 'warning',   'Nil carborundum illegitami' );
    $logger->log( 'critical',  'Nil carborundum illegitami' );
    $logger->log( 'emergency', 'Nil carborundum illegitami' );
    $logger->log( 'error',     'Nil carborundum illegitami' );
    $logger->log( 'debug',     'Nil carborundum illegitami' );
    $logger->log( 'alert',     'Nil carborundum illegitami' );

    # fake the modify time
    $mtime = $plainFileTestTime;

    $Foswiki::Logger::PlainFile::dontRotate           = 0;
    $Foswiki::Logger::PlainFile::nextCheckDue{error}  = $then;
    $Foswiki::Logger::PlainFile::nextCheckDue{debug}  = $then;
    $Foswiki::Logger::PlainFile::nextCheckDue{events} = $then;

    # now advance the clock to this month, and add another log entry. This
    # should rotate the log.
    $plainFileTestTime = $then;
    $logger->log( 'info',      'Salve nauta' );
    $logger->log( 'warning',   'Salve nauta' );
    $logger->log( 'critical',  'Salve nauta' );
    $logger->log( 'emergency', 'Salve nauta' );
    $logger->log( 'error',     'Salve nauta' );
    $logger->log( 'debug',     'Salve nauta' );
    $logger->log( 'alert',     'Salve nauta' );

    local $/ = undef;
    $this->assert( open( F, '<', $lfn ) );
    my $e = <F>;
    $this->assert_equals( "| 2000-02-01T00:00:00Z info | Salve nauta |\n", $e );
    close(F);

    # We should see the creation of a backup log with
    # the last-month entry, and the current log should be cut down to
    # this month's entry.
    my $backup = $lfn;
    $backup =~ s/log$/200001/;
    $this->assert( -e $backup );

    $this->assert( open( F, '<', $backup ) );
    $e = <F>;
    $this->assert_equals(
        "| 2000-01-31T23:59:00Z info | Nil carborundum illegitami |\n", $e );
    close(F);

    *Foswiki::Logger::PlainFile::_time = $timecache;
    *Foswiki::Logger::PlainFile::_stat = $statcache;
    use warnings 'redefine';
}

sub verify_rotate_debug {
    my $this = shift;

    return
      unless $Foswiki::cfg{Log}{Implementation} =~
          '^Foswiki::Logger::PlainFile';

    my $timecache = \&Foswiki::Logger::PlainFile::_time;
    my $statcache = \&Foswiki::Logger::PlainFile::_stat;
    no warnings 'redefine';
    *Foswiki::Logger::PlainFile::_time = \&PlainFileTestTime;
    *Foswiki::Logger::PlainFile::_stat = \&PlainFileTestStat;

    $Foswiki::Logger::PlainFile::dontRotate = 1;

    my $then = Foswiki::Time::parseTime("2000-02-01T00:00Z");

    $plainFileTestTime = $then;
    $mode              = 0777;

    # Don't try to rotate a non-existant log
    my $lfn = "$Foswiki::cfg{Log}{Dir}/debug.log";

    my $logger = new Foswiki::Logger::PlainFile();
    $this->assert( !-e $lfn );
    $logger->_rotate($plainFileTestTime);
    $this->assert( !-e $lfn );

    # Create the log, the entry should be stamped at $then - 1000 (last month)
    $plainFileTestTime = Foswiki::Time::parseTime("2000-01-31T23:59Z");
    $logger->log( 'info',      'Nil carborundum illegitami' );
    $logger->log( 'warning',   'Nil carborundum illegitami' );
    $logger->log( 'critical',  'Nil carborundum illegitami' );
    $logger->log( 'emergency', 'Nil carborundum illegitami' );
    $logger->log( 'error',     'Nil carborundum illegitami' );
    $logger->log( 'debug',     'Nil carborundum illegitami' );
    $logger->log( 'alert',     'Nil carborundum illegitami' );

    # fake the modify time
    $mtime = $plainFileTestTime;

    $Foswiki::Logger::PlainFile::dontRotate           = 0;
    $Foswiki::Logger::PlainFile::nextCheckDue{error}  = $then;
    $Foswiki::Logger::PlainFile::nextCheckDue{debug}  = $then;
    $Foswiki::Logger::PlainFile::nextCheckDue{events} = $then;

    # now advance the clock to this month, and add another log entry. This
    # should rotate the log.
    $plainFileTestTime = $then;
    $logger->log( 'info',      'Salve nauta' );
    $logger->log( 'warning',   'Salve nauta' );
    $logger->log( 'critical',  'Salve nauta' );
    $logger->log( 'emergency', 'Salve nauta' );
    $logger->log( 'error',     'Salve nauta' );
    $logger->log( 'debug',     'Salve nauta' );
    $logger->log( 'alert',     'Salve nauta' );

    local $/ = undef;
    $this->assert( open( F, '<', $lfn ) );
    my $e = <F>;
    $this->assert_equals( "| 2000-02-01T00:00:00Z debug | Salve nauta |\n",
        $e );
    close(F);

    # We should see the creation of a backup log with
    # the last-month entry, and the current log should be cut down to
    # this month's entry.
    my $backup = $lfn;
    $backup =~ s/log$/200001/;
    $this->assert( -e $backup );

    $this->assert( open( F, '<', $backup ) );
    $e = <F>;
    $this->assert_equals(
        "| 2000-01-31T23:59:00Z debug | Nil carborundum illegitami |\n", $e );
    close(F);

    *Foswiki::Logger::PlainFile::_time = $timecache;
    *Foswiki::Logger::PlainFile::_stat = $statcache;
    use warnings 'redefine';
}

sub verify_rotate_error {
    my $this = shift;

    return
      unless $Foswiki::cfg{Log}{Implementation} =~
          '^Foswiki::Logger::PlainFile';

    my $timecache = \&Foswiki::Logger::PlainFile::_time;
    my $statcache = \&Foswiki::Logger::PlainFile::_stat;
    no warnings 'redefine';
    *Foswiki::Logger::PlainFile::_time = \&PlainFileTestTime;
    *Foswiki::Logger::PlainFile::_stat = \&PlainFileTestStat;

    $Foswiki::Logger::PlainFile::dontRotate = 1;

    my $then = Foswiki::Time::parseTime("2000-02-01T00:00Z");

    $plainFileTestTime = $then;
    $mode              = 0777;

    # Don't try to rotate a non-existant log
    my $lfn = "$Foswiki::cfg{Log}{Dir}/error.log";

    my $logger = new Foswiki::Logger::PlainFile();
    $this->assert( !-e $lfn );
    $logger->_rotate($plainFileTestTime);
    $this->assert( !-e $lfn );

    # Create the log, the entry should be stamped at $then - 1000 (last month)
    $plainFileTestTime = Foswiki::Time::parseTime("2000-01-31T23:59Z");
    $logger->log( 'info',      'Nil carborundum illegitami' );
    $logger->log( 'warning',   'Nil carborundum illegitami' );
    $logger->log( 'critical',  'Nil carborundum illegitami' );
    $logger->log( 'emergency', 'Nil carborundum illegitami' );
    $logger->log( 'error',     'Nil carborundum illegitami' );
    $logger->log( 'debug',     'Nil carborundum illegitami' );
    $logger->log( 'alert',     'Nil carborundum illegitami' );

    # fake the modify time
    $mtime = $plainFileTestTime;

    $Foswiki::Logger::PlainFile::dontRotate           = 0;
    $Foswiki::Logger::PlainFile::nextCheckDue{error}  = $then;
    $Foswiki::Logger::PlainFile::nextCheckDue{debug}  = $then;
    $Foswiki::Logger::PlainFile::nextCheckDue{events} = $then;

    # now advance the clock to this month, and add another log entry. This
    # should rotate the log.
    $plainFileTestTime = $then;
    $logger->log( 'info',      'Salve nauta' );
    $logger->log( 'warning',   'Salve nauta' );
    $logger->log( 'critical',  'Salve nauta' );
    $logger->log( 'emergency', 'Salve nauta' );
    $logger->log( 'error',     'Salve nauta' );
    $logger->log( 'debug',     'Salve nauta' );
    $logger->log( 'alert',     'Salve nauta' );

    local $/ = undef;
    $this->assert( open( F, '<', $lfn ) );
    my $e = <F>;
    $this->assert_equals( $e, <<FILE );
| 2000-02-01T00:00:00Z warning | Salve nauta |
| 2000-02-01T00:00:00Z critical | Salve nauta |
| 2000-02-01T00:00:00Z emergency | Salve nauta |
| 2000-02-01T00:00:00Z error | Salve nauta |
| 2000-02-01T00:00:00Z alert | Salve nauta |
FILE

    close(F);

    # We should see the creation of a backup log with
    # the last-month entry, and the current log should be cut down to
    # this month's entry.
    my $backup = $lfn;
    $backup =~ s/log$/200001/;
    $this->assert( -e $backup );

    $this->assert( open( F, '<', $backup ) );
    $e = <F>;
    $this->assert_equals( $e, <<FILE );
| 2000-01-31T23:59:00Z warning | Nil carborundum illegitami |
| 2000-01-31T23:59:00Z critical | Nil carborundum illegitami |
| 2000-01-31T23:59:00Z emergency | Nil carborundum illegitami |
| 2000-01-31T23:59:00Z error | Nil carborundum illegitami |
| 2000-01-31T23:59:00Z alert | Nil carborundum illegitami |
FILE
    close(F);

    *Foswiki::Logger::PlainFile::_time = $timecache;
    *Foswiki::Logger::PlainFile::_stat = $statcache;
    use warnings 'redefine';
}

1;
