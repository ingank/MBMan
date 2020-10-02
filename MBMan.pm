#
# MBMan.pm
#
# MBMan - Eine IMAP Mailboxmanagement API.
#

package MBMan;
use strict;

our $VERSION = '0.0.7';

use warnings;
use diagnostics;
use feature qw(say);
use Mail::IMAPClient;
use Digest::MD5::File qw(md5_hex);    # MD5 Prüfsummen erzeugen
use FileHandle;                       # Einfache Dateioperationen

#use Storable;
#use Mail::IMAPClient::BodyStructure;
#use Mail::Header;
#use Email::Address;
#use Date::Manip;                      # Zeitangaben parsen
#use MIME::Words qw(:all);                 # Mime decodieren
#use Data::Structure::Util qw(unbless);    # Datenbasis eines Objektes extrahieren

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse    = 1;
$Data::Dumper::Indent   = 1;

# Objekthandling

sub new
  #
  # Konstruktor
  #
{

    my $class = shift;

    # Voreinstellungen

    my $self = {

        # IMAP-SERVER
        DEBUG   => 0,          # Verwende Mail::IMAPClient nicht im Debug-Modus
        SSL     => 1,          # SSL-verschlüsselte Client-/Serverkommunikation
        PEEK    => 1,          # Setze nicht das /SEEN Flag
        USEUID  => 1,          # Nutze UID
        UID     => 0,          # Zuletzt verwendete UID
        SERVER  => '',         # IMAP-Servername (fqdn) oder Server-IP
        USER    => '',         # Nutzerkennung
        PASS    => '',         # Passphrase
        MAILBOX => 'INBOX',    # Standard-Postfach
        EXPUNGE => 0,          # Nachricht nach dem Herunterladen auf dem Server löschen?

        # LOKALE BACKUP-DATENBANK
        DBASE    => 'MBData',    # Name des Datenordners (unterhalb von ``~/'')
        UIDWIDTH => 6,           # Länge des UID-Indizes im Dateinamen (Bsp.: '3' für 000 bis 999)
        FILECHK  => 0,           # Nach dem Speichern Datei gegenprüfen

        # LIMITER
        LIMIT => 80,             # Maximale Füllung der Mailbox in Prozent
        TREND => 'OLD',          # 'OLD' = Älteste, 'NEW' = Neueste Nachrichten bevorzugen

    };

    while (@_) {

        my $k = uc shift;
        my $v = shift;
        $self->{$k} = $v if defined $v;

    }

    bless $self, ref($class) || $class;

    die("Instanzierung der Klasse Mail::IMAPClient fehlgeschlagen.\n")

      unless $self->{IMAP} = Mail::IMAPClient->new(

        Debug => $self->{DEBUG},
        Ssl   => $self->{SSL},
        Peek  => $self->{PEEK},
        Uid   => $self->{USEUID}

      );

    return $self;

}

sub vars
  #
  # Gibt eine Hashreferenz auf Kopien von internen Variablen zurück.
  # Die Variablen des IMAP-Client-Objektes werden ausgeblendet.
  # Zur Maximierung der Kontrolle ist die Variablen-Liste als
  # White-List umgesetzt. Vorteil ist die einfache Umsetzung von
  # Listensets bzw. die Modularisierung.
  #
{

    my $self     = shift;
    my $data     = undef;
    my %keywords = map { $_, 1 } qw (

      DEBUG
      SSL
      PEEK
      USEUID
      SERVER
      USER
      PASS
      LIMIT
      DBASE
      UIDWIDTH
      FILECHK
      MAILBOX
      UID
      EXPUNGE
      AUTOSAVE
      TREND
      SERVER_ID_TAG
      SERVER_RESPONSE

    );

    for my $keyword ( keys(%keywords) ) {

        if ( exists $self->{$keyword} ) {

            $data->{$keyword} = $self->{$keyword};

        }

    }

    return $data;

}

# IMAP4 Client-/Server-Kommunikation

sub connect
  #
  # Eine Verbindung zu einem IMAP-Server aufbauen
  #
{

    my $self = shift;

    while (@_) {

        my $k = uc shift;
        my $v = shift;
        $self->{$k} = $v if defined $v;

    }

    my $imap = $self->{IMAP};
    return 1 if $imap->IsConnected;

    my $server = $self->{SERVER};

    die("IMAP-Server-Adresse ist unbekannt.\n")
      unless $server;

    $imap->Server($server);

    die("IMAP-Server konnte nicht konnektiert werden.\n")
      unless $imap->connect;

    my $server_response;
    my $server_id_tag;

    $server_response         = $imap->LastIMAPCommand;
    $server_response         = &_str_chomp($server_response);
    $self->{SERVER_RESPONSE} = $server_response;
    $server_id_tag           = $imap->tag_and_run('ID NIL');
    $server_id_tag           = &_str_chomp( ${$server_id_tag}[1] );
    $self->{SERVER_ID_TAG}   = $server_id_tag;

    return 1;

}

sub login
  #
  # User-Login auf IMAP-Server
  #
{

    my $self = shift;

    while (@_) {

        my $k = uc shift;
        my $v = shift;
        $self->{$k} = $v if defined $v;

    }

    my $imap = $self->{IMAP};
    return 1 if $imap->IsAuthenticated;

    die("Keine Verbindung zum IMAP-Server vorhanden.\n")
      unless $imap->IsConnected;

    die("Der Server unterstützt kein CRAM-MD5.\n")
      unless $imap->has_capability('AUTH=CRAM-MD5');

    my $user = $self->{USER} // 0;
    my $pass = $self->{PASS} // 0;

    die("Benutzerkennung ist unbekannt.\n")
      unless $user;

    die("Passwort ist unbekannt.\n")
      unless $pass;

    $imap->User($user);
    $imap->Password($pass);
    $imap->Authmechanism('CRAM-MD5');
    $imap->login;

    die("Authentifizierung fehlgeschlagen.\n")
      unless $imap->IsAuthenticated;

    return 1;

}

sub quota
  #
  # Gibt folgende Werte als Liste zurück:
  #
  #     (x, y)
  #
  # x = Die Quota des IMAP-Benutzers auf dem Server in Byte.
  # y = Aktuelle Nutzung des Speichers auf dem Server in Byte.
  #
{

    my $self = shift;
    my $imap = $self->{IMAP};

    die("Voraussetzung für die Ermittlung der Quota ist der AUTHENTICATED STATE!\n")
      unless $imap->IsAuthenticated;

    my $quota     = undef;
    my $usage     = undef;
    my $quotaroot = $imap->getquotaroot();

    for ( @{$quotaroot} ) {

        if ( $_ =~ /\(STORAGE (\d+) (\d+)\)/ ) {

            $usage = $1 * 1024;
            $quota = $2 * 1024;
            last;

        }
    }

    $usage = "$usage" * 1;
    $quota = "$quota" * 1;

    return ( $quota, $usage );

}

sub mailboxes
  #
  # Liefert eine Liste aller Postfächer
  # des aktuellen Nutzers auf dem aktuellen Server
  #
{

    my $self = shift;
    my $imap = $self->{IMAP};

    die("Voraussetzung für die Ermittlung von Postfächern ist der AUTHENTICATED STATE!\n")
      unless $imap->IsAuthenticated;

    my @sigwords = qw (

      All
      Archive
      Drafts
      Flagged
      Junk
      Sent
      Trash

    );

    my @raw;
    my @folders;
    my @attrs;
    my %specials;
    my $data;
    my $item;
    my $name;
    my $sigword;

    @raw = $imap->folders_hash;

    for $item (@raw) {

        $name = $item->{name};

        for $sigword (@sigwords) {

            @attrs = grep { /$sigword/ } @{ $item->{attrs} };

            if (@attrs) {

                $specials{$sigword} = $name;

            }

        }

        push @folders, $name;

    }

    $data->{FOLDERS}  = [@folders];
    $data->{SPECIALS} = {%specials};

    return $data;

}

sub message
  #
  # Holt eine Nachricht vom Server
  #
{

    my $self = shift;

    my $args = {

        MAILBOX => $self->{MAILBOX},
        EXPUNGE => $self->{EXPUNGE},
        UID     => 0,

    };

    while (@_) {

        my $k = uc shift;
        my $v = shift;
        $args->{$k} = $v if $v;

    }

    my $mailbox = $args->{MAILBOX};
    my $expunge = $args->{EXPUNGE};
    my $uid     = $args->{UID};
    my $imap    = $self->{IMAP};
    my $user    = $self->{USER};
    my $message;
    my $receivedsize;
    my $md5checksum;
    my $serversize;
    my $uid_list;
    my $uidvalidity;
    my $internaldate;
    my $headerdate;
    my $info;
    my $data;

    die("Voraussetzung für den Zugriff auf Server-Nachrichten ist der AUTHENTICATED STATE!\n")
      unless $imap->IsAuthenticated;

    die("Unbekannte Mailbox $mailbox.\n")
      unless $imap->exists($mailbox);

    die("Mailbox $mailbox kann nicht angewählt werden.\n")
      unless $imap->examine($mailbox);

    $uid_list = $imap->messages;

    unless ( scalar @{$uid_list} ) {

        warn("Mailbox $mailbox ist leer (empty).");
        $info->{WARNING} = "MAILBOX_EMPTY";
        $data->{INFO}    = $info;
        return $data;

    }

    die("Nachricht mit der UID $uid ist nicht auf dem Server zu finden.\n")
      unless scalar grep { /^$uid$/ } @{$uid_list};

    $message               = $imap->message_string($uid);
    $receivedsize          = length($message);
    $md5checksum           = md5_hex($message);
    $serversize            = $imap->size($uid);
    $uidvalidity           = $imap->uidvalidity($mailbox);
    $internaldate          = $imap->internaldate($uid);
    $headerdate            = $imap->date($uid);
    $info->{USER}          = $user;
    $info->{UID}           = $uid;
    $info->{UIDVALIDITY}   = $uidvalidity;
    $info->{DATE_INTERNAL} = $internaldate;
    $info->{DATE_HEADER}   = $headerdate;
    $info->{SIZE_SERVER}   = $serversize;
    $info->{SIZE_RECEIVED} = $receivedsize;
    $info->{MD5CHECKSUM}   = $md5checksum;
    $info->{MAILBOX}       = $mailbox;
    $info->{SAVED}         = 0;
    $info->{EXPUNGED}      = 0;
    $info->{CHECKED}       = 0;
    $data->{MESSAGE}       = $message;

    if ($expunge) {

        $imap->select($mailbox);
        $imap->delete_message($uid);

        die("Kann Nachricht auf dem Server nicht löschen\n")
          unless $imap->expunge;

        $info->{EXPUNGED} = 1;

    }

    $data->{INFO} = $info;
    return $data;

}

sub save
  #
  # Schreibe Nachricht in Datenbank
  # Wenn keine Datenbank vorhanden, wird eine initialisiert.
  #
{

    my $self        = shift;
    my $data        = shift;
    my $info        = $data->{INFO} // 0;
    my $message     = $data->{MESSAGE} // 0;
    my $user        = $info->{USER} // 0;
    my $mailbox     = $info->{MAILBOX} // 0;
    my $uid         = $info->{UID} // 0;
    my $uidvalidity = $info->{UIDVALIDITY} // 0;
    my $uidwidth    = $self->{UIDWIDTH} // 0;
    my $dbase       = $self->{DBASE} // 0;
    my $filechk     = $self->{FILECHK} // 1;
    my $filename;
    my $filehandle;
    my $filedata;

    die("Kann Nachricht nicht speichern: zu wenig Argumente!\n")
      unless $message
      && $user
      && $mailbox
      && $uid
      && $uidvalidity
      && $uidwidth;

    die("Kann nicht in das Home-Verzeichnis wechseln.\n")
      unless chdir;

    die("Kann Datenbankverzeichnis ~/$dbase nicht erstellen.\n")
      unless ( -d $dbase ) || mkdir( $dbase, 0755 );

    die("Kein Datenbankverzeichnis ~/$dbase vorhanden\n.")
      unless ( -d $dbase );

    die("Kann nicht in das Datenbankverzeichnis $dbase wechseln.\n")
      unless chdir $dbase;

    die("Kann den Benutzerzweig $user nicht erstellen.\n")
      unless ( -d $user ) || mkdir( $user, 0755 );

    die("Kein Benutzerzweig $user vorhanden.\n")
      unless ( -d $user );

    die("Kann nicht in den Benutzerzweig $user wechseln.\n")
      unless chdir $user;

    die("Kann den Mailboxzweig $mailbox nicht erstellen.\n")
      unless ( -d $mailbox ) || mkdir( $mailbox, 0755 );

    die("Kann nicht in den Mailboxzweig $mailbox wechseln.\n")
      unless chdir $mailbox;

    $filename = $uidvalidity;
    $filename .= " - " . ( sprintf "%0" . $uidwidth . "d", $uid );
    $filename .= ".eml";
    $filehandle = FileHandle->new( $filename, "w" );
    print $filehandle $message;
    undef $filehandle;

    die("Datei $filename konnte nicht geschrieben werden.\n")
      unless ( -f $filename );

    if ($filechk) {

        $filehandle = FileHandle->new( $filename, "r" );
        $filedata = do { local $/; <$filehandle> };
        undef $filehandle;

        die("Gespeicherte Nachricht $filename konnte nicht verifiziert werden.\n")
          unless $message eq $filedata;

        $info->{CHECKED} = 1;

    }

    $info->{SAVED} = 1;
    return 1;

}

sub limitlist
  #
  # Gibt eine Liste mit UID's zurück,
  # die nach der Löschung der zugehörigen Nachrichten auf dem Server
  # den genutzten Speicher genau unterhalb der limitierten Größe des
  # IMAP-Accounts einmessen würde.
  #
{

    my $self = shift;

    my $args = {

        MAILBOX => $self->{MAILBOX},
        LIMIT   => $self->{LIMIT},

    };

    while (@_) {

        my $k = uc shift;
        my $v = shift;
        $args->{$k} = $v if $v;

    }

    my $mailbox = $args->{MAILBOX};
    my $limit   = $args->{LIMIT};
    my $imap    = $self->{IMAP};

    $imap->examine($mailbox);

    my $fetch    = $imap->fetch_hash("RFC822.SIZE");
    my $uid_list = $imap->messages();
    my ( $quota, $usage ) = $self->quota();
    my $limit_border = $quota / 100 * $limit;
    my @data;

    for my $uid ( @{$uid_list} ) {

        last if $usage < $limit_border;

        $usage -= $fetch->{$uid}->{'RFC822.SIZE'};
        push @data, $uid;

    }

    return \@data;

}

sub logout
  #
  # IMAP LOGOUT
  #
{

    my $self = shift;
    my $imap = $self->{IMAP};
    return 1 unless $imap->IsConnected;
    $imap->logout;
    return 0 if $imap->IsConnected;
    return 1;

}

# interne Funktionen

sub _str_chomp
  #
{

    my $str = shift;

    return unless $str;

    $str =~ s/\r\n|\r|\n//g;
    return $str;

}

sub _array_chomp
  #
{

    my $array = shift;
    my $out   = ();

    return unless scalar @{$array};

    push @{$out}, _str_chomp($_) for @{$array};

    return $out;

}

sub _array_filter
  #
{

    my $in   = shift;
    my $term = shift;
    my $out  = ();

    return unless scalar @{$in};

    for my $row ( @{$in} ) {

        $row =~ s/\r\n|\r|\n//g;
        push @{$out}, $row if scalar grep (/$term/), $row;

    }

    return $out;

}
