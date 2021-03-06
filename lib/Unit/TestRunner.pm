# See bottom of file for license and copyright
package Unit::TestRunner;

=begin TML

---+ package Unit::TestRunner

Test run controller. Provides most of the functionality for the TestRunner.pl
script that runs testcases.

=cut

use strict;
use warnings;
use Devel::Symdump;
use Error qw(:try);
use File::Spec;

sub CHECKLEAK { 0 }

BEGIN {
    if (CHECKLEAK) {
        eval "use Devel::Leak::Object qw{ GLOBAL_bless };";
        die $@ if $@;
        $Devel::Leak::Object::TRACKSOURCELINES = 1;
    }
}

sub new {
    my $class = shift;
    return bless(
        {
            unexpected_passes => [],
            expected_failures => [],
            failures          => [],
            number_of_asserts => 0,
            unexpected_result => {},
            tests_per_module  => {}
        },
        $class
    );
}

sub start {
    my $this  = shift;
    my @files = @_;
    @{ $this->{failures} }   = ();
    @{ $this->{initialINC} } = @INC;
    my $passes = 0;

    my ($start_cwd) = Cwd->cwd() =~ m/^(.*)$/;
    print "Starting CWD is $start_cwd \n";

    # First use all the tests to get them compiled
    while ( scalar(@files) ) {
        my $testSuiteModule = shift @files;
        $testSuiteModule =~
          s/\/$//;    # Trim final slash, for completion lovers like Sven
        my $testToRun;
        if ( $testSuiteModule =~ s/::(\w+)$// ) {
            $testToRun = $1;
        }
        my $suite = $testSuiteModule;
        if ( $testSuiteModule =~ /^(.*?)(\w+)\.pm$/ ) {
            $suite = $2;
            push( @INC, $1 ) if $1 && -d $1;
        }
        ($suite) = $suite =~ /^(.*)$/;
        eval "use $suite";
        if ($@) {
            my $useError = $@;
            my $bad;

            # Try to be clever, look for it
            if ( $useError =~ /Can't locate \Q$suite\E\.pm in \@INC/ ) {
                my $testToFind = $testToRun ? "::$testToRun" : '';
                print "Looking for $suite$testToFind...\n";
                require File::Find;
                my @found;
                File::Find::find(
                    {
                        wanted => sub {
                            /^$suite/
                              && $File::Find::name =~ /^\.\/(.*\.pm)$/
                              && ( print("\tFound $1\n") )
                              && push( @found, $1 . $testToFind );
                        },
                        follow            => 1,
                        untaint           => 1,
                        dangling_symlinks => sub {
                            if ( $_[0] =~ m/^$suite/ ) {
                                print
"ERROR: $_[0] has dangling symlink, bypassing ...\n";
                                $bad = 1;
                            }
                        },
                        untaint_pattern => qr|^([-+@\w./:]+)$|,
                    },
                    '.'
                );

                next if ($bad);

                # Try to be even smarter: favor test suites
                # unless a specific test was requested
                my @suite = grep { /Suite\.pm/ } @found;
                if ( $#found and @suite ) {
                    if ($testToFind) {
                        @found = grep { !/Suite.pm/ } @found;
                        print "$testToRun is most likely not in @suite"
                          . ", removing it\n";
                        unshift @files, @found;
                    }
                    else {
                        print "Found "
                          . scalar(@found)
                          . " tests,"
                          . " favoring @suite\n";
                        unshift @files, @suite;
                    }
                }
                else {
                    unshift @files, @found;
                }
                next if @found;
            }
            my $m = "*** Failed to use $suite: $useError";
            print $m;
            push( @{ $this->{failures} }, $m );
            next;
        }
        print "Running $suite\n";
        my $tester = $suite->new($suite);
        if ( $tester->isa('Unit::TestSuite') ) {

            # Get a list of included tests
            my @set = $tester->include_tests();
            unshift( @files, @set );
        }
        else {
            my $completed;
            my $action;
            if ( $tester->run_in_new_process() ) {
                $action =
                  $this->runOneInNewProcess( $testSuiteModule, $suite,
                    $testToRun );
            }
            else {
                $action = runOne( $tester, $suite, $testToRun );
            }

            if ( Cwd->cwd() ne $start_cwd ) {
                print "CWD changed to " . Cwd->cwd() . " by previous test!! \n";
                chdir $start_cwd
                  or die "Cannot change back to previous $start_cwd\n";
            }

            # untaint action for the case where the test is run in
            # another process
            $action =~ m/^(.*)$/ms;
            eval $1;
            die $@ if $@;
            die "Test suite $suite aborted\n" unless $completed;
        }
    }

    #marker so we can remove the above large output from the nightly emails
    print "\nUnit test run Summary:\n";
    my $total = $passes;
    my $failed;
    my $expected_failures_total = 0;
    my $unexpected_passes_total = 0;
    if ( $failed = scalar @{ $this->{unexpected_passes} } ) {
        print "$failed unexpected pass" . ( $failed > 1 ? 'es' : '' ) . ":\n";
        print join( "\n", @{ $this->{unexpected_passes} } );
        $unexpected_passes_total = $failed;
        $total += $failed;
    }
    if ( $failed = scalar @{ $this->{expected_failures} } ) {
        print "$failed expected failure" . ( $failed > 1 ? 's' : '' ) . ":\n";
        print join( "\n", @{ $this->{expected_failures} } );
        $expected_failures_total = $failed;
        $total += $failed;
    }
    if ( $failed = scalar @{ $this->{failures} } ) {
        my $unexpected_total = 0;

        $total += $failed;
        print "\n$failed failure" . ( $failed > 1 ? 's' : '' ) . ":\n";
        print join( "\n---------------------------\n", @{ $this->{failures} } ),
          "\n";

        if ( $total > 0 ) {
            print <<"HERE";
----------------------------
---++ Module Failure summary
HERE
            foreach my $module (
                sort {
                    $this->{unexpected_result}
                      ->{$a} <=> $this->{unexpected_result}->{$b}
                } keys( %{ $this->{unexpected_result} } )
              )
            {
                print "$module has "
                  . $this->{unexpected_result}{$module}
                  . " unexpected results (of "
                  . $this->{tests_per_module}{$module} . "):\n";
                $unexpected_total += $this->{unexpected_result}{$module};
                foreach my $test ( sort( @{ $this->{unexpected_passes} } ) ) {

                    # SMELL: we should really re-arrange data structures to
                    # avoid guessing which module the test belongs to...
                    if ( $test =~ /^$module\b/ ) {
                        $this->_print_unexpected_test( $test, 'P' );
                    }
                }
                foreach my $test ( sort( @{ $this->{failures} } ) ) {
                    ($test) = split( /\n/, $test );

                    # SMELL: we should really re-arrange data structures to
                    # avoid guessing which module the test belongs to...
                    if ( $test =~ /^$module\b/ ) {
                        $this->_print_unexpected_test( $test, 'F' );
                    }
                }
            }
        }

        my $expected_passes = $total - $expected_failures_total;
        print <<"HERE";
----------------------------
$passes of $total test cases passed (expected $expected_passes of $total).
$unexpected_passes_total + $failed = $unexpected_total incorrect results from unexpected passes + failures
HERE
        ::PRINT_TAP_TOTAL();

        return $failed;
    }
    print "All tests passed ($passes"
      . ( $passes == $total ? '' : "/$total" ) . ")\n";
    ::PRINT_TAP_TOTAL();
    return 0;
}

sub _print_unexpected_test {
    my ( $this, $test, $sense ) = @_;

    print "   * $sense: $test\n";

    return;
}

sub runOneInNewProcess {
    my $this            = shift;
    my $testSuiteModule = shift;
    my $suite           = shift;
    my $testToRun       = shift;
    $testToRun ||= 'undef';

    my $tempfilename = 'worker_output.' . $$ . '.' . $suite;

    # Assume all new paths were either unshifted or pushed onto @INC
    my @pushedOntoINC    = @INC;
    my @unshiftedOntoINC = ();
    while ( $this->{initialINC}->[0] ne $pushedOntoINC[0] ) {
        push @unshiftedOntoINC, shift @pushedOntoINC;
    }
    for my $oneINC ( @{ $this->{initialINC} } ) {
        shift @pushedOntoINC if $pushedOntoINC[0] eq $oneINC;
    }

    my @paths;
    push( @paths, "-I", $_ ) for ( @unshiftedOntoINC, @pushedOntoINC );
    my @command = map {
        my $value = $_;
        if ( defined $value ) {
            $value =~ /(.*)/;
            $value = $1;    # untaint
        }
        $value;
      } (
        $^X, "-wT", @paths, File::Spec->rel2abs($0),
        "-worker", $suite,, $testToRun, $tempfilename
      );
    my $command = join( ' ', @command );
    print "Running: $command\n";

    $ENV{PATH} =~ /(.*)/;
    $ENV{PATH} = $1;        # untaint
    system(@command);
    if ( $? == -1 ) {
        my $error = $!;
        unlink $tempfilename;
        print "*** Could not spawn new process for $suite: $error\n";
        return
            'push( @{ $this->{failures} }, "' 
          . $suite . '\n'
          . quotemeta($error) . '" );';
    }
    else {
        my $returnCode = $? >> 8;
        if ($returnCode) {
            print "*** Error trying to run $suite\n";
            unlink $tempfilename;
            return
                'push( @{ $this->{failures} }, "Process for ' 
              . $suite
              . ' returned '
              . $returnCode . '" );';
        }
        else {
            open my $testoutputfile, "<", $tempfilename
              or die
              "Cannot open '$tempfilename' to read output from $suite: $!";
            my $action = '';
            while (<$testoutputfile>) {
                $action .= $_;
            }
            close $testoutputfile or die "Error closing '$tempfilename': $!";
            unlink $tempfilename;
            return $action;
        }
    }
}

sub worker {
    my $numArgs = scalar(@_);
    my ( $this, $testSuiteModule, $testToRun, $tempfilename ) = @_;
    if (   $numArgs != 4
        or not defined $this
        or not defined $testSuiteModule
        or not defined $testToRun
        or not defined $tempfilename )
    {
        my $pkg = __PACKAGE__;
        die <<"DIE";

Wrong number of arguments to $pkg->worker(). Got $numArgs, expected 4.
Are you trying to use -worker from the command-line?
-worker is only intended for use by $pkg->runOneInNewProcess().
To run your test in a separate process, override run_in_new_process() in your test class so that it returns true.
DIE
    }

    if ( $testToRun eq 'undef' ) {
        $testToRun = undef;
    }
    else {
        $testToRun =~ /(.*)/;    # untaint
        $testToRun = $1;
    }

    $testSuiteModule =~ /(.*)/;    # untaint
    $testSuiteModule = $1;

    $tempfilename =~ /(.*)/;       # untaint
    $tempfilename = $1;

    my $suite = $testSuiteModule;
    eval "use $suite";
    die $@ if $@;

    my $tester = $suite->new($suite);

    my $log = "stdout.$$.log";
    require Unit::Eavesdrop;
    open( my $logfh, ">", $log ) || die $!;
    print STDERR "Logging to $log\n";
    my $stdout = new Unit::Eavesdrop('STDOUT');
    $stdout->teeTo($logfh);

    # Don't need this, all the required info goes to STDOUT. STDERR is
    # really just treated as a black hole (except when debugging)
    #    my $stderr = new Unit::Eavesdrop('STDERR');
    #    $stderr->teeTo($logfh);

    my $action = runOne( $tester, $suite, $testToRun );

    {
        local $SIG{__WARN__} = sub { die $_[0]; };
        eval { close $logfh; };
        if ($@) {
            if ( $@ =~ /Bad file descriptor/ and $suite eq 'EngineTests' ) {

                # This is expected - ignore it
            }
            else {

                # propagate the error
                die $@;
            }
        }
    }
    undef $logfh;
    $stdout->finish();
    undef $stdout;

    #    $stderr->finish();
    #    undef $stderr;
    open( $logfh, "<", $log ) or die $!;
    local $/;    # slurp in whole file
    my $logged_stdout = <$logfh>;
    close $logfh or die $!;
    unlink $log  or die "Could not unlink $log: $!";

    #escape characters so that it may be printed
    $logged_stdout =~ s{\\}{\\\\}g;
    $logged_stdout =~ s{'}{\\'}g;
    $action .= "print '" . $logged_stdout . "';";

    open my $outputfile, ">", $tempfilename
      or die "Cannot open output file '$tempfilename': $!";
    print $outputfile $action . "\n";
    close $outputfile or die "Error closing output file '$tempfilename': $!";
    exit(0);
}

sub runOne {
    my $tester    = shift;
    my $suite     = shift;
    my $testToRun = shift;
    my $action    = '$completed = 1;';

    # Get a list of the test methods in the class
    my @tests = $tester->list_tests($suite);
    if ($testToRun) {
        my @runTests = grep { /^${suite}::$testToRun$/ } @tests;
        if ( !@runTests ) {
            @runTests = grep { /^${suite}::$testToRun/ } @tests;
            if ( !@runTests ) {
                print "*** No test matching $testToRun in $suite\n";
                print join( "\n", "\t$suite contains:", @tests, '' );
                return $action;
            }
            else {
                print "*** Running "
                  . @runTests
                  . " tests matching your pattern ($testToRun)\n";
            }
        }
        @tests = @runTests;
    }
    unless ( scalar(@tests) ) {
        print "*** No tests in $suite\n";
        return $action;
    }
    foreach my $test (@tests) {

        Devel::Leak::Object::checkpoint() if CHECKLEAK;
        print "\t$test\n";
        $action .= "\n# $test\n    ";
        $tester->set_up($test);
        try {
            $action .= '$this->{tests_per_module}->{\'' . $suite . '\'}++;';
            $tester->$test();
            _finish_singletons() if CHECKLEAK;
            $action .= '$passes++;';
            if ( $tester->{expect_failure} ) {
                print "*** Unexpected pass\n";
                $action .=
                  '$this->{unexpected_result}->{\'' . $suite . '\'}++;';
                $action .= 'push( @{ $this->{unexpected_passes} }, "'
                  . quotemeta($test) . '");';
            }
        }
        catch Error with {
            my $e = shift;
            print "*** ", $e->stringify(), "\n";
            if ( $tester->{expect_failure} ) {
                $action .= 'push( @{ $this->{expected_failures} }, "';
            }
            else {
                $action .=
                  '$this->{unexpected_result}->{\'' . $suite . '\'}++;';
                $action .= 'push( @{ $this->{failures} }, "';
            }
            $action .=
              quotemeta($test) . '\\n' . quotemeta( $e->stringify() ) . '" );';
        };
        $tester->tear_down($test);
        if (CHECKLEAK) {
            _finish_singletons();

            #require Devel::FindRef;
            #foreach my $s (@Foswiki::Address::THESE) {
            #    print STDERR Devel::FindRef::track($s);
            #}
        }
    }
    return $action;
}

sub _finish_singletons {

    # Item11349. This class keeps a bunch of singletons around, which is
    # the same as a memory leak.
    if ( eval { require Foswiki::Serialise; 1; }
        && Foswiki::Serialise->can('finish') )
    {
        Foswiki::Serialise->finish();
    }
}

1;

__DATA__

Author: Crawford Currie, http://c-dot.co.uk

Copyright (C) 2007-2010 Foswiki Contributors
All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
