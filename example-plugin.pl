#!/usr/bin/perl

use strict;
use warnings;

use JSON;
use HTTP::Request;
use LWP::UserAgent;
use Data::Dumper;		# debugging, ok to remove when done.


my $default_duration = 60;	# seconds
my $config_file="newrelic_config.txt";
my $data_post_url="https://platform-api.newrelic.com/platform/v1/metrics";
my ($license_key, $name, $guid, $version, $ssl, $use_proxy, $proxy);

my %dataharvest;
my $recollectmetrics=0;


sub parse_config_file() {
	open FILE, "<$config_file" or die $!;
	while (my $line = <FILE>) {
		chomp($line);
		if ($line =~ /^license_key=(.*)/) { $license_key = $1; }
		if ($line =~ /^name=(.*)/) { $name = $1; }
		if ($line =~ /^guid=(.*)/) { $guid = $1; }
		if ($line =~ /^version=(.*)/) { $version = $1; }
		if ($line =~ /^ssl=(.*)/) { $ssl = $1; }
		if ($line =~ /^use_proxy=(.*)/) { $use_proxy = $1; }
		if ($line =~ /^proxy=(.*)/) { $proxy = $1; }
	}
	if (-z $license_key) { die "no license key found in $config_file\n"; }
	if (-z $guid) { die "no GUID found in $config_file\n"; }
	if (-z $name) { die "no GUID found in $config_file\n"; }
	if (-z $version) { die "no version found in $config_file\n"; }
	if ($use_proxy) {
		if ( -z $proxy ) { die "asked to use null proxy\n"; }
	}	
	if (! $ssl) {
		$data_post_url =~ s/https/http/; 
		warn "not using SSL!";
	}

	return ($license_key, $guid, $name, $version, $use_proxy, $proxy);
}


# populate the JSON "agent" stanza.
# This should be fairly static, all read from configfile/system.

sub get_agent_data() {
	my $hostname = `hostname`;
	chomp($hostname);
	my %agent_hash = ( 
		'host' => $hostname,
		'pid' => $$,
		'version' => $version
	);
	print "agent data hash: [" . Dumper(%agent_hash) . "]\n"; # DEBUG
	return \%agent_hash;
}

# populate the JSON "components" stanza.  You'll need to change this,
# very carefully since our server's JSON parser is pretty picky.

sub get_component_data() {
	my %component_subhash = (
        'Component/tickets/total[open tickets]' => $dataharvest{'total'},
        'Component/tickets/tier2[tier 2 tickets]' => $dataharvest{'tier2'});

# if you want to report other fields for a metric, here's how to do it.
#		'Component/fieldtest/fieldsmetric1[otherunits]' => {
#			'min' => 2,
#			'max' => 10,
#			'total' => 12,
#			'count' => 2,
#			'sum_of_squares' => 144
#		});

	print "component subhash: [" . Dumper(\%component_subhash) . "]\n"; #DEBUG
	my %component_hash = ( 
		'name' => $name,
		'guid' => $guid,
		'duration' => 60, # FIXME hardcoded for now
		'metrics' => \%component_subhash
	);
	print "component hash: [" . Dumper(\%component_hash) . "]\n"; #DEBUG
	return \%component_hash;
}

($license_key, $guid, $name, $version, $use_proxy, $proxy) =parse_config_file();

# JSON.pm and our data format require some very specific object hierarchies:  
# components must be an [ "array" ], but everything else must be a { "hash" }.
# Failure to set this up just right leads to an array of HTTP error returns.

my $duration = $default_duration;
while (1) {
	# if this metric was a "# changed" versus a count, we'd want to add instead
	# of replacing in case we didn't get to post the last #.
	# if ($recollectmetrics) {
	#	$dataharvest{'total'} += system("ruby /Users/fool/code/newrelic-perl-plugin-example/zendesk_total.rb");
	#	$dataharvest{'tier2'} += system("ruby /Users/fool/code/newrelic-perl-plugin-example/zendesk_tier2.rb");
	#} else { 

	$dataharvest{'total'} = `ruby /Users/fool/code/newrelic-perl-plugin-example/zendesk_total.rb`;
	$dataharvest{'tier2'} = `ruby /Users/fool/code/newrelic-perl-plugin-example/zendesk_tier2.rb`;
	# these have to be integers for JSON.pm to treat them as numbers :/
	$dataharvest{'total'} += 0;
	$dataharvest{'tier2'} += 0;

	#}

	my @component_array = (get_component_data());
	my %post_data = (
		'agent' => get_agent_data(),
		'components' => \@component_array
	);
	print "post data: [" . Dumper(%post_data) . "]\n"; #DEBUG
	my $json_data = encode_json(\%post_data);
	print "json data: [" . Dumper($json_data) . "]\n"; #DEBUG

# must use HTTP::Request to make sure to send Content-Type: application/json
	my $req = HTTP::Request->new( 'POST', $data_post_url );
	$req->header( 'Content-Type' => 'application/json' );
	$req->header( 'X-License-Key' => $license_key);
	$req->header( 'Accept' => "application/json");
	$req->content( $json_data );

	my $ua       = LWP::UserAgent->new();
	if ($use_proxy) {
		$ua->proxy(['https', 'http'], $proxy);
	}
# for testing purposes, don't do a full-CA-chain verification
	$ua->ssl_opts( verify_hostname => 0 );
	my $response = $ua->request($req);
	if ($response->is_success()) {
		print $response->decoded_content();
		$duration=$default_duration; # reset in case it had been multiplied.
    $recollectmetrics = 0;
	} else {
		print "HTTP error posting metrics: " . $response->status_line . "\n";
		if (($response->code) >= 500) {
			print "Many 5xx errors are transient. We'll try again soon.\n";
			$duration += 60;
      $recollectmetrics = 1;
		} elsif ((400 <= $response->code) && ($response->code < 500)) {
			die "4xx errors mean there is a problem with your POST,\nperhaps bad license_key or unacceptable JSON?\n";
		} else {
			die "That's some kinda crazy error, exiting."
		}
	}
	sleep(60);	# wait a minute to poll again.
}

	
__END__
