#
# MBMan.pm
#
# MBMan - Eine IMAP Mailboxmanagement API.
#

package MBMan;
use strict;

our $VERSION = '0.0.3';

use warnings;
use diagnostics;
use feature qw(say);
use Storable;
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

# Client-/Server-Kommunikation

sub new
  #
  # Konstruktor
  #
{

    my $class = shift;

    my $self = {

        Debug     => 0,
        Ssl       => 1,
        Peek      => 1,           # 1 = setze nicht das /SEEN Flag
        Uid       => 1,           # nutze UID
        Server    => '',
        User      => '',
        Password  => '',
        Limit     => 80,
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
        $s_resp = &_chomp_str($s_resp);
        $s_id   = &_chomp_str( ${$s_id}[1] );

        # spit out
        $notes->{'10_ServerResponse'} = $s_resp;
        $notes->{'11_ServerIDTag'}    = $s_id;
        $notes->{'12_ServerCapa'}     = $s_capa;

    }
    else {

        my $s_id = $imap->tag_and_run('ID NIL');
        $s_id = &_chomp_str( ${$s_id}[1] );
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

    $imap->User($user);
    $imap->Password($pass);
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

    my $self  = shift;
    my $imap  = $self->{Imap};
    my $notes = $self->{Notes};

    return 0 unless $imap->IsAuthenticated;

    # my $folders  = $imap->folders;
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

sub unshift_message
  #
  # Holt die älteste Nachricht eines Postfaches vom Server
  #
{

    my $self = shift;
    my $args = {

        Mailbox => 'INBOX',
        Expunge => 0,

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

    return 0 unless $imap->IsAuthenticated;
    return 0 unless $imap->exists($mailbox);

    $imap->examine($mailbox) || return 0;
    my $uid_list = $imap->messages || return 0;

    return 0 unless scalar @{$uid_list};

    my $uid     = ${$uid_list}[0];
    my $message = $imap->message_string($uid);
    $data->{'00_UidValidity'}  = $imap->uidvalidity($mailbox);
    $data->{'01_InternalDate'} = $imap->internaldate($uid);
    $data->{'02_HeaderDate'}   = $imap->date($uid);
    $data->{'03_ServerSize'}   = $imap->size($uid);
    $data->{'04_ReceivedSize'} = length($message);
    $data->{'05_MD5'}          = md5_hex($message);
    $data->{'10_Message'}      = $message;

    if ($expunge) {

        $imap->select($mailbox);
        $imap->delete_message($uid);
        $imap->expunge;

    }

    $notes->{'40_LastMessage'} = $data;
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

sub new_database
  #
  # Erzeuge eine neue Datenbank für das Nachrichtenbackup
  #
{

}

sub database_exists
  #
  # Gebe WAHR zurück, wenn eine Datenbasis existiert
  #
{

}

sub save_message
  #
  # Schreibe eine Nachricht in die Datenbank
  #
{

}

# interne Funktionen

sub _chomp_str
  #
{

    my $str = shift;

    return unless $str;

    $str =~ s/\r\n|\r|\n//g;
    return $str;

}

sub _chomp_array
  #
{

    my $array = shift;
    my $out   = ();

    return unless scalar @{$array};

    push @{$out}, _chomp_str($_) for @{$array};

    return $out;

}

sub _filter_array
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
