#!/usr/bin/perl

use strict;
use warnings;

use JSON;
use HTTP::Request;
use LWP::UserAgent;
use Data::Dumper;		# debugging, ok to remove when done.


my $config_file="newrelic_config.txt";
my $data_post_url="http://platform-api.newrelic.com/platform/v1/metrics";
my ($license_key, $name, $guid, $version);


sub parse_config_file() {
	open FILE, "<$config_file" or die $!;
	while (my $line = <FILE>) {
		chomp($line);
		if ($line =~ /^license_key=(.*)/) { $license_key = $1; }
		if ($line =~ /^name=(.*)/) { $name = $1; }
		if ($line =~ /^guid=(.*)/) { $guid = $1; }
		if ($line =~ /^version=(.*)/) { $version = $1; }
	}
	if (-z $license_key) { die "no license key found in config file $config_file\n"; }
	if (-z $guid) { die "no GUID found in config file $config_file\n"; }
	if (-z $name) { die "no GUID found in config file $config_file\n"; }
	if (-z $version) { die "no version found in config file $config_file\n"; }

	return ($license_key, $guid, $name, $version);
}


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

sub get_component_data() {
	my %component_hash = (
		'Component/test/metric1[units]' => 4.5,
		'Component/fieldtest/fieldsmetric1[otherunits]' => {
			'min' => 2,
			'max' => 10,
			'total' => 12,
			'count' => 2,
			'sum_of_squares' => 144
		});
	print "component hash: [" . Dumper(\%component_hash) . "]\n"; #DEBUG
	my @component_array = ( 
		'name', $name,
		'guid', $guid,
		'duration', 60, # FIXME hardcoded for now
		'metrics', \%component_hash
	);
	print "component array: [" . Dumper(\@component_array) . "]\n"; #DEBUG
	return \@component_array;
}

($license_key, $guid, $name, $version) = parse_config_file();
my %post_data = (
	'agent' => get_agent_data(),
	'components' => get_component_data()
);
print "post data: [" . Dumper(%post_data) . "]\n"; #DEBUG
my $json_data = encode_json(\%post_data);
print "json data: [" . Dumper($json_data) . "]\n"; #DEBUG
my $req = HTTP::Request->new( 'POST', $data_post_url );
$req->header( 'Content-Type' => 'application/json' );
$req->header( 'X-License-Key' => $license_key);
$req->header( 'Accept' => "application/json");
$req->content( $json_data );

my $ua       = LWP::UserAgent->new();
$ua->ssl_opts( verify_hostname => 0 );
my $response = $ua->request($req);
if ($response->is_success()) {
	print $response->decoded_content();
} else {
	print $response->status_line . "\n";
}

	
__END__
