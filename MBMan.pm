#
# MBMan.pm
#
# MBMan - Eine IMAP Mailboxmanagement API.
#

package MBMan;
use strict;

our $VERSION = '0.0.5';

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

# Client-/Server-Kommunikation

sub new
  #
  # Konstruktor
  #
{

    my $class = shift;

    my $self = {

        Debug    => 0,
        Ssl      => 1,
        Peek     => 1,          # 1 = setze nicht das /SEEN Flag
        Uid      => 1,          # nutze UID
        Server   => '',
        User     => '',
        Password => '',
        Limit    => 80,
        Folder   => 'MBData',
        IdWidth  => 6,
        MaxSize  => 0,
        SaveChk  => 1           # Nach dem Speichern Datei prüfen

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

    $self->{Notes}->{'00_Status'} = 'New';

    return $self;

}

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

    my $imap   = $self->{Imap};
    my $notes  = $self->{Notes};
    my $server = $self->{Server};
    my $debug  = $self->{Debug};

    return 1 if $imap->IsConnected;
    return 0 unless $server;

    $imap->Server($server);
    $imap->connect || return 0;

    if ($debug) {

        # slurp
        my $s_resp = $imap->LastIMAPCommand;
        my $s_id   = $imap->tag_and_run('ID NIL');
        my $s_capa = $imap->capability;

        # transmutation
        $s_resp = &_str_chomp($s_resp);
        $s_id   = &_str_chomp( ${$s_id}[1] );

        # spit out
        $notes->{'10_ServerResponse'} = $s_resp;
        $notes->{'11_ServerIDTag'}    = $s_id;
        $notes->{'12_ServerCapa'}     = $s_capa;

    }
    else {

        my $s_id = $imap->tag_and_run('ID NIL');
        $s_id = &_str_chomp( ${$s_id}[1] );
        $notes->{'11_ServerIDTag'} = $s_id;

    }

    $notes->{'00_Status'} = 'Connected';
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

    my $imap  = $self->{Imap};
    my $notes = $self->{Notes};
    my $user  = $self->{User};
    my $pass  = $self->{Password};
    my $debug = $self->{Debug};
    my $data  = undef;

    return 1 if $imap->IsAuthenticated;
    return 0 unless $imap->IsConnected;
    return 0 unless $user;
    return 0 unless $pass;
    return 0 unless $imap->has_capability('AUTH=CRAM-MD5');

    $imap->User($user);
    $imap->Password($pass);
    $imap->Authmechanism('CRAM-MD5');
    $imap->login;

    return 0 unless $imap->IsAuthenticated;

    if ($debug) {

        my $capa = $imap->capability;
        $notes->{'20_UserCapa'} = $capa;

    }

    $notes->{'00_Status'} = 'Authenticated';
    return 1;

}

sub quota
  #
{
    my $self     = shift;
    my $imap     = $self->{Imap};
    my $notes    = $self->{Notes};
    my $quota    = 0;
    my $usage    = 0;
    my $usage100 = 0;

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

    $usage    = "$usage";
    $quota    = "$quota";
    $usage100 = $usage / $quota * 100;

    $notes->{'21_UserQuota'}    = $quota;
    $notes->{'22_UserUsage'}    = $usage;
    $notes->{'23_UserUsage100'} = $usage100;

    return ( $quota, $usage, $usage100 );

}

sub folders
  #
  # Holt die aktuelle Liste der Postfächer
  #
{

    my $self = shift;
    my $imap = $self->{Imap};

    return 0 unless $imap->IsAuthenticated;

    my $notes    = $self->{Notes};
    my @fhashes  = $imap->folders_hash;
    my $folders  = ();
    my $specials = {};
    my $data     = {};

    foreach my $fhash (@fhashes) {

        next unless defined $fhash->{name};

        my $filter = 'All|Archive|Drafts|Flagged|Junk|Sent|Trash';
        my @special = grep { /$filter/ } @{ $fhash->{attrs} };
        if (@special) { $specials->{ $special[0] } = $fhash->{name}; }
        push @{$folders}, $fhash->{name};

    }

    $notes->{'30_Folders'}  = $folders;
    $notes->{'31_Specials'} = $specials;
    $data->{Folders}        = $folders;
    $data->{Specials}       = $specials;
    return $data;

}

sub message_unshift
  #
  # Holt die älteste Nachricht eines Postfaches vom Server
  #
{

    my $self = shift;
    my $args = {

        Mailbox => 'INBOX',
        Expunge => 0,
        Save    => 1          # Nachricht nach dem Herunterladen automatisch speichern

    };

    while (@_) {

        my $k = ucfirst lc shift;
        my $v = shift;
        $args->{$k} = $v if defined $v;

    }

    my $data    = undef;
    my $mailbox = $args->{Mailbox};
    my $expunge = $args->{Expunge};
    my $save    = $args->{Save};
    my $imap    = $self->{Imap};
    my $notes   = $self->{Notes};
    my $maxsize = $self->{MaxSize};

    return 0 unless $imap->IsAuthenticated;
    return 0 unless $imap->exists($mailbox);

    $imap->examine($mailbox) || return 0;
    my $uid_list = $imap->messages || return 0;

    return 0 unless scalar @{$uid_list};

    my $uid  = ${$uid_list}[0];
    my $size = $imap->size($uid);

    return 0 if $maxsize and ( $size > $maxsize );

    my $message = $imap->message_string($uid);

    $data->{'00_Uid'}          = $uid;
    $data->{'01_UidValidity'}  = $imap->uidvalidity($mailbox);
    $data->{'02_InternalDate'} = $imap->internaldate($uid);
    $data->{'03_HeaderDate'}   = $imap->date($uid);
    $data->{'04_ServerSize'}   = $size;
    $data->{'05_ReceivedSize'} = length($message);
    $data->{'06_MD5'}          = md5_hex($message);
    $data->{'10_Message'}      = $message;
    $notes->{'40_LastMessage'} = $data;

    # Wenn eine Nachricht nach dem Holen auf dem Server gelöscht werden soll,
    # wird eine lokale Kopie der Nachricht automatisch erstellt.
    # Dabei gilt: Nur, wenn die Nachricht auch wirklich gesichert wurde,
    # wird sie auch auf dem Server gelöscht.

    return $data unless $save or $expunge;
    return 0     unless $self->message_save();
    return $data unless $expunge;
    $imap->select($mailbox);
    $imap->delete_message($uid);
    $imap->expunge;
    return $data;

}

sub limit_reached
  #
  # Gibt WAHR zurück, wenn das voreingestellte Limit eines
  # Nutzerkontos überschritten wurde
  #
{
    my $self  = shift;
    my $imap  = $self->{Imap};
    my $notes = $self->{Notes};

    return 0 unless $imap->IsAuthenticated;

    my ( $quota, $usage, $usage100 ) = $self->quota;

    return 0 if $usage100 lt $self->{Limit};
    return 1;

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
    my $imap  = $self->{Imap};
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
    my $folder = $self->{Folder};

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
    my $folder = $self->{Folder};

    chdir;
    return ( -d $folder );

}

sub message_save
  #
  # Schreibe die letzte abgerufene Nachricht in die Datenbank
  #
{

    my $self   = shift;
    my $folder = $self->{Folder} // 0;
    my $user   = $self->{User} // 0;
    my $notes  = $self->{Notes} // 0;
    my $width  = $self->{IdWidth} // 0;

    return 0 unless $folder && $user && $notes && $width;

    my $message = $notes->{'40_LastMessage'} // 0;

    return 0 unless $message;

    my $uid    = $message->{'00_Uid'}         // 0;
    my $uidval = $message->{'01_UidValidity'} // 0;
    my $md5    = $message->{'06_MD5'}         // 0;
    my $text   = $message->{'10_Message'}     // 0;

    return 0 unless $uid && $uidval && $md5 && $text;

    my $savechk = $self->{SaveChk};

    chdir || die('Kann nicht in das Home-Verzeichnis wechseln');

    return 0 unless ( -d $folder );

    chdir $folder || die('Kann nicht in die Datenbank wechseln');
    mkdir( $user, 0755 ) unless ( -d $user );
    chdir $user || die('Kann nicht in den Benutzerzweig wechseln');

    my $filename = $uidval;
    $filename .= " - " . ( sprintf "%0" . $width . "d", $uid );
    $filename .= ".eml";

    my $handle = FileHandle->new( $filename, "w" );
    print $handle $text;
    undef $handle;

    return 0 unless ( -f $filename );
    return 1 unless $savechk;

    $handle = FileHandle->new( $filename, "r" );
    my $text2 = do { local $/; <$handle> };
    undef $handle;

    return 0 unless $text eq $text2;
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
