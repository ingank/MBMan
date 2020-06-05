#!/usr/bin/perl
#
# mbman.pl
#
# Kommandoszeilentool zum Testen des Moduls MBMan.
#

use strict;
use warnings;
use diagnostics;

use lib '.';
use MBMan;
use feature 'say';
use Getopt::Std;
use Pod::Usage;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse    = 1;
$Data::Dumper::Indent   = 1;

my @messages = (
    'mbman.pl erwartet einen Befehl. Hilfe über "mbman.pl -h"!',
    'mbman.pl erwartet Argumente. Hilfe über "mbman.pl -h"!'
);

our $opt_S = '';
our $opt_U = '';
our $opt_P = '';
our $opt_h = 0;
our $opt_v = 0;    # verbose
our $opt_c = 0;    # connect
our $opt_l = 0;    # login
our $opt_s = 0;    # server-info
our $opt_a = 0;    # account-info
our $opt_m = 0;    # messages-info
our $opt_f = 0;    # fetch message
our $opt_t = 0;    # any test

our $mbman = undef;

exit &main();      # Hauptprogramm

sub main {

    if (@ARGV) {

        getopts('S:U:P:hvclsamft');
        $opt_h and do { &print_help(); return 1 };

        $mbman = MBMan->new( Debug => $opt_v, Peek => 0 );

        #&print_status;

        $opt_c and do { &connect };
        $opt_l and do { &login };
        $opt_s and do { &print_server_info };
        $opt_a and do { &print_account_info };
        $opt_m and do { &print_messages_infos };
        $opt_f and do { &fetch_message };
        $opt_t and do { &test };

        &disconnect;

        return 0;

    }

    print_info(1);
    return 0;

}

sub connect {

    if ($opt_S) {

        $mbman->connect( Server => $opt_S );

    }

}

sub login {

    if ( $opt_U and $opt_P ) {

        $mbman->login(
            User     => $opt_U,
            Password => $opt_P,
        );

    }

}

sub disconnect {

    $mbman->logout();

}

sub print_status {

    my $ax = $mbman->info;
    print Dumper $ax;

}

sub print_server_info
  #
  # Allgemeine Infos über den IMAP-Server ermitteln und ausgeben.
  #
{

    my $info = $mbman->get_server_info;
    print Dumper ($info);

    #    print Dumper ($mbman);

}

sub print_account_info
  #
  # Allgemeine Infos über den IMAP-Server-Account ermitteln und ausgeben.
  #
{

    my $info = $mbman->get_account_info;
    print Dumper ($info);

}

sub print_messages_info
  #
  # Allgemeine Infos über das IMAP-Postfach ermitteln und ausgeben.
  #
{

    my $info = $mbman->get_messages_info( Modus => 'Full', HashEnv => 1, DecodeMime => 1 );
    print Dumper ($info);

}

sub fetch_message
  #
  #
  #
{

    # my $message = $mbman->fetch_message( Uid => '644', ReadOnly => 0 );
    my $message = $mbman->unshift_message( Expunge => 1 );
    print Dumper ($message);

}

sub test
  #
  #
  #
{

    my $ret = $mbman->get_folder_list;
    print Dumper ($ret);

}

sub print_info
  #
  # Ausgabe von Hinweisen für den Benutzer
  #
{

    my $m = shift;
    say $messages[$m];

}

sub print_help
  #
  # Ausgabe der internen POD ( Plain Old Documentation ) des Programms
  #
{

    pod2usage(
        -verbose    => 2,
        -perldocopt => "-T"
    );

}

__END__

=encoding UTF-8

=head1 NAME
 
B<mbman.pl> ( Version 0.0.1 )

=head1 FUNKTION

Kommandoszeilentool zum Zugriff auf die MBMan API.

=head1 ANWENDUNG
 
accman.pl [-hv][-S Servername[:Port]][-U Username -P Passwort]

=head1 OPTIONEN

=over
 
=item B<-h>
 
Zeige die Hilfeseite an und beende das Programm.

=item B<-v>

Das Programm gibt zusätzliche Informationen aus (verbose).

=item B<-S Server[:Port]>

Hostadresse und Port des IMAP4S-Servers. Standardport = 993.

=item B<-U Username>

Der für den IMAP-Login zu verwendende Nutzername
(bei großen Email-Hostern meist in der Form 'foo@bar.tld').

=item B<-P Passwort>

Das für den IMAP-Login zu verwendende Passwort.

=back

=head1 BEFEHLE

=over

=item B<-i>

Sammle Infos über das IMAP-Postfach und gib sie auf dem Bildschirm aus.

=back 

=cut
