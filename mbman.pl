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

our $opt_S = '';    # server name
our $opt_U = '';    # user
our $opt_P = '';    # password
our $opt_h = 0;     # help
our $opt_v = 0;     # verbose
our $opt_e = 0;     # expunge?
our $opt_c = 0;     # connect
our $opt_l = 0;     # login
our $opt_f = 0;     # folder list
our $opt_q = 0;     # quota
our $opt_u = 0;     # unshift message
our $opt_d = 0;     # new database
our $opt_s = 0;     # save message

our $mbman = undef;

exit &main();       # Hauptprogramm

sub main {

    if (@ARGV) {

        getopts('S:U:P:hveclfquds');
        $opt_h and do { &print_help(); return 1 };

        $mbman = MBMan->new( Debug => $opt_v );

        $opt_c and do { &connect };
        $opt_l and do { &login };
        $opt_f and do { &folders };
        $opt_q and do { &quota };
        $opt_u and do { &unshift_message };
        $opt_d and do { &new_database };
        $opt_s and do { &save_message };

     #   &print_status;

        &disconnect;

        #       &print_status;

    }

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

    my $ax = $mbman->notes;
    print Dumper $ax;

}

sub folders {

    $mbman->folders;

}

sub quota {

    $mbman->quota;

}

sub unshift_message
  #
  #
  #
{

    $mbman->unshift_message( Expunge => $opt_e );

}

sub new_database
  #
{

    $mbman->new_database;

}

sub save_message
  #
{

    say "erfolgreich geschrieben" if $mbman->save_message;

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
