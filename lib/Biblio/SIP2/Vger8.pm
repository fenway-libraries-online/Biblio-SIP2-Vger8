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

1;
