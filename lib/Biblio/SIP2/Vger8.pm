package Biblio::SIP2::Vger8;

use strict;
use warnings;

use vars qw(@ISA);

use Biblio::SIP2 qw(returns fixed variable timestamp);

@ISA = qw(Biblio::SIP2);

sub returns(@);
sub fixed(@);
sub variable(@);

# Standard variable parameters:
#   AB  barcode
#   AJ  title

# Voyager-specific variable parameters:
#   MA  bib ID
#   MB  ISBN
#   MC  LCCN
#   MF  operator ID
#   MH  bib type (leader/06) [defaults to a (book)]
#   MI  bib level (leader/07) [defaults to m (monograph)]
#   MJ  item ID
#   MK  ILL system reference number (i.e., VC request number)
#   ML  location code

sub CREATE {(
    81, 82,
    returns fixed(
                'ok'      =>  1,
            ),
            variable(
                'item_id' => 'MJ',
                'bib_id'  => 'MA',
                'message' => 'AF',
            ),
)}

sub DELETE {(
    85, 86,
    returns fixed(
                'ok'      => 1,
            ),
            variable(
                'message' => 'AF',
            ),
)}

# --- Methods

sub operator { $_[0]->{operator} }
sub password { $_[0]->{password} }
sub location { $_[0]->{location} }

sub create {
    my ($self, $barcode, $title, $refnum) = @_;
    my %req = (
        AB => $barcode,
       #AC => '',
        AJ => $title,
       #AO => '',
       #MB => '',
       #MC => '',
        MF => $self->operator,
        MH => 'a',
        MI => 'm',
    );
    $req{MK} = $refnum if defined $refnum;
    $self->request(
        CREATE, timestamp(),
        \%req
    );
}

sub delete {
    my ($self, $barcode, $bibid) = @_;
    $self->request(
        DELETE, timestamp(),
        { MF => $self->operator, AB => $barcode, 'MA' => $bibid }
    );
}

# --- Testing this code

sub test {
    my $opname = 'flovc';
    my $oppass = 'flovc';
    my $patron_barcode = '1119300586150';
    my $item_barcode = 'testing1234567';
    my $title = 'Testing 1, 2, 3';
    my %result;

    my $sip = Biblio::SIP2::Vger8->new(
        operator => $opname,
        password => $oppass,
        location => 'FLOVC',
    );
    $sip->connect;

    %result = $sip->login;
    print "OK login\n" if $result{ok};

    %result = $sip->patron_status($patron_barcode);
    print "OK patron status\n" if $result{valid} eq 'Y';

    %result = $sip->create($item_barcode, $title);

    if ($result{ok}) {
        my $bibid = $result{bib_id};
        print "OK created $bibid\n";

        %result = $sip->hold($patron_barcode, $bibid, $item_barcode);
        print $result{ok} ? "OK hold placed\n" : "ERR $result{message}\n";

        %result = $sip->checkout($patron_barcode, $item_barcode);
        print $result{ok} ? "OK checked out\n" : "ERR $result{message}\n";

        %result = $sip->checkin($item_barcode);
        print $result{ok} ? "OK checked in\n" : "ERR $result{message}\n";

        %result = $sip->delete($item_barcode, $bibid);
        print $result{ok} ? "OK deleted $bibid\n" : "ERR $result{message}\n";
    }
    else {
        print "ERR $result{message}\n";
    }

    %result = $sip->end_patron_session($patron_barcode);
    print "OK session ended\n" if $result{ended} eq 'Y';
}

test() if !caller();

1;
