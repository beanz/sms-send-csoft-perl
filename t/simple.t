#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 13;
use IO::Socket::INET;
use IO::Select;

eval { require SMS::Send; };
my $has_sms_send = !$@;
SKIP: {
  skip 'SMS::Send not available', 13 unless $has_sms_send;

  use_ok('SMS::Send::CSoft');
  use_ok('SMS::Send');
  my $sms = SMS::Send->new('CSoft',
                           _login => 'test', _password => 'pass',
                           _verbose => 0);
  ok($sms, 'SMS::Send->new with CSoft driver');

  my $serv = IO::Socket::INET->new(Listen => 1, LocalAddr => "127.0.0.1",
                                   LocalPort => 0);
  $serv or die "Failed to set up fake HTTP server\n";
  my $port = $serv->sockport;
  #print STDERR "Using port: $port\n";
  my $pid = fork;
  unless ($pid) { server($serv); }
  $serv->close;
  $SMS::Send::CSoft::URL = 'http://127.0.0.1:'.$port.'/';
  ok($sms->send_sms(text => 'text1', to => '+441234654321'),
     'CSoft successful message');
  ok(!$sms->send_sms(text => 'text2', to => '+441234654321'),
     'CSoft unsuccessful message');
  ok(!$sms->send_sms(text => 'text3', to => '+441234654321'),
     'CSoft HTTP error');

  $sms = SMS::Send->new('CSoft', _login => 'test', _password => 'pass');
  ok($sms, 'SMS::Send->new with CSoft driver - verbose');

  my $res;
  is(test_warn(sub {
                 $res = $sms->send_sms(text => 'text4', to => '+441234654321'),
               }),
     "Failed: Oops\n",
     'CSoft unsuccessful message warning');
  ok(!$res, 'CSoft unsuccessful message w/verbose mode');
  like(test_warn(sub {
                   $sms->send_sms(text => 'text5', to => '+441234654321'),
                 }),
     qr/^HTTP failure: HTTP\/1\.0 402 Payment required/,
     'CSoft HTTP error warning');
  ok(!$res, 'CSoft HTTP error w/verbose mode');

  waitpid $pid, 0;
  undef $SMS::Send::CSoft::URL;

  is(test_error(sub { SMS::Send->new('CSoft') }),
     "SMS::Send::CSoft->new requires _login parameter\n",
     'requires _login parameter');
  is(test_error(sub { SMS::Send->new('CSoft', _login => 'test') }),
     "SMS::Send::CSoft->new requires _password parameter\n",
     'requires _password parameter');

}

sub server {
  my $serv = shift;
  my $sel = IO::Select->new($serv);
  my $client;
  my $sel2;
  my $count = 1;

  foreach my $resp
    ("HTTP/1.0 200 OK\nContent-Type: text/plain\n\nMessage Sent OK\n",
     "HTTP/1.0 200 OK\nContent-Type: text/plain\n\nOops\n",
     "HTTP/1.0 402 Payment required\nContent-Type: text/plain\n\nOops\n",
     "HTTP/1.0 200 OK\nContent-Type: text/plain\n\nOops\n",
     "HTTP/1.0 402 Payment required\nContent-Type: text/plain\n\nOops\n",
    ) {

    $sel->can_read(1) or die "Failed to receive connection\n";
    $client = $serv->accept;
    $sel2 = IO::Select->new($client);
    $sel2->can_read(1) or die "Failed to receive request\n";
    my $got;
    my $bytes = $client->sysread($got, 1500);
    match($got, 'header', qr!^(.+?)\r?\n!, 'POST / HTTP/1.1');
    match($got, 'Content-Type', qr!Content-Type: ([^\n\r]+)\r?\n!,
          'application/x-www-form-urlencoded');
    match($got, 'Content-Length', qr!Content-Length: ([^\n\r]+)\r?\n!,
          '56');
    match($got, 'PIN', qr!PIN=(.*?)([\r\n;&]|$)!, 'pass');
    match($got, 'Username', qr!Username=(.*?)([\r\n;&]|$)!, 'test');
    match($got, 'SendTo', qr!SendTo=(.*?)([\r\n;&]|$)!, '441234654321');
    match($got, 'Message', qr!Message=(.*?)([\r\n;&]|$)!, 'text'.$count++);
    $client->syswrite($resp);
    $client->close;
  }

  exit;
}

sub match {
  my $text = shift;
  my $name = shift;
  my $re = shift;
  my $expect = shift;
  unless ($text =~ $re) {
    die "Request didn't match: $name\n";
  }
  my $actual = $1;
  unless ($expect eq $actual) {
    die "Request had $name with '$actual' not '$expect'\n";
  }
  return 1;
}

=head2 C<test_error($code_ref)>

This method runs the code with eval and returns the error.  It strips
off some common strings from the end of the message including any "at
<file> line <number>" strings and any "(@INC contains: .*)".

=cut

sub test_error {
  my $sub = shift;
  eval { $sub->() };
  my $error = $@;
  if ($error) {
    $error =~ s/\s+at (\S+|\(eval \d+\)(\[[^]]+\])?) line \d+\.?\s*$//g;
    $error =~ s/\s+at (\S+|\(eval \d+\)(\[[^]]+\])?) line \d+\.?\s*$//g;
    $error =~ s/ \(\@INC contains:.*?\)$//;
  }
  return $error;
}

=head2 C<test_warn($code_ref)>

This method runs the code with eval and returns the warning.  It strips
off any "at <file> line <number>" specific part(s) from the end.

=cut

sub test_warn {
  my $sub = shift;
  my $warn;
  local $SIG{__WARN__} = sub { $warn .= $_[0]; };
  eval { $sub->(); };
  die $@ if ($@);
  if ($warn) {
    $warn =~ s/\s+at (\S+|\(eval \d+\)(\[[^]]+\])?) line \d+\.?\s*$//g;
    $warn =~ s/\s+at (\S+|\(eval \d+\)(\[[^]]+\])?) line \d+\.?\s*$//g;
    $warn =~ s/ \(\@INC contains:.*?\)$//;
  }
  return $warn;
}
