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

sub test_simple {
    my ($this) = @_;
    my $dom = Foswiki::DOM->new(<<'HERE');
a<verbatim class="tml">b
<verbatim class="html">x
0\
1\
</verbatim>y</verbatim>z
HERE

    $dom->range_add(0, 0, 'outside-content1');
    $dom->range_add(1, 22, 'start-tag');
    $dom->range_add(23, 64, 'content');
    $dom->range_add(65, 75, 'close-tag');
    $dom->range_add(76, 77, 'outside-content2');
    $dom->range_add(1, 75, 'verbatim-thing');
    $dom->ranges_containing(2);

    return;
}

1;
