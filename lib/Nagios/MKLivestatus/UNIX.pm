package Nagios::MKLivestatus::UNIX;

use 5.000000;
use strict;
use warnings;
use IO::Socket::UNIX;
use Carp;
use base "Nagios::MKLivestatus";

=head1 NAME

Nagios::MKLivestatus::UNIX - connector with unix sockets

=head1 SYNOPSIS

    use Nagios::MKLivestatus;
    my $nl = Nagios::MKLivestatus::UNIX->new( '/var/lib/nagios3/rw/livestatus.sock' );
    my $hosts = $nl->selectall_arrayref("GET hosts");

=head1 CONSTRUCTOR

=over 4

=item new ( [ARGS] )

Creates an C<Nagios::MKLivestatus::UNIX> object. C<new> takes at least the socketpath.
Arguments are the same as in C<Nagios::MKLivestatus>.

If the constructor is only passed a single argument, it is assumed to
be a the C<socket> specification. Use either socker OR server.

=back

=cut


sub new {
    my $class = shift;
    unshift(@_, "socket") if scalar @_ == 1;
    my(%options) = @_;

    $options{'backend'} = $class;
    my $self = Nagios::MKLivestatus->new(%options);
    bless $self, $class;
    return $self;
}


########################################

=head1 METHODS

=over 4

=cut

sub _open {
    my $self      = shift;
    if(!-S $self->{'socket'}) {
        croak("failed to open socket $self->{'socket'}: $!");
    }
    my $sock = IO::Socket::UNIX->new($self->{'socket'});
    if(!defined $sock or !$sock->connected()) {
        my $msg = "failed to connect to $self->{'socket'} :$!";
        if($self->{'errors_are_fatal'}) {
            croak($msg);
        }
        $Nagios::MKLivestatus::ErrorCode    = 500;
        $Nagios::MKLivestatus::ErrorMessage = $msg;
        return;
    }
    return($sock);
}


########################################

=item close

close the sock

=cut

sub _close {
    my $self = shift;
    my $sock = shift;
    return close($sock);
}


1;

=back

=head1 AUTHOR

Sven Nierlein, E<lt>nierlein@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
