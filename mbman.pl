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

my %messages = (

    need_command => 'mbman.pl erwartet einen Befehl. Hilfe über "mbman.pl -h"!',
    need_args    => 'mbman.pl erwartet Argumente. Hilfe über "mbman.pl -h"!',
    saved        => 'Nachricht wurde erfolgreich gespeichert'

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
our $opt_i = 0;     # print info at max collector level

our $mbman = undef;

exit &main();       # Hauptprogramm

sub main {

    if (@ARGV) {

        getopts('S:U:P:hveclfqudsi');
        $opt_h and do { help_print(); return 1 };

        $mbman = MBMan->new( Debug => $opt_v );

        if ( $opt_c and $opt_S ) {

            $mbman->connect( Server => $opt_S );

        }

        if ( $opt_l and $opt_U and $opt_P ) {

            $mbman->login(
                User     => $opt_U,
                Password => $opt_P,
            );

        }

        if ($opt_f) {

            $mbman->folders;

        }

        if ($opt_q) {

            $mbman->quota;

        }

        if ($opt_u) {

            $mbman->message_unshift( Expunge => $opt_e );

        }

        if ($opt_d) {

            $mbman->database_new;

        }

        if ($opt_s) {

            say $messages{saved} if $mbman->message_save;

        }

        if ($opt_i) {

            &status_print;

        }

        $mbman->logout();

    }
    else {

        say $messages{need_command};

    }

    return 0;

}

sub status_print {

    my $ax = $mbman->notes;
    print Dumper $ax;

}

sub help_print
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
