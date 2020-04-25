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
our $opt_i = 0;    # mailbox-info
our $opt_l = 0;    # message-infos
our $opt_s = 0;
our $opt_t = 0;    # test
our $opt_f = 0;    # fetch message

our $mbman = undef;

exit &main();      # Hauptprogramm

sub main {

    if (@ARGV) {

        getopts('S:U:P:hvilstf');
        $opt_h and do { &print_help(); return 1 };

        $mbman = MBMan->new( Debug => $opt_v, Peek => 0 );

        $opt_i and do { &print_mailbox_info;  return 1 };
        $opt_l and do { &print_message_infos; return 1 };
        $opt_f and do { &fetch_message;       return 1 };

        &print_info(0);
        return 0;

    }

    &print_info(1);
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

    $mbman->logout;

}

sub print_mailbox_info
  #
  # Allgemeine Infos über das IMAP-Postfach ermitteln und ausgeben.
  #
{

    &connect;
    &login;

    my $info = $mbman->mailbox_info;
    print Dumper ($info);

    &disconnect;

}

sub print_message_infos
  #
  #
  #
{

    &connect;
    &login;

    my $info = $mbman->get_messages_info( Modus => 'Full', HashEnv => 1, DecodeMime => 1 );
    print Dumper ($info);

    &disconnect;

}

sub fetch_message
  #
  #
  #
{

    &connect;
    &login;

    my $message = $mbman->fetch_message( Uid => '644', ReadOnly => 0 );
    print Dumper ($message);

    &disconnect;

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
