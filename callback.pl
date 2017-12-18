#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use YAML::XS 'LoadFile';
use JSON;
use Path::Tiny;
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
	my ($auth_bearer, $playlist_id, $my_id) = @_;
	my $response = `curl -s -H "Authorization: Bearer $auth_bearer" https://api.spotify.com/v1/users/$my_id/playlists/$playlist_id`;
	return $response;
}

sub get_new_token {
	my ($code, $oauth_client_id, $oauth_client_secret, $grant_type) = @_;
	my $refresh = "";
	if ($grant_type =~ /^refresh_token$/) {
		$refresh = "&" . $grant_type . "=" . $code;
	}
	my $response = `curl --data "grant_type=$grant_type&code=$code&redirect_uri=http://138.197.50.244/spotify/callback.pl&client_secret=$oauth_client_secret&client_id=$oauth_client_id$refresh" "https://accounts.spotify.com/api/token"`;
	my $token = decode_json($response)->{access_token};
	my $refresh_token = decode_json($response)->{refresh_token};
	my %tokens;
	$tokens{'token'} = $token // "error";
	$tokens{'refresh_token'} = $refresh_token // "error_r";
	write_new_tokens($tokens{'token'}, $tokens{'refresh_token'});
	return %tokens;
}

sub write_new_tokens {
	my ($token, $r_token) = @_;
	path('token.txt')->spew($token);
	path('token.txt')->chmod(0777);
	path('r_token.txt')->spew($r_token);
	path('r_token.txt')->chmod(0777);
	return 1;
}

sub print_a_playlist {
	my ($auth_bearer, $playlist_id, $my_id) = @_;
	my $data = decode_json(get_a_playlist($auth_bearer, $playlist_id, $my_id));
	print "Playlist Name: " . $data->{name} . "</br>\n";
	my @song_list = @{$data->{tracks}{items}};
	print "Songs (x" . scalar(@song_list) . "): </br>\n";
	foreach my $song (@song_list) {
		print $song->{track}{name} . " by " . $song->{track}{album}{artists}[0]{name} . "</br>\n";
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
	print $cgi->header(-type => "text/html");
	my $config = LoadFile('/var/www/html/spotify/.config.yaml');

	my $oauth_client_id = $config->{oauth}{client_id};
	my $oauth_client_secret = $config->{oauth}{client_secret};

	if ($cgi->param('code')) {
		my %tokens = get_new_token($cgi->param('code'), $oauth_client_id, $oauth_client_secret, 'authorization_code');
		path('token.txt')->spew($tokens{token});
		path('token.txt')->chmod(0777);
		path('r_token.txt')->spew($tokens{refresh_token});
		path('r_token.txt')->chmod(0777);
		#print "GOT FRESH TOKEN: " . $tokens{token} . "</br>\n</br>\n";
		print "Got a fresh token.</br>\n";
	}

	my $token = path('token.txt')->slurp;
	my $r_token = path('r_token.txt')->slurp;
	my $id;
	if (decode_json(get_me($token))->{error}) {
		print "Invalid Token. Need to refresh.</br>\n";
		print "Using R_TOKEN: " . $r_token . "</br>\n";
		print my %t = get_new_token($r_token, $oauth_client_id, $oauth_client_secret, 'refresh_token');
		print $t{token} . "</br>\n";
		print "Got new token.</br>\n";
		if (decode_json(get_me($t{token}))->{error}) {
			print "ERROR: Recieved tokens are invalid.\nPlease visit NewCode.html to retrieve a fresh set of tokens.</br>\n";
			exit;
		}
	}
	else {
		print "Token OK</br>\n";
		print "Hello ";
		print $id = decode_json(get_me(path('token.txt')->slurp))->{id};
		print "</br>\n<hr/></br>\n";
		if ($cgi->param('method') =~ /^print_my_playlist$/) {
			print_my_playlists(path('token.txt')->slurp);
		}
	}

	if ($cgi->param('method') =~ /^print_a_playlist$/) {
		print_a_playlist(path('token.txt')->slurp, $cgi->param('playlist'), $id)
	}

	print_html_forms();

}
