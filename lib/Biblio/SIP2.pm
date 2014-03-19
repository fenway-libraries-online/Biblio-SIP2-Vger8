package Biblio::SIP2;

use IO::Socket;

require Exporter;

use vars qw(@ISA @EXPORT_OK);

@ISA = qw(Exporter);
@EXPORT_OK = qw(returns fixed variable timestamp);

sub returns(@);
sub fixed(@);
sub variable(@);

# --- Methods

sub new {
    my $cls = shift;
    bless { @_ }, $cls;
}

sub connect {
    my ($self, $port) = @_;
    $port ||= $self->{'port'} || 7031;
    my $socket = IO::Socket::INET->new("localhost:$port")
        or die "Can't connect: $@";
    $self->{'socket'} = $socket;
    return $self;
}

sub disconnect {
    my ($self) = @_;
    my $socket = delete $self->{'socket'} || return $self;
    close $socket;
    return $self;
}

sub is_connected { defined $_[0]->{'socket'} }

# --- Requests and replies

sub LOGIN {(
    93, 94,
    returns fixed(
                'ok' => 1,
            ),
            variable(),
)};

sub SYSTEM_STATUS {(
    99, 98,
    returns fixed(
                'online' =>  1,
                'checkin' =>  1,
                'checkout' =>  1,
                'renew' =>  1,
                'status_update' =>  1,
                'offline' =>  1,
                'timeout' =>  3,
                'retries' =>  3,
                'date' => 18,
                'version' => 4,
            ),
            variable(
                'supported_messages' => 'BX',
                'message' => 'AF',
            ),
)}

sub PATRON_STATUS {(
    23, 24,
    returns fixed(
                'patron_status'  => 14,
                'language'       =>  3,
                'date'           => 18,
            ),
            variable(
                'institution_id' => 'AO',
                'barcode'        => 'AA',
                'name'           => 'AE',
                'valid'          => 'BL',
                'fees'           => 'BV',
                'currency'       => 'BH',
                'screen_message' => 'AF',
                'address'        => 'BD',
                'email'          => 'BE',
                'group'          => 'ML',
            ),
)};

sub CHECKOUT {(
    11, 12,
    returns fixed(
                'ok'            =>  1,
                'may_renew'     =>  1,
                'magnetic'      =>  1,
                'desensitize'   =>  1,
                'date'          => 18,
            ),
            variable(
                'institution_id' => 'AO',
                'patron_barcode' => 'AA',
                'message'        => 'AF',
                'title'          => 'AJ',
                'due_date'       => 'AH',
            ),
)}

sub RENEW {(
    29, 30,
    returns fixed(
                'ok'            =>  1,
                'may_renew'     =>  1,
                'magnetic'      =>  1,
                'desensitize'   =>  1,
                'date'          => 18,
            ),
            variable(
                'institution_id' => 'AO',
                'patron_barcode' => 'AA',
                'item_barcode'   => 'AB',
                'message'        => 'AF',
                'title'          => 'AJ',
                'due_date'       => 'AH',
            ),
)}

sub CHECKIN {(
    '09', 10,
    returns fixed(
                'ok'            =>  1,
                'resensitize'   =>  1,
                'magnetic'      =>  1,
                'alert'         =>  1,
                'date'          => 18,
            ),
            variable(
                'item_barcode'  => 'AB',
                'item_location' => 'AQ',
                'title'         => 'AJ',
            ),
)}

sub HOLD {(
    15, 16,
    returns fixed(
                'ok'        =>  1,
                'available' =>  1,
                'transaction_date' => 18,
            ),
            variable(
                'expiration_date' => 'BW',
                'patron_barcode'  => 'AA',
                'item_barcode'    => 'AB',
                'title'           => 'AJ',
                'message'         => 'AF',
            ),
)}

sub END_PATRON_SESSION {(
    35, 36,
    returns fixed(
                'ended' =>  1,
                'date'  => 18,
            ),
            variable(
                'institution_id' => 'AO',
                'patron_barcode' => 'AA',
                'message'        => 'AF',
            ),
)}

# --- Requests

sub login {
    my ($self, %arg) = @_;
    my $operator = $arg{'operator'} || $self->operator;
    my $password = $arg{'password'} || $self->password;
    my $location = $arg{'location'} || $self->location;
    $self->request(LOGIN, 0, 0, { CN => $operator, CO => $password, CP => $location });
}

sub system_status {
    my ($self) = @_;
    my %result = $self->request(
        SYSTEM_STATUS, 0, '008', '2.00',
    );
    return %result;
}

sub patron_status {
    my ($self, $barcode) = @_;
    my %result = $self->request(
        PATRON_STATUS, '001', timestamp(),
        { AA => $barcode, AO => '', AC => '', AD => '' }
    );
    if ($result{'valid'} eq 'M') {
        $result{'valid'} = 'Y';
        $result{'ok'} = 1;
        $result{'group'} ||= '';
        $result{'groups'} = [ split /\t/, $result{'group'} ];
    }
    elsif ($result{'valid'} eq 'Y') {
        $result{'ok'} = 1;
        $result{'groups'} = [ $result{'group'} ] if defined $result{'group'};
    }
    return %result;
}

sub hold {
    my ($self, $patron_barcode, $item_bibid, $item_barcode, $pickup_loc) = @_;
    $self->request(
        HOLD, '+', timestamp(),
        { BW => timestamp(time + 86400*30), AO => '', AA => $patron_barcode, AB => $item_barcode, MA => $item_bibid, MB => '', MD => '', MF => $self->operator, BS => $pickup_loc }
    );
}

sub cancel_hold {
    my ($self, $patron_barcode, $item_bibid, $item_barcode) = @_;
    $self->request(
        HOLD, '-', timestamp(),
        { BW => timestamp(time + 86400*30), AO => '', AA => $patron_barcode, AB => $item_barcode, MA => $item_bibid, MB => '', MD => '', MF => $self->operator }
    );
}

sub checkout {
    my ($self, $patron_barcode, $item_barcode, $renewals, $noblock, $due_date, $cancel) = @_;
    $self->request(
        CHECKOUT, $renewals||'Y', $noblock||'Y', timestamp(), $due_date||timestamp(time + 86400*56),
        { AA => $patron_barcode, AB => $item_barcode, BI => $cancel ? 'Y' : 'N' }
    );
}

sub renew {
    my ($self, $patron_barcode, $item_barcode, $third_party, $noblock, $due_date) = @_;
    $self->request(
        RENEW, $third_party||'Y', $noblock||'Y', timestamp(), $due_date||timestamp(time + 86400*56),
        { AA => $patron_barcode, AB => $item_barcode }
    );
}

sub checkin {
    my ($self, $item_barcode) = @_;
    my $now = timestamp();
    $self->request(
        CHECKIN, 'Y', $now, $now,
        { AB => $item_barcode, MF => $self->operator }
    );
}

sub end_patron_session {
    my ($self, $patron_barcode) = @_;
    $self->request(
        END_PATRON_SESSION, timestamp(),
        { AO => '', AA => $patron_barcode }
    );
}

# --- Utility functions

sub returns(@) { @_ }

sub fixed(@) {
    return sub { return } if !@_;
    my @subs;
    while (@_) {
        my ($name, $spec) = splice @_, 0, 2;
        if ($spec =~ /^\d+$/) {
            push @subs, sub {
                my $val = substr($_, 0, $spec);
                substr($_, 0, $spec) = '';
                return $name => $val;
            };
        }
        else {
            push @subs, sub {
                die if !s/\A($spec)//;
                return $name => $1;
            }
        }
    }
    my %field;
    return sub {
        foreach my $sub (@subs) {
            my ($name, $val) = $sub->();
            $field{$name} = $val;
        }
        return %field;
    }
}

sub variable(@) {
    return sub { return } if !@_;
    my %field;
    my %code2name;
    while (@_) {
        my ($name, $code) = splice @_, 0, 2;
        $code2name{$code} = $name;
    }
    return sub {
        while (s/\A(..)([^|]*)\|//) {
            my $name = $code2name{$1} || next;
            $field{$name} = $2;
        }
        return %field;
    };
}

sub request {
    my ($self, $cmd, $exp, $req, $opt) = splice @_, 0, 5;
    foreach my $param (@_) {
        my $r = ref $param;
        if ($r eq '') {
            $cmd .= $param;
        }
        elsif ($r eq 'HASH') {
            while (my ($key, $val) = each %$param) {
                $cmd .= $key . $val . '|';
            }
        }
    }
    my $socket = $self->{socket};
    print STDERR "** SIP2 -> $cmd\n" if $self->{debug};
    $socket->send($cmd."\r");
    my $buf;
    my $result = $socket->recv($buf, 1024);
    die "No reply" if !defined $result;
    die "Ill-formed response" if $buf !~ s/\r\z//;
    print STDERR "** SIP2 <- $buf\n" if $self->{debug};
    if ($buf =~ s/^$exp//) {
        for ($buf) {
            my %result = ( 'command_identifier' => $exp, $req->(), $opt->() );
            return %result;
        }
    }
    else {
        return ( 'error' => "expected $exp, received $buf" );
    }
}

sub timestamp {
    my ($t) = @_;
    my @date = localtime($t || time);
    $date[5] += 1900;
    $date[4]++;
    sprintf('%04d%02d%02d    %02d%02d%02d', @date[5,4,3,2,1,0]);
}

1;

