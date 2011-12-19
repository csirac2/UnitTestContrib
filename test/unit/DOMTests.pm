package DOMTests;
use strict;
use warnings;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use Assert;
use Data::Dumper;
use Benchmark qw(:hireswallclock);
use Foswiki::DOM();
use constant TRACE => 0;

sub test_verbatim {
    my ($this) = @_;

    Foswiki::DOM->new(<<'HERE');
a<verbatim class="tml">b
<verbatim class="html">x
0\
1\
</verbatim>y</verbatim>z
HERE

    return;
}

1;
