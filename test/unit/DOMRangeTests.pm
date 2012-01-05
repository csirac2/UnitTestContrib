package DOMRangeTests;
use strict;
use warnings;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use Assert;
use Data::Dumper;
use Benchmark qw(:hireswallclock);
use Foswiki::DOM();
use constant TRACE => 0;

sub ASSERT_SANITY { 0 }

sub tear_down {
    my ($this) = @_;

    $this->SUPER::tear_down();
    foreach my $key ( keys %{ $this->{random_lists} } ) {
        delete $this->{random_lists}{$key};
    }
    delete $this->{random_lists};

    return;
}

sub _get_random_data {
    my ( $this, $size ) = @_;

    if ( !exists( $this->{random_lists}{$size} ) ) {
        my @random_list;

        foreach my $i ( 0 .. $size ) {
            push( @random_list, int( rand($size) ) );
        }
        $this->{random_lists}{$size} = \@random_list;
    }

    return @{ $this->{random_lists}{$size} };
}

sub _sort_perl {
    my (@input) = @_;

    return sort(@input);
}

sub _sort_insertion {
    my (@input) = @_;
    my @output = ( shift(@input) );

    while ( scalar(@input) ) {
        my $item = shift(@input);
        my $output_i;

        if ( $item <= $output[0] ) {
            unshift( @output, $item );
        }
        elsif ( $item >= $output[-1] ) {
            push( @output, $item );
        }
        else {
            my $n_output = scalar(@output);
            my $search_i = int( $n_output / 2 );
            my $prev_search_i;
            my $search_i_delta = $search_i;

            # Binary-search for the correct place to insert $item into @output
            while ( !defined $output_i ) {
                my $search_item = $output[$search_i];

                if ( $item < $search_item ) {
                    my $new_search_i_delta = $search_i_delta / 2;

                    if ( $new_search_i_delta <= 1 ) {
                        if ( $item < $output[ $search_i - 1 ] ) {
                            $output_i = $search_i - 1;
                        }
                        else {
                            $output_i = $search_i;
                        }
                    }
                    else {
                        $search_i_delta = $new_search_i_delta;
                        $search_i -= int($search_i_delta);
                    }
                }
                elsif ( $item >= $search_item ) {
                    my $new_search_i_delta = $search_i_delta / 2;

                    if ( $new_search_i_delta <= 1 ) {
                        if ( $item >= $output[ $search_i + 1 ] ) {
                            $output_i = $search_i + 1;
                        }
                        else {
                            $output_i = $search_i;
                        }
                    }
                    else {
                        $search_i_delta = $new_search_i_delta;
                        $search_i += int($search_i_delta);
                    }
                }
            }
            ASSERT( $item >= $output[ $output_i - 1 ] ) if ASSERT_SANITY;
            ASSERT( $item < $output[ $output_i + 1 ] )  if ASSERT_SANITY;

            # array splicing is expensive, a linked list would would suck less
            # splice( @output, $output_i, 0, $item );
        }
    }

    return @output;
}

sub _sort_timing {
    my ( $this, $cycles, $data_fn, $data_size, $sort_fn ) = @_;
    my $benchmark;

    # prime the data, so we get accurate timing
    $data_fn->( $this, $data_size );
    $benchmark = timeit(
        $cycles,
        sub {
            $sort_fn->( $data_fn->( $this, $data_size ) );
        }
    );

    print "Sorted list of size $data_size:\n" . timestr($benchmark) . "\n";

    return;
}

# Briefly curious about just how slow an insertion sort/build-the-tree-as-we-go
# approach would be; the question is: do we accumulate the claimed syntax
# regions (ranges) first before building a (sorted) tree (which could leverage
# the perl sort builtin), or is a continuous insertion-sort approach less
# expensive overall. Eventually, after I wrote these tests, I found
# http://www.sysarch.com/Perl/sort_paper.html
sub test_timing_random_sort_perl {
    my ($this) = @_;

    $this->_sort_timing( 200, \&_get_random_data, 1000, \&_sort_perl );

    return;
}

sub test_timing_random_sort_insertion {
    my ($this) = @_;

    $this->_sort_timing( 20, \&_get_random_data, 1000, \&_sort_insertion );

    return;
}

sub test_simple {
    my ($this) = @_;
    my $dom = Foswiki::DOM->new(<<'HERE');
a<verbatim class="tml">b
<verbatim class="html">x
0\
1\
</verbatim>y</verbatim>z
HERE

    $dom->range_add( 0,  0,  'outside-content1' );
    $dom->range_add( 1,  22, 'start-tag' );
    $dom->range_add( 23, 64, 'content' );
    $dom->range_add( 65, 75, 'close-tag' );
    $dom->range_add( 76, 77, 'outside-content2' );
    $dom->range_add( 1,  75, 'verbatim-thing' );
    $dom->ranges_containing(2);

    return;
}

1;
