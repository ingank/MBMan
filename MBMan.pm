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

        DEBUG    => 0,           # Verwende Mail::IMAPClient im Debug-Modus
        SSL      => 1,           # SSL-verschlüsselte Client-/Serverkommunikation
        PEEK     => 1,           # 1 = setze nicht das /SEEN Flag
        USEUID   => 1,           # nutze UID
        SERVER   => '',          # IMAP-Servername (fqdn) oder Server-IP
        USER     => '',          # dem IMAP-Server bekannte Nutzerkennung
        PASS     => '',          # zur Nutzerkennung passende Passphrase
        LIMIT    => 80,          # Maximale Füllung der Mailbox in Prozent
        DBASE    => 'MBData',    # ~/${DBASE}
        UIDWIDTH => 6,           # Länge des UID-Indizes (bspw. '3' für 000 bis 999)
        FILECHK  => 1            # Nach dem Speichern Datei gegenprüfen

    };

    while (@_) {

        my $k = ucfirst lc shift;
        my $v = shift;
        $self->{$k} = $v if defined $v;

    }

    bless $self, ref($class) || $class;

    $self->{IMAP} = Mail::IMAPClient->new(

        Debug => $self->{DEBUG},
        Ssl   => $self->{SSL},
        Peek  => $self->{PEEK},
        Uid   => $self->{USEUID}

    ) || die("Instanzierung der Klasse Mail::IMAPClient fehlgeschlagen.\n");

    return $self;

}

sub vars
  #
  # Gibt eine Hashreferenz auf Kopien von internen Variablen zurück.
  # Die Variablen des IMAP-Client-Objektes werden ausgeblendet.
  # Zur Maximierung der Kontrolle ist die Variablen-Liste als
  # White-List umgesetzt. Ein weiterer Vorteil ist die einfache
  # Umsetzung von verschiedenen Listensets oder die Modularisierung.
  #
{

    my $self = shift;
    my $data = {};

    my %keywords = map { $_, 1 } qw (
      DEBUG
      SSL
      PEEK
      USEUID
      SERVER
      USER
      LIMIT
      DBASE
      UIDWIDTH
      FILECHK
      SERVER_ID_TAG
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

        my $k = ucfirst lc shift;
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

        my $k = ucfirst lc shift;
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

    my $quota = 0;
    my $usage = 0;

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

    my @folders;
    my %specials;
    my @raw;
    my $data;

    @raw = $imap->folders_hash;

    for my $item (@raw) {

        my $name = $item->{name};

        for my $sigword (@sigwords) {

            my @attrs = grep { /$sigword/ } @{ $item->{attrs} };

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
  # Holt eine Nachricht eines Postfaches vom Server
  #
{

    my $self = shift;

    my $args = {

        Mailbox => 'INBOX',
        Uid     => 'OLDEST',           # 'OLDEST' = Älteste, 'NEWEST' = Neueste, ansonsten die UID
        Expunge => 0,                  # Nachricht nach dem Herunterladen auf dem Server löschen?
        Save    => 1,                  # Nachricht nach dem Herunterladen automatisch speichern?
        Filechk => $self->{FILECHK}    # Gespeicherte Nachricht prüfen?

    };

    while (@_) {

        my $k = ucfirst lc shift;
        my $v = shift;
        $args->{$k} = $v if defined $v;

    }

    $self->{FILECHK} = $args->{Filechk};

    my $mailbox      = $args->{Mailbox};
    my $uid          = $args->{Uid};
    my $expunge      = $args->{Expunge};
    my $save         = $args->{Save};
    my $imap         = $self->{IMAP};
    my $user         = $self->{USER};
    my $message      = undef;
    my $receivedsize = undef;
    my $md5checksum  = undef;
    my $serversize   = undef;
    my $uid_list     = undef;
    my $uidvalidity  = undef;
    my $internaldate = undef;
    my $headerdate   = undef;
    my $info         = undef;
    my $data         = undef;

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

    if ( $uid eq 'OLDEST' ) {

        $uid = ${$uid_list}[0];

    }
    if ( $uid eq 'NEWEST' ) {

        $uid = ${$uid_list}[-1];

    }

    die("Nachricht mit der UID $uid ist nicht auf dem Server zu finden.\n")
      unless scalar grep { /$uid/ } @{$uid_list};

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
    $data->{INFO}          = $info;
    $data->{MESSAGE}       = $message;

    if ($save) {

        die("Nachricht konnte nicht gespeichert werden.")
          unless $self->save($data);

        $data->{SAVED} = 1;

    }

    if ($expunge) {

        $imap->select($mailbox);
        $imap->delete_message($uid);

        die("Kann Nachricht auf dem Server nicht löschen\n")
          unless $imap->expunge;

        $data->{INFO}->{EXPUNGED} = 1;

    }

    $self->{MESSAGE} = $data;
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
    my $folder      = $self->{DBASE} // 0;
    my $savechk     = $self->{FILECHK};
    my $filename    = undef;
    my $filehandle  = undef;
    my $filedata    = undef;

    die("Kann Nachricht nicht speichern: zu wenig Argumente!\n")
      unless $message
      && $user
      && $mailbox
      && $uid
      && $uidvalidity
      && $uidwidth;

    die("Kann nicht in das Home-Verzeichnis wechseln.\n")
      unless chdir;

    unless ( -d $folder ) {

        die("Kann Datenbankverzeichnis ~/$folder nicht erstellen.\n")
          unless mkdir( $folder, 0755 );

    }

    die("Kein Datenbankverzeichnis ~/$folder vorhanden\n.")
      unless ( -d $folder );

    die("Kann nicht in das Datenbankverzeichnis $folder wechseln.\n")
      unless chdir $folder;

    unless ( -d $user ) {

        die("Kann den Benutzerzweig $user nicht erstellen.\n")
          unless mkdir( $user, 0755 );

    }

    die("Kann nicht in den Benutzerzweig $user wechseln.\n")
      unless chdir $user;

    $filename = $uidvalidity;
    $filename .= " - " . ( sprintf "%0" . $uidwidth . "d", $uid );
    $filename .= ".eml";
    $filehandle = FileHandle->new( $filename, "w" );
    print $filehandle $message;
    undef $filehandle;

    die("Datei $filename konnte nicht geschrieben werden.\n")
      unless ( -f $filename );

    if ($savechk) {

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

sub limit
  #
  # Gibt WAHR zurück, wenn das voreingestellte Limit eines
  # Nutzerkontos überschritten wurde
  #
{

    my $self       = shift;
    my $imap       = $self->{IMAP};
    my $limit      = $self->{LIMIT};
    my $quota      = undef;
    my $usage      = undef;
    my $usage_cent = undef;

    ( $quota, $usage, $usage_cent ) = $self->usage();
    return 0 if $usage_cent lt $limit;
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

        Mailbox => 'INBOX',
        Trend   => 'OLDEST',        # 'OLDEST' = Älteste, 'NEWEST' = Neueste Nachrichten
        Limit   => $self->{LIMIT}

    };

    while (@_) {

        my $k = ucfirst lc shift;
        my $v = shift;
        $args->{$k} = $v if defined $v;

    }

    my $mailbox = $args->{Mailbox};
    my $limit   = $args->{Limit};
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

sub notes
  #
  # Gib gesammelte Infos an den Hostprozess
  #
{

    my $self = shift;
    return $self->{Notes};

}

sub logout
  #
  # IMAP LOGOUT
  #
{

    my $self  = shift;
    my $imap  = $self->{IMAP};
    my $notes = $self->{Notes};

    return 1 unless $imap->IsConnected;

    $imap->logout;

    return 0 if $imap->IsConnected;

    %{$notes} = ();
    $notes->{'00_Status'} = 'Disconnected';

    return 1;

}

# Dateiverwaltung

sub database_new
  #
  # Erzeuge eine neue Datenbank für das Nachrichtenbackup
  #
{

    my $self   = shift;
    my $folder = $self->{DBASE};

    chdir;
    return 1 if ( -d $folder );
    mkdir( $folder, 0755 ) || die;
    return 0 if ( -d $folder );
    return

}

sub database_exists
  #
  # Gebe WAHR zurück, wenn eine Datenbasis existiert
  #
{

    my $self   = shift;
    my $folder = $self->{DBASE};

    chdir;
    return ( -d $folder );

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
