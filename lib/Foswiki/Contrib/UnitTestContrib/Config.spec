# ---+ Extensions
# ---++ UnitTestContrib
# Foswiki Unit-Test Framework
# ---+++ Selenium Remote Control
# For browser-in-the-loop testing
# **STRING 30**
# The UnitTestContrib needs a username to access (i.e. edit) the testcase web and topic from the browser opened by Selenium RC.
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Username} = '';
# **PASSWORD 30**
# The password for the Selenium RC user
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Password} = '';
# **PERL 40x10**
# List the browsers accessible via Selenium RC.
# It is keyed by browser identifier - you choose the identifiers as seems sensible. Browser identifiers may only consist of alphanumeric characters.
# Examples: <code>FF3 FF2dot1OnWindows IE6_1_345 w3m</code>
# <br />
# The values are hashes of arguments to <code>Test::WWW::Selenium->new()</code>. All fields have defaults, so <pre><code>{
#   FF => {}
#}</code></pre> is a valid configuration (defaulting to Firefox on the same machine running the unit tests).
# See <a href="http://search.cpan.org/perldoc?WWW%3A%3ASelenium">the WWW::Selenium documentation</a> for more information.
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers} = {};
# **NUMBER**
# The base timeout in milliseconds, used when waiting for the browser (and by implication, the server) to respond.
# You may have to increase this if your test setup is slow.
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{BaseTimeout} = 5000;
# **PERL 40x10**
# <p>For multi-hosted Foswiki installations. Some Selenium tests need to test the Foswiki installation from different webservers or webserver configurations. For example, <code>UTF8Tests</code> needs to verify against different <code>Foswiki::Engines</code> such as the default CGI engine, ModFastCGIEngineContrib and ModPerlEngineContrib. These require different apache configurations made accessible from different hostnames or URL paths.</p>
# <p>It is keyed by Foswiki cfg identifier - choose identifiers as seems sensible. Foswiki cfg identifiers may only consist of alphanumeric characters.</p>
# <p>Example identifiers: <code>default FastCGI ModPerl</code></p>
# <p>The values are hashrefs of <code>$Foswiki::cfg</code> key/value pairs that need to be set for accessing the Foswiki host/path. Typical keys are <code>PubUrlPath, ScriptUrlPath</code> and <code>DefaultUrlHost</code>.</p>
# <p>A default Foswiki cfg named <code>default</code> will always exist (even if <code>{SeleniumRc}{Foswikis}</code> is empty/undef), which will contain <code>DefaultUrlHost PermittedRedirectHostUrls ScriptUrlPath ScriptUrlPaths PubUrlPath</code> key/values from your existing <code>$Foswiki::cfg</code></p>
# <p>Example:<pre><code>{
#   FastCGI => {
#       ScriptUrlPath => '/foswiki/fastcgi/bin',
#       PubUrlPath    => '/foswiki/fastcgi/pub'
#   }
#}</code></pre> is a valid setting which might be the UrlPath keys necessary to access a Foswiki installation via <code>mod_fcgid</code> apache configuration (where the "default" configuration might be the standard, plain-old-CGI config).
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Foswikis} = {};
