# Contrib for Foswiki Collaboration Platform, http://Foswiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Contrib::UnitTestContrib;

use strict;
use warnings;

our $VERSION = '$Rev$';
our $RELEASE = '1.1';
our $SHORTDESCRIPTION = 'Foswiki Unit-Test Framework';

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

Contribs don't normally use an initPlugin(), and on a 'normal' installation
with UnitTestContrib installed, this init handler should remain unused.

UnitTestContrib's WebserverTests, however, need to verify the versions of
perl modules (Eg. CGI.pm, FCGI.pm, etc) as a part of its testing & reporting
for the framework which starts & configures webservers for Selenium-based tests

We can't rely on the unit test environment to report the same module versions
as those which would be found inside the webserver environment (in theory, the
temporary Foswiki installations we want to run Selenium against might not even
be running from the same checkout as the unit test environment).

So the WebserverTests write a new LocalSite.cfg which (among other things)
enables UnitTestContrib as a plugin, which in turn registers rest handlers which
can be called over http

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    require Foswiki::Contrib::UnitTestContrib::RestHandlers;
    Foswiki::Contrib::UnitTestContrib::RESTHandlers::register();

    return 1;
}
