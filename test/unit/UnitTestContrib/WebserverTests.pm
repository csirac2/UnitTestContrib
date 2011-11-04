package WebserverTests;
use strict;
use warnings;

use Unit::TestCase ();
our @ISA = qw( Unit::TestCase );

use Error qw( :try );
use Unit::Webserver();
use Data::Dumper;

my $test_web = 'Temporary' . __PACKAGE__ . 'TestWeb';
my $builtgroup_serverconfigsvariants;
my @group_serverconfigs;

sub finish {
    my ($this) = @_;

    $this->{ServerConfigName}        = undef;
    $this->{ServerConfigVariantName} = undef;
    $this->{ServerConfigs}           = undef;

    return $this->SUPER::finish();
}

sub new {
    my ( $class, @args ) = @_;
    my $this = $class->SUPER::new(@args);

    $this->{test_web}   = $test_web;
    $this->{test_topic} = 'TestTopic' . $class;
    $this->fixgroup_serverconfigs();

    return $this;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    return;
}

sub tear_down {
    my $this = shift;

    $this->assert($this->{ServerObj});
    $this->{ServerObj}->finish();
    $this->{ServerObj} = undef;

    # Always do this, and always do it last
    return $this->SUPER::tear_down();
}

sub verify_sanity {
    my ($this) = @_;
    my $name = $this->{ServerConfigName};
    my $variant = $this->{ServerConfigVariantName};

    $this->assert( $name );
    $this->assert( $variant );
    $this->assert( ref($this->{ServerConfigs}{$name}) eq 'HASH');

    return;
}

sub fixture_groups {
    my ( $this, $suite ) = @_;
    my @groups =
      ( [ $this->fixgroup_serverconfigs() ], $this->SUPER::fixture_groups() );

    return @groups;
}

sub get_server_configs {
    my ($this) = @_;
    my $servers = $Foswiki::cfg{UnitTestContrib}{Webservers};
    my %configs;

    $this->assert( ref($servers) eq 'HASH' );

    while ( my ( $name, $config ) = each %{$servers} ) {
        $this->assert( ref($config) eq 'HASH' );
        if ( scalar( keys %{$config} ) ) {
            while ( my ( $key, $value ) = each %{$config} ) {
                if ( $key =~ /^_(.+)$/ ) {
                    $configs{$name}{server}{$1} = $value;
                }
                else {
                    $configs{$name}{LocalSite}{$key} = $value;
                }
            }
        }
        else {
            $this->assert_str_equals( 'ApacheHtAccess', $name );
            $configs{$name}{server} = {

                #restart_cmd => 'sudo service apache2 restart',
                type => $name
            };
        }
        $this->assert( scalar( keys %{ $configs{$name}{server} } ) );
    }
    $this->assert( scalar( keys %configs ) );

    return %configs;
}

sub get_merged_localsite {
    my ($this, $name) = @_;
    my %conf;
    $this->assert($this->{ServerConfigs}{$name});

    if ( $this->{ServerConfigs}{$name}{LocalSite} ) {
        $this->assert( ref( $this->{ServerConfigs}{$name}{LocalSite} ) eq 'HASH' );
        %conf = ( %Foswiki::cfg, %{ $this->{ServerConfigs}{$name}{LocalSite} } );
    }
    else {
        %conf = %Foswiki::cfg;
    }

    return %conf;
}

sub fixgroup_serverconfigs {
    my ($this) = @_;
    my %configs = $this->get_server_configs();

    $this->{ServerConfigs} = \%configs;
    if ( not $builtgroup_serverconfigsvariants ) {
        while ( my ( $name, $config ) = each %{ $this->{ServerConfigs} } ) {
            my $type = $config->{server}{type};
            $this->assert($type);
            my $serverclass = "Unit::Webserver::$type";
            my @variants;

            $this->assert($type);
            $this->assert( eval "require $serverclass; 1;", $@ );
            @variants = $serverclass->variants();
            $this->assert( scalar(@variants) );
            foreach my $variant (@variants) {
                my $fn = $name . '_' . $variant;

                push( @group_serverconfigs, $fn );
                no strict 'refs';
                *{$fn} = sub {
                    my %LocalSite = $this->get_merged_localsite($name);
                    $this->{ServerConfigName} = $name;
                    $this->{ServerConfigVariantName} = $variant;
                    $this->{ServerObj} = $serverclass->new($name, $type, $variant, $config->{server}, \%LocalSite);

                    return;
                };
                use strict 'refs';
            }
        }
        $builtgroup_serverconfigsvariants = 1;
    }

    return @group_serverconfigs;
}

1;
