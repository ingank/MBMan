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
use Mail::Header;
use Email::Address;
use Date::Manip;             # Zeitangaben parsen
use MIME::Words qw(:all);    # Mime decodieren
use Data::Structure::Util qw(unbless);

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
    my $self  = {
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

    $imap->Server( $self->{Server} );
    $imap->connect || die;
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

sub mailbox_info
  #
  # Infos zum IMAP-Account sammeln
  #
{
    my $self = shift;
    my $imap = $self->{Imap};
    my $info = {};

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
        $info->{Capabilities} = $imap->capability;
        $info->{Folders}      = {};

        for my $folder ( @{$folders} ) {

            my $fetch    = {};
            my @keys     = ();
            my $messages = 0;
            my $seen     = 0;
            my $unseen   = 0;
            my $usage    = 0;
            my $size     = 0;

            $imap->examine($folder);
            $messages = $imap->message_count();

            if ($messages) {

                $fetch    = $imap->fetch_hash("FAST");
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

            $info->{Folders}->{$folder}->{Usage}  = $usage;
            $info->{Folders}->{$folder}->{Count}  = $messages;
            $info->{Folders}->{$folder}->{Seen}   = $seen;
            $info->{Folders}->{$folder}->{Unseen} = $unseen;

        }

        ( $x, $y ) = &_get_quota_usage($imap);

        $info->{'01_Host'}         = $imap->{Server};
        $info->{'02_User'}         = $imap->{User};
        $info->{'03_Quota'}        = $x;
        $info->{'04_RootUsage'}    = $y;
        $info->{'05_RootUsage100'} = $y / $x * 100;
        $info->{'06_AccuUsage'}    = $usage_accu;
        $info->{'07_AccuUsage100'} = $usage_accu / $x * 100;
        $info->{'08_UsageDiff'}    = $usage_accu - $y;
        $info->{'09_MessageCount'} = $messages_accu;
        $info->{'10_Seen'}         = $seen_accu;
        $info->{'11_Unseen'}       = $unseen_accu;
        $info->{'12_SmallestMail'} = $smallest;
        $info->{'13_LargestMail'}  = $largest;
        $info->{'14_AverageSize'}  = int( $usage_accu / $messages_accu );

    }
    elsif ( $imap->IsConnected ) {

        $info->{Capabilities} = $imap->capability;

    }

    return $info;

}

sub fetch_message_infos
  #
  # Usage: $foo = &fetch_message_infos(@args);
  #
  # Ermittle Informationen über alle Mails aller Ordner in einer Mailbox.
  #
  # Übergib anschließend die ermittelten Daten
  # als referenzierten Hash an $foo.
  #
  # Ohne Argumente wird der IMAP-Befehl 'FETCH FAST' ausgeführt.
  #
  # Das Argument Modus => 'Fast' bestimmt explizit 'FETCH FAST'.
  # Das Argument Modus => 'All' führt stattdessen 'FETCH ALL' aus.
  # Das Argument Modus => 'Full' führt stattdessen 'FETCH FULL' aus.
  # Der Schalter HashEnv => 1 gibt ENVELOPE-Daten zusätzlich in einem Hash zurück.
  # Der Schalter DecodeMime => 1 gibt MIME-dekodierte Daten zurück.
  #
  # Beachte Folgendes:
  #
  # ** 'ENVELOPE' macht nur mit 'FETCH ALL' und 'FETCH FULL' wirklich Sinn.
  # **  Der Schalter 'HashEnv' kann die Rechenzeit erheblich beeinflussen.
  # **  Je nach Größe der Mailbox solltest Du dich von 'Fast' über 'All' nach 'Full' vorarbeiten.
  #
{
    my $self = shift;
    my $args = {
        Modus      => 'Fast',
        Hashenv    => 0,
        Decodemime => 0,
    };

    while (@_) {
        my $k = ucfirst lc shift;
        my $v = shift;
        $args->{$k} = $v if defined $v;
    }

    my $imap = $self->{'Imap'};
    my $ret  = {};

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
            $ret->{$folder}->{'MESSAGES'} = $mcount;
            $ret->{$folder}->{'SEARCH'}   = $search;

            if ($mcount) {

                my $fast = $args->{Fast} && not $args->{All} && not $args->{Full};
                my $all  = $args->{All}  && not $args->{Full};
                my $full = $args->{Full};

                my $fetch_data = undef;
                my $fetch      = undef;

                if ( $args->{Modus} eq 'Fast' ) {
                    $fetch = $imap->fetch( 0, "FAST" );
                    $args->{Hashenv} = 0;
                }

                if ( $args->{Modus} eq 'All' ) {
                    $fetch = $imap->fetch( 0, "ALL" );
                }

                if ( $args->{Modus} eq 'Full' ) {
                    $fetch = $imap->fetch( 0, "FULL" );
                }

                my @indizes = 0 .. @{$fetch} - 1;

                if ( $args->{Decodemime} ) {
                    for (@indizes) {
                        ${$fetch}[$_] = decode_mimewords( ${$fetch}[$_] );
                    }
                }

                for (@indizes) { ${$fetch}[$_] =~ s/\r\n|\r|\n//g; }

                $ret->{$folder}->{'FETCH_COMMAND'}  = shift @{$fetch};
                $ret->{$folder}->{'FETCH_RESPONSE'} = pop @{$fetch};

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

                if ( $args->{Hashenv} ) {

                    for (@indizes) {

                        my $package = undef;
                        my $string  = shift @{$fetch};
                        $package->{'FETCH_STRING'} = $string;
                        $string =~ s/^(.*)ENVELOPE/* 1 FETCH (ENVELOPE/;
                        my $bso = Mail::IMAPClient::BodyStructure::Envelope->new($string);
                        unbless $bso;
                        $package->{'FETCH_ENVELOPE'} = $bso;
                        undef $bso;
                        $package->{'INTERNAL_DATE'} = shift @internal_dates;
                        push @{$fetch_data}, $package;

                    }
                }
                else {

                    for (@indizes) {

                        my $package = undef;

                        $package->{'INTERNAL_DATE'} = shift @internal_dates;
                        $package->{'FETCH_STRING'}  = shift @{$fetch};

                        push @{$fetch_data}, $package;

                    }
                }

                $ret->{$folder}->{'FETCH_DATA'} = $fetch_data;

            }
        }
    }

    return $ret;

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

        if ( $args->{Modus} eq 'Percent' ) {

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
    my $ret  = '';
    my @addr = Email::Address->parse(shift);

    while ( $addr[0] ) {

        my $name    = $addr[0][0];
        my $email   = $addr[0][1];
        my $comment = $addr[0][2];

        if ($name)    { $ret .= "$name "; }
        if ($email)   { $ret .= "<$email> "; }
        if ($comment) { $ret .= "($comment) "; }

        $ret = substr( $ret, 0, -1 );
        $ret .= ", ";

        shift @addr;
    }

    $ret = substr( $ret, 0, -2 );
    return $ret;
}

sub _test {
    _clean_address(shift);
}
