#!/usr/bin/perl

use strict;
use warnings;
use LWP::UserAgent;
use HTML::Entities;
use Date::Parse;

my $key_file = './pushover-appkey.txt';
my $users_file = './pushover-userkeys.txt';

open my $key_handle, '<', $key_file or die $!;
my $key = <$key_handle>; chomp $key;
close $key_handle;

my $pushover_url = 'https://api.pushover.net/1/messages.json';

my $mspa_url = 'http://www.mspaintadventures.com/rss/rss.xml';

my $save_state_file = './savestate.txt';

my $rss_item_regex = qr%<item>\s*<title>(.*)</title>\s*<description>(.*)</description>\s*<link>(.*)</link>\s*<guid[^>]*>(.*)</guid>\s*<pubDate>(.*)</pubDate>\s*</item>%;

my $browser = LWP::UserAgent->new;

my $previous_date = 0;

if (-e $save_state_file) {
	open my $fh, '<', $save_state_file or die $!;
	$previous_date = 0 + <$fh>;
	close $fh;
}

while(1) {
	# load user list every time, so it updates on the fly
	open my $users_handle, '<', $users_file or die $!;
	my @users = <$users_handle>; chomp @users;
	close $users_handle;

	my $response = $browser->get($mspa_url);

	my $content = $response->content;

	$content = decode_entities($content);

	my @fresh_items = ();
	
	while($content =~ m/$rss_item_regex/g) {
		my ($title, $description, $link, $guid, $pubDate) = ($1,$2,$3,$4,$5);
#		print "title $title link $link guid $guid pubdate $pubDate\n";
		
		my $item_date = str2time($pubDate);
		
		if ($item_date > $previous_date) {
			my ($number) = ($link =~ m:p=(\d{6}):);
			unshift @fresh_items, { title => $title, number => $number, link => $link, date => $pubDate};
		}
	}

	if (@fresh_items) {
		my $first = $fresh_items[0];
		my $last = $fresh_items[-1];
		#print "Homestuck Update - [", $first->{number}, "~", $last->{number}, "] ", $first->{title}, $/;
		
		for my $user (@users) {
			while (1) {
				my $response = $browser->post (
						$pushover_url,
						[
							'token' => $key,
							'user' => $user,
							'message' => "[" . $first->{number} . "~" . $last->{number} . "] " . $first->{title},
							'url' => $first->{link},
							'timestamp' => time,
							'priority' => 1
						]
					);
				print $response->message;
				if ($response->code >= 400 && $response->code <= 499) {
					die ("Failed to post: " . $response->code . " : " . $response->message);
				}
				if ($response->code >= 500 && $response->code <= 599) {
					print "Failed to post: " , $response->code , " : " , $response->message, " - will retry in 10s\n";
					sleep(10);
					next;
				}
				last;
			}
		}
		
		$previous_date = str2time($last->{date});
		
		open my $fh, '>', $save_state_file or die $!;
		print $fh $previous_date,$/;
		close $fh;
	}

	sleep(60);
}
=pod
my $notification = {
	'from' => 'Boxcar LWP Test',
	'msg'  => 'This is a test: Boxcar User Token via Perl LWP at ' . localtime(time),
	'url'  => 'http://boxcar.io/devices/providers/' . $api->{key} . '/notifications',
	};

my $browser  = LWP::UserAgent->new;
my $response = $browser->post (
	$notification->{url}, [
		'email'                                => $email_md5,
		'secret'                               => $api->{secret},
		'notification[from_screen_name]'       => $notification->{from},
		'notification[message]'                => $notification->{msg},
		'notification[from_remote_service_id]' => time, # Just a unique placeholder
		'notification[redirect_payload]'       => $email_md5,
		'notification[source_url]'             => 'http://your.url.here',
		'notification[icon_url]'               => 'http://your.url.to/image.here',
		],
	);

for my $key (keys %{$response}) { print $key . ': ' . $response->{$key} . "\n"; }

exit;

__END__
=cut
