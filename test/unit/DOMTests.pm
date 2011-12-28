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

sub test_verbatim_nested {
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

sub test_verbatim_stray_open_tag {
    my ($this) = @_;
    my $input = <<'HERE';
a<verbatim><verbatim class="tml">b
<verbatim class="html">x
0\
1\
</verbatim>y</verbatim>z
HERE
    $this->annotate("Length of input: " . length($input) . "\n");
    Foswiki::DOM->new($input);

    return;
}

sub test_verbatim_stray_close_tag {
    my ($this) = @_;

    Foswiki::DOM->new(<<'HERE');
a<verbatim class="tml">b
<verbatim class="html">x
0\
1\
</verbatim>y</verbatim>z</verbatim>
HERE

    return;
}

sub test_verbatim_stray_close_tag {
    my ($this) = @_;

    Foswiki::DOM->new(<<'HERE');
<a \
href="\
something\
"\
>b</a>

Trai\ 
ling white\ 
space

Dou\\ble sla\\shes
HERE

    return;
}

sub test_VAR {
    my ($this) = @_;

    Foswiki::DOM->new('%VAR%');
}

sub test_VAR_params {
    my ($this) = @_;

    Foswiki::DOM->new(<<'HERE');
%VAR{a="b" c="d
    with
    newlines\
 escaped"}%
HERE
}

sub test_nested_VAR {
    my ($this) = @_;

    Foswiki::DOM->new(<<'HERE');
%VAR{a="b" c="d
    with %NESTED% %MACROS%
    newlines\
 escaped"}%

%%FOO%RCH%{
}%
HERE
}

1;
