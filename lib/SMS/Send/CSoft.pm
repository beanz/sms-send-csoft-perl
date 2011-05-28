use strict;
use warnings;
package SMS::Send::CSoft;

# ABSTRACT: SMS::Send driver to send via the Connection Software service

=head1 SYNOPSIS

  # Create a testing sender
  my $send = SMS::Send->new( 'CSoft',
                             _login => 'csoft username',
                             _password => 'csoft pin' );

  # Send a message
  $send->send_sms(
     text => 'Hi there',
     to   => '+61 (4) 1234 5678',
  );

=head1 DESCRIPTION

SMS::Send driver for sending SMS messages with the Connection
Software (http://www.csoft.co.uk/) SMS service.

=cut

use 5.006;
use SMS::Send::Driver;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

our @ISA = qw/SMS::Send::Driver/;
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $URL = 'https://www.csoft.co.uk/sendsms';

=method CONSTRUCTOR

This constructor should not be called directly.  See L<SMS::Send> for
details.

=cut

sub new {
  my $pkg = shift;
  my %p = @_;
  exists $p{_login} or die $pkg."->new requires _login parameter\n";
  exists $p{_password} or die $pkg."->new requires _password parameter\n";
  exists $p{_verbose} or $p{_verbose} = 1;
  my $self = \%p;
  bless $self, $pkg;
  $self->{_ua} = LWP::UserAgent->new();
  return $self;
}

sub send_sms {
  my $self = shift;
  my %p = @_;
  $p{to} =~ s/^\+//;
  $p{to} =~ s/[- ]//g;

  my $response = $self->{_ua}->post($URL,
                                    {
                                     Username => $self->{_login},
                                     PIN => $self->{_password},
                                     Message => $p{text},
                                     SendTo => $p{to},
                                    });
  unless ($response->is_success) {
    my $s = $response->as_string;
    warn "HTTP failure: $s\n" if ($self->{_verbose});
    return 0;
  }
  my $s = $response->as_string;
  $s =~ s/\r?\n$//;
  $s =~ s/^.*\r?\n//s;
  unless ($s =~ /Message Sent OK/i) {
    warn "Failed: $s\n" if ($self->{_verbose});
    return 0;
  }
  return 1;
}

1;

=head1 SEE ALSO

SMS::Send(3), SMS::Send::Driver(3)

Connection Software Website: http://www.csoft.co.uk/
