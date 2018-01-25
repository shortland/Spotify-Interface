#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use CGI::Cookie;
use CGI::Carp qw(fatalsToBrowser);
use YAML::XS 'LoadFile';
use JSON;
use MIME::Base64;

sub get_me {
	my ($auth_bearer) = @_;
	my $response = `curl -s -H "Authorization: Bearer $auth_bearer" https://api.spotify.com/v1/me`;
	return $response;
}

sub get_my_playlists {
	my ($auth_bearer) = @_;
	my $response = `curl -s -H "Authorization: Bearer $auth_bearer" https://api.spotify.com/v1/me/playlists`;
	return $response;
}

sub get_a_playlist {
	my ($auth_bearer, $playlist_id, $my_id, $offset) = @_;
	my $response = `curl -s -H "Authorization: Bearer $auth_bearer" https://api.spotify.com/v1/users/$my_id/playlists/$playlist_id/tracks?offset=$offset`;
	return $response;
}

sub get_new_token {
	my ($code, $oauth_client_id, $oauth_client_secret, $grant_type, $host, $path) = @_;
	my $refresh = "";

	if ($grant_type =~ /^refresh_token$/) {
		$refresh = "&" . $grant_type . "=" . $code;
	}

	my $response = `curl --data "grant_type=$grant_type&code=$code&redirect_uri=$host/$path/callback.pl&client_secret=$oauth_client_secret&client_id=$oauth_client_id$refresh" "https://accounts.spotify.com/api/token"`;
	my $token = decode_json($response)->{access_token};
	my $refresh_token = decode_json($response)->{refresh_token};
	my %tokens;
	$tokens{'token'} = $token // "errorT";
	return %tokens;
}

sub print_a_playlist {
	my ($auth_bearer, $playlist_id, $my_id, $offset) = @_;
	my $data = decode_json(get_a_playlist($auth_bearer, $playlist_id, $my_id, $offset));
	my @song_list = @{$data->{items}};

	foreach my $song (@song_list) {
		print $song->{track}{name} . " by " . $song->{track}{album}{artists}[0]{name} . "</br>\n";
	}

	if (defined $data->{next}) {
		$offset += 100;
		print_a_playlist($auth_bearer, $playlist_id, $my_id, $offset);
	}
}

sub print_my_playlists {
	my ($auth_bearer) = @_;
	my $data = decode_json(get_my_playlists($auth_bearer));
	my @items = @{$data->{items}};

	print "Found " . scalar(@items) . " playlists:</br>\n";

	foreach my $item (@items) {
		print "<p>&nbsp;&nbsp;Name: " . $item->{name} . "</p>\n";
		print "<p>&nbsp;&nbsp;Songs: x" . $item->{tracks}{total} . "</p>\n";
		print "<p>&nbsp;&nbsp;ID: " . $item->{id} . "</p>\n";
		my $playlist_url = $item->{id};

		print qq{
			<form action='' method='get'>
				<input type='hidden' name='method' value='print_a_playlist'/>
				<input type='hidden' name='playlist' value='$playlist_url'/>
				<input type='submit' value='Show Songs'/>
			</form>
		};
		print "<hr>\n";
	}

}

sub print_html_forms {
	print my $html = qq{
		<form action='' method='get'>
			<input type='hidden' name='method' value='print_my_playlist'/>
			<input type='submit' value='Show Playlists'/>
		</form>
	};
}

BEGIN {
	my $cgi = CGI->new;
	my %cookies = fetch CGI::Cookie;
	my $cookie_token = 'ne';

	if ($cookies{'cookie_token'}) {
		$cookie_token = $cookies{'cookie_token'}->value;
	}
	
	my $config = LoadFile('.config.yaml');
	my $oauth_client_id = $config->{oauth}{client_id};
	my $oauth_client_secret = $config->{oauth}{client_secret};
	my $host = $config->{server}{host};
	my $path = $config->{server}{path};
	my $token;

	if ($cgi->param('code')) {
		my %tokens = get_new_token($cgi->param('code'), $oauth_client_id, $oauth_client_secret, 'authorization_code', $host, $path);
		my $cookie_token = new CGI::Cookie(-name => 'cookie_token', -value => "$tokens{token}", -expires => '+3M');
		print "Set-Cookie: $cookie_token\n";
		print $cgi->header(-type => "text/html");
		print "Got & set new Token.</br>\n";
		$token = $tokens{token};
	}
	else {
		print $cgi->header(-type => "text/html");
		$token = $cookie_token;
	}

	my $id;

	if (decode_json(get_me($token))->{error}) {
		print "Expired Token. Please visit <a href='NewCode.html'>NewCode.html</a> to retrieve a new Token.";
	}
	else {
		print "Hello ";
		print $id = decode_json(get_me($token))->{id};
		print "</br>\n<hr/></br>\n";
		if ($cgi->param('method') =~ /^print_my_playlist$/) {
			print_my_playlists($token);
		}
	}

	if ($cgi->param('method') =~ /^print_a_playlist$/) {
		print_a_playlist($token, $cgi->param('playlist'), $id, 0);
	}

	if ($cgi->param('method') !~ /^print_my_playlist$/) {
		print_html_forms();
	}
}
