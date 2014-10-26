package Nagios::MKLivestatus;

use 5.008000;
use strict;
use warnings;
use IO::Socket;
use Data::Dumper;
use Carp;

our $VERSION = '0.13';


=head1 NAME

Nagios::MKLivestatus - access nagios runtime data from check_mk livestatus Nagios addon

=head1 SYNOPSIS

    use Nagios::MKLivestatus;
    my $nl = Nagios::MKLivestatus->new( socket => '/var/lib/nagios3/rw/livestatus.sock' );
    my $hosts = $nl->selectall_arrayref("GET hosts");

=head1 DESCRIPTION

This module connects via socket to the check_mk livestatus nagios addon. You first have
to install and activate the livestatus addon in your nagios installation.


=head1 CONSTRUCTOR

=over 4

=item new ( [ARGS] )

Creates an C<Nagios::MKLivestatus> object. C<new> takes at least the socketpath.
Arguments are in key-value pairs.

    socket                    path to the unix socket of check_mk livestatus
    verbose                   verbose mode
    line_seperator            ascii code of the line seperator, defaults to 10, (newline)
    column_seperator          ascii code of the column seperator, defaults to 0 (null byte)
    list_seperator            ascii code of the list seperator, defaults to 44 (comma)
    host_service_seperator    ascii code of the host/service seperator, defaults to 124 (pipe)

If the constructor is only passed a single argument, it is assumed to
be a the C<socket> specification.

=back

=cut

########################################
sub new {
    my $class = shift;
    unshift(@_, "socket") if scalar @_ == 1;
    my(%options) = @_;

    my $self = {
                    "verbose"                   => 0,
                    "socket"                    => undef,
                    "line_seperator"            => 10,   # defaults to newline
                    "column_seperator"          => 0,    # defaults to null byte
                    "list_seperator"            => 44,   # defaults to comma
                    "host_service_seperator"    => 124,  # defaults to pipe
               };
    bless $self, $class;

    for my $opt_key (keys %options) {
        if(exists $self->{$opt_key}) {
            $self->{$opt_key} = $options{$opt_key};
        }
        else {
            croak("unknown option: $opt_key");
        }
    }

    if(!defined $self->{'socket'}) {
        croak('no socket given');
    }

    return $self;
}

########################################

=head1 METHODS

=over 4

=item do

send a single statement without fetching the result

=cut

sub do {
    my $self      = shift;
    my $statement = shift;
    $self->_send($statement);
    return(1);
}

########################################

=item selectall_arrayref($statement)

send a query an get a array reference of arrays

    my $arr_refs = $nl->selectall_arrayref("GET hosts");

to get a array of hash references do something like

    my $hash_refs = $nl->selectall_arrayref("GET hosts", { slice => {} });

=cut

sub selectall_arrayref {
    my $self      = shift;
    my $statement = shift;
    my $slice     = shift;

    croak("no statement") if !defined $statement;

    my $result = $self->_send($statement);

    if(defined $slice and ref $slice eq 'HASH') {
        # make an array of hashes
        my @hash_refs;
        for my $res (@{$result->{'result'}}) {
            my $hash_ref;
            for(my $x=0;$x<scalar @{$res};$x++) {
                $hash_ref->{$result->{'keys'}->[$x]} = $res->[$x];
            }
            push @hash_refs, $hash_ref;
        }
        return(\@hash_refs);
    }

    return($result->{'result'});
}


########################################

=item selectall_hashref($statement, $key_field);

send a query an get a hashref

    my $hashrefs = $nl->selectall_hashref("GET hosts", "name");

=cut

sub selectall_hashref {
    my $self      = shift;
    my $statement = shift;
    my $key_field = shift;

    croak("no statement")                          if !defined $statement;
    croak("key is required for selectall_hashref") if !defined $key_field;

    my $result = $self->selectall_arrayref($statement, { slice => 1 });
    return if !defined $result;

    my %indexed;
    for my $row (@{$result}) {
        croak("key $key_field not found in result set") if !defined $row->{$key_field};
        $indexed{$row->{$key_field}} = $row;
    }
    return(\%indexed);
}



#selectcol_arrayref($statement);
#selectcol_arrayref($statement, \%attr);
#selectrow_array($statement);
#selectrow_arrayref($statement);
#selectrow_hashref($statement);

sub _send {
    my $self      = shift;
    my $statement = shift;
    if(!-S $self->{'socket'}) {
        croak("failed to open socket $self->{'socket'}: $!");
    }
    my $sock = IO::Socket::UNIX->new($self->{'socket'});
    if(!defined $sock or !$sock->connected()) {
        croak("failed to connect: $!");
    }

    my ($recv, @result);
    my $send = "$statement\nSeparators: $self->{'line_seperator'} $self->{'column_seperator'} $self->{'list_seperator'} $self->{'host_service_seperator'}\n";
    print "> ".Dumper($send) if $self->{'verbose'};
    print $sock $send;
    $sock->shutdown(1) or croak("shutdown failed: $!");
    while(<$sock>) { $recv .= $_; }
    print "< ".Dumper($recv) if $self->{'verbose'};

    return if !defined $recv;

    my $line_seperator = chr($self->{'line_seperator'});
    my $col_seperator  = chr($self->{'column_seperator'});

    for my $line (split/$line_seperator/, $recv) {
        push @result, [ split/$col_seperator/, $line ];
    }

    my $keys = shift @result;
    return({ keys => $keys, result => \@result});
}


1;

=back

=head1 SEE ALSO

For more information see the Livestatus page: http://mathias-kettner.de/checkmk_livestatus.html

=head1 AUTHOR

Sven Nierlein, E<lt>nierlein@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
