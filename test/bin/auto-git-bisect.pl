#!/usr/bin/perl -w
package UnitTestContrib::AutoBisect;
use strict;
use warnings;
use 5.010;    # named regex captures
use base qw(Test::Class);
use Test::More;
use Getopt::Long qw(:config auto_help);
use Pod::Usage();
use autodie;

use constant DEBUG => 1;

init();

sub init {
    my ( $help, $man, $test, $input_fname, $bisect_from );
    my $module = 'core';
    my $fh;

    Getopt::Long::GetOptions(
        'help|?|h'   => \$help,
        'man'        => \$man,
        'input|i=s'  => \$input_fname,
        'date|s=s'   => \$bisect_from,
        'test'       => \$test,
        'module|m=s' => \$module,
    );
    if ($test) {
        Test::Class->runtests();
    }
    elsif ($man) {
        Pod::Usage::pod2usage( verbose => 2 );
    }
    elsif ( !$input_fname || !$bisect_from || !length($bisect_from) ) {
        print "Error: Missing input and/or isodate to start bisecting from.\n";
        Pod::Usage::pod2usage( -exitstatus => 1 );
    }
    else {
        open( $fh, '<', $input_fname );
        run( $fh, $bisect_from );
        close($fh);
    }

    return;
}

sub run {
    my ( $fh, $bisect_from ) = @_;
    my $passes;
    my $tests;

    ( $tests, $passes ) = proc_TestRunner($fh);
    if (DEBUG) {
        require Data::Dumper;
        print "Processing from $bisect_from: " . Data::Dumper->Dump( [$tests] );
    }

    return;
}

# proc_TestRunner($TestRunner_output_fh) -> ([unexpected, fails], [unexpected, passes])

sub proc_TestRunner {
    my ($fh) = @_;
    my %tests;
    my $found_module_failure_summary;

    # skip all the junk first.
    while ( !$found_module_failure_summary && ( my $line = <$fh> ) ) {
        if ( $line =~ /Module Failure summary$/i ) {
            $found_module_failure_summary = 1;
        }
    }
    if ( !$found_module_failure_summary ) {
        print "Didn't find module failure summary\n" if DEBUG;

        # Rewind to start of the file.
        seek( $fh, 0, 0 ) or die $!;
    }
    while ( my $line = <$fh> ) {
        if ( $line =~ /^   \* (?<result>F|P): (?<test>.*)$/ ) {
            $tests{ $+{test} } = $+{result};
        }
    }

    return ( \%tests );
}

sub test_proc_TestRunner : Test(2) {
    my $TestRunner_text = <<'HERE';
2 expected failures:
UnitTestContribTests has 1 expected failure (of 1):
RESTTests has 1 expected failure (of 18):
   * RESTTests::test_topic_context: Item12055: PopTopicContext in rest handler looses default context
RenameTests has 1 expected failure (of 29):
   * RenameTests::test_renameTopic_same_web_new_topic_name_slash_delim: [[Web/Topic]] fails due to Item11555

----------------------------
---++ Module Failure summary
RenameTests has 1 unexpected results (of 29):
   * F: RenameTests::test_renameTopic_new_web_same_topic_name
   * F: RenameTests::test_makeSafeTopicName
Fn_MAKETEXT has 1 unexpected results (of 14):
   * P: Fn_MAKETEXT::test_escaping
EditRowPluginSuite has 2 unexpected results (of 7):
   * P: EditRowPluginSuite::test_edit_view_default
   * P: EditRowPluginSuite::test_edit_view_no_js
MailerContribSuite has 1 unexpected results (of 11):
HERE
    open( my $fh, '<', \$TestRunner_text );
    my $tests = proc_TestRunner($fh);
    close($fh);

    is( scalar( keys %{$tests} ), 5, 'test_proc Got five things' );
    is_deeply(
        $tests,
        {
            'RenameTests::test_renameTopic_new_web_same_topic_name' => 'F',
            'RenameTests::test_makeSafeTopicName'                   => 'F',
            'Fn_MAKETEXT::test_escaping'                            => 'P',
            'EditRowPluginSuite::test_edit_view_default'            => 'P',
            'EditRowPluginSuite::test_edit_view_no_js'              => 'P',
        },
        'test_proc Test names and their unexpected results'
    );
}

package UnitTestContrib::AutoBisect::MooseTypes;
use Moose;

subtype 'UTCUnexpectedTestResult',
as 'Str',
where { $_ eq 'F' || $_ eq 'P' };

subtype 'UTCGitRevID',
as 'Str',
where { length($_) && $_ =~ /^[a-fA-F0-9]$/ };

package UnitTestContrib::AutoBisect::FoswikiTest;
use Moose;
use UnitTestContrib::AutoBisect::MooseTypes;

has 'name' => (
    is => 'ro',
    isa => 'Str',
);

has 'unexpected_result' => (
    is => 'ro',
    isa => 'UTCUnexpectedTestResult',
);

has 'good_rev' => (
    is => 'rw',
    isa => 'UTCGitRevID',
);

1;

__END__
=head1 NAME

auto-git-bisect - git bisect each failing test from TestRunner output.

=head1 SYNOPSIS

auto-git-bisect --input <TestRunner output> --date <ISO8601 date to start from>


=head1 OPTIONS

=over 8

=item B<--input>

Input file with output from TestRunner.pl containing lines like:

   * F: Something::that_failed

=item B<--date>

A date in the git revision history where the tests are good, Eg. 2013-01-28

=item B<--module>

Optionally specify the Foswiki extension under test. This will force an assumption that all failing tests apply to this extension only. Only this module will be explored in the git bisect adventure.

If B<--module> is omitted, symlinks will be followed from core/test/unit directory to discover what module a failing test belongs to.

=item B<--test>

Run auto-git-bisect's own internal unit tests

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print the manual page and exit.

=back

=head1 DESCRIPTION

For each test, B<auto-git-bisect> tries to discover the git rev. ID where the
test starts to fail.

There are some assumptions:
   * You are using a repo-per-extension checkout (rather than "fat" checkout).
   * All modules involved with testing are added as a submodule.

=cut
