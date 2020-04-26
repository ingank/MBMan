#
#
# MBMan.pm
#
# Administrative Tätigkeiten an IMAP-Mailboxen durchführen.
#

package MBMan;

our $VERSION = '0.0.2';

use strict;
use warnings;
use diagnostics;

use feature qw(say);
use Mail::IMAPClient;
use Mail::IMAPClient::BodyStructure;

#use Mail::Header;
#use Email::Address;
#use Date::Manip;                      # Zeitangaben parsen
use MIME::Words qw(:all);                 # Mime decodieren
use Digest::MD5::File qw(md5_hex);        # MD5 Prüfsummen erzeugen
use Data::Structure::Util qw(unbless);    # Datenbasis eines Objektes extrahieren

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse    = 1;
$Data::Dumper::Indent   = 1;

sub new
  #
  # Konstruktor
  #
{

    my $class = shift;

    my $self = {

        Debug     => 0,
        Ssl       => 1,
        Peek      => 1,
        Uid       => 1,
        Directory => '~/MBData'

    };

    while (@_) {

        my $k = ucfirst lc shift;
        my $v = shift;
        $self->{$k} = $v if defined $v;

    }

    bless $self, ref($class) || $class;

    $self->{Imap} = Mail::IMAPClient->new(

        Debug => $self->{Debug},
        Ssl   => $self->{Ssl},
        Peek  => $self->{Peek},
        Uid   => $self->{Uid}

    ) || die;

    return $self;

}

sub connect
  #
  # Eine Verbindung zu einem IMAP-Server aufbauen
  #
{

    my $self = shift;
    my $imap = $self->{Imap};

    while (@_) {

        my $k = ucfirst lc shift;
        my $v = shift;
        $self->{$k} = $v if defined $v;

    }

    return 0 if not $self->{Server};

    if ( not $imap->IsConnected ) {

        $imap->Server( $self->{Server} );
        $imap->connect || die;

    }

    return 1;

}

sub login
  #
  # User-Login auf einem IMAP-Server durchführen
  #
{

    my $self = shift;
    my $imap = $self->{Imap};

    while (@_) {

        my $k = ucfirst lc shift;
        my $v = shift;
        $self->{$k} = $v if defined $v;

    }

    return 0 if not $self->{User};
    return 0 if not $self->{Password};

    if ( $imap->IsConnected ) {

        $imap->User( $self->{User} );
        $imap->Password( $self->{Password} );
        $imap->login || die;

    }

    return 1;

}

sub logout
  #
  # Implementiert das LOGOUT IMAP Client Kommando
  # Die Objektdaten bleiben bestehen, solange das Objekt besteht.
  # Es kann beispielsweise mit den gleichen Zugangsdaten wieder eine Verbindung
  # zum IMAP-Server aufgebaut und der Login ausgeführt werden.
  #
{

    my $self = shift;
    my $imap = $self->{Imap};

    if ( $imap->IsConnected ) {

        $imap->logout || die;

    }

    return 1;

}

sub get_server_info
  #
  # Infos über den IMAP-Server und das (eventuell)
  # angemeldete Nutzerkonto sammeln.
  #
  # TODO: Server und Konto sollten eventuell in getrennten Methoden
  #       behandelt werden.
  #
{
    my $self = shift;
    my $imap = $self->{Imap};
    my $data = {};

    if ( $imap->IsAuthenticated ) {

        my $usage_accu    = 0;
        my $messages_accu = 0;
        my $seen_accu     = 0;
        my $unseen_accu   = 0;
        my $smallest      = 0;
        my $largest       = 0;
        my $x             = 0;
        my $y             = 0;

        my $folders = $imap->folders;
        $data->{Capabilities} = $imap->capability;
        $data->{Folders}      = {};

        for my $folder ( @{$folders} ) {

            my $fetchone = {};
            my @keys     = ();
            my $messages = 0;
            my $seen     = 0;
            my $unseen   = 0;
            my $usage    = 0;
            my $size     = 0;

            $imap->examine($folder);
            $messages = $imap->message_count();

            if ($messages) {

                $fetchone = $imap->fetch_hash("FAST");
                @keys     = keys %{$fetch};
                $smallest = $fetch->{ $keys[0] }->{'RFC822.SIZE'};

            }

            for my $key (@keys) {

                if ( index( $fetch->{$key}->{'FLAGS'}, '\\Seen' ) != -1 ) {
                    $seen++;
                }

                $size = $fetch->{$key}->{'RFC822.SIZE'};
                $usage += $size;
                if ( $size < $smallest ) { $smallest = $size }
                if ( $size > $largest )  { $largest  = $size }

            }

            $unseen = $messages - $seen;
            $usage_accu    += $usage;
            $messages_accu += $messages;
            $seen_accu     += $seen;
            $unseen_accu   += $unseen;

            $data->{Folders}->{$folder}->{Usage}  = $usage;
            $data->{Folders}->{$folder}->{Count}  = $messages;
            $data->{Folders}->{$folder}->{Seen}   = $seen;
            $data->{Folders}->{$folder}->{Unseen} = $unseen;

        }

        ( $x, $y ) = &_get_quota_usage($imap);

        $data->{'01_Host'}         = $imap->{Server};
        $data->{'02_User'}         = $imap->{User};
        $data->{'03_Quota'}        = $x;
        $data->{'04_RootUsage'}    = $y;
        $data->{'05_RootUsage100'} = $y / $x * 100;
        $data->{'06_AccuUsage'}    = $usage_accu;
        $data->{'07_AccuUsage100'} = $usage_accu / $x * 100;
        $data->{'08_UsageDiff'}    = $usage_accu - $y;
        $data->{'09_MessageCount'} = $messages_accu;
        $data->{'10_Seen'}         = $seen_accu;
        $data->{'11_Unseen'}       = $unseen_accu;
        $data->{'12_SmallestMail'} = $smallest;
        $data->{'13_LargestMail'}  = $largest;
        $data->{'14_AverageSize'}  = int( $usage_accu / $messages_accu );

    }
    elsif ( $imap->IsConnected ) {

        $data->{Capabilities} = $imap->capability;

    }

    return $data;

}

sub get_messages_info
  #
  # Anwendung: $foo = &get_messages_info(@args);
  #
  # Ermittle Informationen über alle Mails aller Mailboxen eines Nutzerkontos.
  #
  # Übergib anschließend die ermittelten Daten als referenzierten Hash an $foo.
  #
  # Ohne Argumente wird der IMAP-Befehl 'FETCH FAST' ausgeführt.
  #
  # Das Argument Modus => 'Fast' bestimmt explizit 'FETCH FAST'.
  # Das Argument Modus => 'All' führt stattdessen 'FETCH ALL' aus.
  # Das Argument Modus => 'Full' führt stattdessen 'FETCH FULL' aus.
  #
  # Der Schalter Envelope => 1 gibt zusätzlich ENVELOPE-Daten zurück.
  #
  # Der Schalter DecodeMime => 1 MIME-dekodiert alle empfangenen Daten.
  #
  # Beachte Folgendes:
  #
  # ** 'ENVELOPE' macht nur mit 'FETCH ALL' und 'FETCH FULL' wirklich Sinn.
  # ** 'ENVELOPE' kann die Wartezeiten erheblich verlängern.
  # **  Je nach Größe des Nutzeraccounts auf dem IMAP4-Server,
  #     solltest Du dich von 'Fast' über 'All' nach 'Full' vorarbeiten.
  #
{
    my $self = shift;
    my $args = {
        Modus      => 'Fast',
        Envelope   => 0,
        Decodemime => 0
    };

    while (@_) {
        my $k = ucfirst lc shift;
        my $v = shift;
        $args->{$k} = $v if defined $v;
    }

    my $modus    = $args->{Modus};
    my $envelope = $args->{Envelope};
    my $decode   = $args->{Decodemime};
    my $imap     = $self->{'Imap'};
    my $data     = {};

    if ( $imap->IsAuthenticated ) {

        my @folders = $imap->folders;

        for my $folder (@folders) {

            $imap->examine($folder);    # read only

            # Auszug aus RFC3501:
            #
            # Note: The STATUS command is intended to access the
            #   status of mailboxes other than the currently selected
            #   mailbox.  Because the STATUS command can cause the
            #   mailbox to be opened internally, and because this
            #   information is available by other means on the selected
            #   mailbox, the STATUS command SHOULD NOT be used on the
            #   currently selected mailbox.
            #
            # Deshalb wird hier das stabile SEARCH verwendet.

            my $search = $imap->search("ALL");
            my $mcount = @{$search};

            $data->{$folder}->{'MESSAGES'} = $mcount;
            $data->{$folder}->{'SEARCH'}   = $search;

            if ($mcount) {

                my $fetchpack = undef;
                my $fetchone  = undef;

                if ( $modus eq 'Fast' ) {

                    $fetchone = $imap->fetch( 0, "FAST" );
                    $args->{Hashenv} = 0;

                }
                elsif ( $modus eq 'All' ) {

                    $fetchone = $imap->fetch( 0, "ALL" );

                }
                elsif ( $modus eq 'Full' ) {

                    $fetchone = $imap->fetch( 0, "FULL" );

                }

                my @indizes = 0 .. @{$fetch} - 1;

                if ($decode) {

                    for (@indizes) { ${$fetch}[$_] = decode_mimewords( ${$fetch}[$_] ); }

                }

                for (@indizes) { ${$fetch}[$_] =~ s/\r\n|\r|\n//g; }

                $data->{$folder}->{'FETCH_COMMAND'}  = shift @{$fetch};
                $data->{$folder}->{'FETCH_RESPONSE'} = pop @{$fetch};

                pop @indizes;
                pop @indizes;

                my @internal_dates = ();

                for (@indizes) {

                    my $date = undef;

                    if ( ${$fetch}[$_] =~ /FETCH \(INTERNALDATE \"(.*)\" RFC822\.SIZE/ ) {
                        $date = $1;
                    }

                    push @internal_dates, $date;

                }

                if ($envelope) {

                    for (@indizes) {

                        my $package = undef;
                        my $string  = shift @{$fetch};

                        $package->{'FETCH_STRING'} = $string;
                        $string =~ s/^(.*)ENVELOPE/* 1 FETCH (ENVELOPE/;

                        my $bodyStructObj = Mail::IMAPClient::BodyStructure::Envelope->new($string);
                        unbless $bodyStructObj;
                        $package->{'FETCH_ENVELOPE'} = $bodyStructObj;
                        undef $bodyStructObj;

                        $package->{'INTERNAL_DATE'} = shift @internal_dates;
                        push @{$fetchpack}, $package;

                    }
                }
                else {

                    for (@indizes) {

                        my $package = undef;

                        $package->{'INTERNAL_DATE'} = shift @internal_dates;
                        $package->{'FETCH_STRING'}  = shift @{$fetch};

                        push @{$fetchpack}, $package;

                    }
                }

                $data->{$folder}->{'FETCH_DATA'} = $fetchpack;

            }
        }
    }

    return $data;

}

sub fetch_message
  #
  # Übertrage genau eine Email-Nachricht vom IMAP-Server.
  #
  # Das Ergebnis wird als Referenz auf eine Hash-Struktur zurückgegeben.
  #
  # Die Felder sind selbsterklärend und können mit Hilfe eines geeigneten
  # Data-Dumper-Moduls leicht ermittelt werden.
  #
{

    my $self = shift;
    my $imap = $self->{Imap};

    my $args = {

        Mailbox => 'INBOX',
        Uid     => 0

    };

    while (@_) {

        my $k = ucfirst lc shift;
        my $v = shift;
        $args->{$k} = $v if defined $v;

    }

    my $data    = {};
    my $mailbox = $args->{Mailbox};
    my $uid     = $args->{Uid};

    return $data if not $uid;

    if ( $imap->IsAuthenticated ) {

        $imap->examine($mailbox);

        my $message       = $imap->message_string($uid);
        my $idate         = $imap->internaldate($uid);
        my $hdate         = $imap->date($uid);
        my $server_size   = $imap->size($uid);
        my $received_size = length($message);
        my $md5           = md5_hex($message);

        $data->{Message}      = $message;
        $data->{InternalDate} = $idate;
        $data->{HeaderDate}   = $hdate;
        $data->{ServerSize}   = $server_size;
        $data->{ReceivedSize} = $received_size;
        $data->{MD5}          = $md5;

    }

    return $data;

}

sub limit
  #
  # Schaffe Platz in einer Mailbox durch Löschen der ältesten Mails
  # bis zu einem definierten Wert (prozentual oder absolut).
  # Lösche dabei zuerst Mails des Ordners 'Trash' (Papierkorb).
  # Danach arbeite dich durch den Ordner 'INBOX'.
  #
  # Verlasse dich dabei strikt auf die korrekte Implementierung von RFC3501
  # in der Software des IMAP-Servers was die Auswahl der jeweilig ältesten
  # Mail im Ordner angeht.
  #
{

    my $self = shift;
    my $imap = $self->{Imap};

    my $args = {

        Modus    => 'Percent',
        Limit    => 80,
        Backup   => 1,
        TestMode => 1

    };

    while (@_) {

        my $k = ucfirst lc shift;
        my $v = shift;
        $args->{$k} = $v if defined $v;

    }

    my $limit = $args->{Limit};

    if ( $imap->IsAuthenticated ) {

        my @folder_sel = ();
        my $folders    = $imap->folders;
        my $selproc    = \$imap->select;
        my ( $quota, $usage ) = &_get_quota_usage($imap);

        if ( $modus eq 'Percent' ) {

            $limit = $quota * $limit / 100;

        }
        if ( $args->{TestMode} ) {

            $selproc = \$imap->examine;

        }

        for ( @{$folders} ) {

            push @folder_sel, $_ if $_ eq 'Trash';
            push @folder_sel, $_ if $_ eq 'INBOX';

        }

        for my $folder (@folder_sel) {

            &{$selproc}($folder);

        }

        #  print "$quota ... $usage ... $limit";

    }

    return 1;

}

# Interne Funktionen

sub _get_quota_usage
  #
{
    my $imap  = shift;
    my $quota = 0;
    my $usage = 0;

    if ( $imap->IsAuthenticated ) {

        my $quotaroot = $imap->getquotaroot();

        for ( @{$quotaroot} ) {

            if ( $_ =~ /\(STORAGE (\d+) (\d+)\)/ ) {

                $usage = $1 * 1024;
                $quota = $2 * 1024;
                last;

            }
        }
    }

    return ( $quota, $usage );
}

sub _clean_address
  #
  # $foo = _clean_address($bar);
  #
  # $bar = Emailadressen in beliebiger Form
  # $foo = Emailadressen in der Form: 'Name1 foo@bar.baz (Kommentar), Name2 ...'
  #
{
    my $data = '';
    my @addr = Email::Address->parse(shift);

    while ( $addr[0] ) {

        my $name    = $addr[0][0];
        my $email   = $addr[0][1];
        my $comment = $addr[0][2];

        if ($name)    { $data .= "$name "; }
        if ($email)   { $data .= "<$email> "; }
        if ($comment) { $data .= "($comment) "; }

        $data = substr( $data, 0, -1 );
        $data .= ", ";

        shift @addr;
    }

    $data = substr( $data, 0, -2 );
    return $data;
}

sub _test {
    _clean_address(shift);
}
