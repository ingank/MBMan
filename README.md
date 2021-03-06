# MBMan

Eine IMAP Mailboxmanagement API in Perl.

## Installation
```
git clone git@github.com:ingank/MBMan.git
```
## Abhängigkeiten auflösen
```
cpan
> reload index
> install Mail::IMAPClient
> install Digest::MD5::File
> install Digest::HMAC_MD5
> install IO::Socket::SSL
> quit
```

## Anwendung
```
use MBMan;

my $mbman = MBMan->new();

$mbman->connect(
    SERVER => 'imap.server.tld'
);

$mbman->login(
    USER => 'user@domain.tld',
    PASS => 'pa$$w0rd'
);

my $uidlist = $mbman->limitlist(
    MAILBOX => 'foo',
    LIMIT => 80
}

my $message = $mbman->message(
    UID => $uidlist->[0],
    MAILBOX => 'foo',
    EXPUNGE => 0
);

$mbman->save( $message );

$mbman->logout();
```
## Lokales Backup inspizieren
MBMan kann ein lokales Backup der auf einem IMAP-Server befindlichen Nachrichten anfertigen.
Die einzelnen Nachrichten werden im sogennanten EML-Format in lokalen Ordnern abgelegt.
Zur Inspektion dieser Emails und vor allem zur Suche nach bestimmten Nachrichten kann folgende
Vorgehensweise sinnvoll sein:

* Installation des Thunderbird Email-Clients.
* Installation des Add-ons 'ImportExportTools NG' von Christopher Leidigh:
  * Klick auf 'Drei Striche' oben rechts.
  * Klick auf 'Add-ons'.
  * Klick auf 'Add-ons'.
  * Im Suchfeld 'Import' eingeben.
  * 'ImportExportTools NG' 'Zu Thunderbird hinzufügen'.
  * Neustart bestätigen.
* Import von lokalen Backup-Ordnern:
  * Rechts-Klick auf 'lokale Ordner' links im Ordnerbaum.
  * Klick auf 'Neuer Ordner...'
  * Beliebigen Ordnernamen eingeben.
  * Klick auf 'Ordner erstellen'.
  * Rechts-Klick auf neuen Ordner.
  * Gehe zu 'ImportExportTools NG'.
  * Gehe zu 'Importiere alle Nachrichten eines Verzeichnisses'.
  * Klick auf 'Auch aus den Unterverzeichnissen'.
  * Navigiere zum gewünschten Mailbox-Ordner.
  * Mailbox-Ordner markieren.
  * Klick auf 'Öffnen'
  * Nach dem Import kann auf alle Nachrichten wie in Thunderbird üblich zugegriffen werden.
* Nach der Inspektion:
  * Der lokale Ordner innerhalb von Thunderbird kann wieder gelöscht werden.
* Vorteile:
  * Schnelle Suchen und Filter anwenden.
  * Stabile Dekodierung von MIME-codierten Nachrichten.
  * Nochmalige automatische Kopie der Original-Nachrichten beim Importieren. Dadurch wird die Gefahr eines Datenverlustes minimiert.
* Nachteile:
  * Das Importieren kostet zusätzlich Zeit und Festplattenplatz.

## RFCs zum IMAP4-Protokoll
* [RFC1730](https://tools.ietf.org/html/rfc1730) 
  * INTERNET MESSAGE ACCESS PROTOCOL - VERSION 4
  * ersetzt durch [RFC2060](https://tools.ietf.org/html/rfc2060)
* [RFC2060](https://tools.ietf.org/html/rfc2060)
  * INTERNET MESSAGE ACCESS PROTOCOL - VERSION 4rev1
  * ersetzt durch [RFC3501](https://tools.ietf.org/html/rfc3501)
* [RFC3501](https://tools.ietf.org/html/rfc3501)
  * INTERNET MESSAGE ACCESS PROTOCOL - VERSION 4rev1
* [RFC6154](https://tools.ietf.org/html/rfc6154)
  * IMAP LIST Extension for Special-Use Mailboxes
  * Es geht um spezielle Mailboxen ( \Drafts, \Junk, \Trash, ... )
* [RFC2087](https://tools.ietf.org/html/rfc2087)
  * IMAP4 QUOTA extension
* [RFC2359](https://tools.ietf.org/html/rfc2359)
  * IMAP4 UIDPLUS extension
* [RFC2971](https://tools.ietf.org/html/rfc2971)
  * IMAP4 ID extension
* [RFC1731](https://tools.ietf.org/html/rfc1731)
  * IMAP4 Authentication Mechanisms

## Nomenklatur und Logik des IMAP4rev1-Protokolls

* User / Nutzer
  * Ein menschlicher Benutzer.
* User Account / Nutzerkonto:
  * Username / Nutzerkennung
    * Die Nutzerkennung ist eine dem IMAP-Server bekannte Zeichenfolge für einen Nutzer.
  * Mailbox / Postfach
    * Dem Nutzer sind Postfächer zugeordnet.
    * Ein Postfach kann als Ordner innerhalb eines Nutzerkontos aufgefasst werden.
    * Das Standard-Postfach trägt den Namen *INBOX*.
    * Jede Nachricht ist einem bestimmten Postfach zugeordnet.
    * Es können untergeordnete Postfächer erstellt werden.
    * Untergeordnete Postfächer werden durch ein vom IMAP4-Server festgelegtes Zeichen (engl.: Delimiter) getrennt. Beispiel: *INBOX.Foo*
  * Access Control List (ACL) / Zugriffskontroll-Liste
    * Der Zugriff des Nutzers auf bestimmte Ressourcen kann mit Hilfe von ACLs (Zugriffskontroll-Listen) geregelt sein.
  * Quota / Kontingent
    * Der Speicherplatz für Nachrichten kann mit Hilfe von Quotas kontingentiert werden.
* Connection / Verbindung
  * Eine IMAP4-Verbindung besteht aus Client-Server-Kommandos und Server-Client-Antworten.
  * Sie besteht vom Ende des Aufbaus bis zum Beginn des Abbaus eines stabilen Datenstroms (link layer).
* Command / Befehl
  * Ein IMAP4-Befehl eines Clients an den Server.
* Response / Antwort
  * Eine IMAP4-Antwort eines Servers an den Client.
* State *of connection* / Zustand *der Verbindung*
  * Any State / (in) jedem Zustand
    * konkretisiert den Zustand einer bestehenden **Verbindung** zwischen Client und Server.
    * Dies schließt auch alle übergeordneten Zustände ( Not Authenticated, Authenticated, Selected ) ein.
    * Capabilities (Mögliche IMAP-Befehle) laut RFC3501:
      * CAPABILITY
      * NOOP
      * LOGOUT
  * Not Authenticated State / Nicht authentifizierter Zustand
    * konkretisiert den Zustand vor/während der Authentifizierung des Users gegenüber dem Server.
    * Dieser Zustand besteht direkt nach dem Server-Greeting (Server-Begrüßung).
    * Beispiel für eine Begrüßung: * OK IMAP4rev1 server ready`.
    * Capabilities (Mögliche IMAP-Befehle) laut RFC3501 (zusätzlich zu den Befehlen im *Any State*):
      * STARTTLS
      * AUTHENTICATE
      * LOGIN
  * Authenticated State / Authentifizierter Zustand
    * der Nutzer konnte sich gegenüber dem IMAP-Server authentifizieren.
    * es wurde also ein erfolgreicher `LOGIN` oder `AUTHENTICATE` Befehl gesendet.
    * Capabilities (Mögliche IMAP-Befehle) laut RFC3501 (zusätzlich zu den Befehlen im *Any State* und *Not Authenticated State*):
      * SELECT
      * EXAMINE
      * CREATE
      * DELETE
      * RENAME
      * SUBSCRIBE
      * UNSUBSCRIBE
      * LIST
      * LSUB
      * STATUS
      * APPEND
  * Selected State / Angewählter Zustand
    * Ein bestimmtes Postfach wurde angewählt.
    * Der *angewählte Zustand* wurde mit dem IMAP4-Befehl `SELECT` herbeigeführt:
      * Auf die Mailbox kann lesend und schreibend zugegriffen werden.
    * Der *angewählte Zustand* wurde mit dem IMAP4-Befehl `EXAMINE` herbeigeführt:
      * Auf die Mailbox kann ausschließlich lesend zugegriffen werden.
    * Capabilities (Mögliche IMAP-Befehle) laut RFC3501 (zusätzlich zu den Befehlen im *Any State*, *Not Authenticated State* und *Authenticated State*):
      * CHECK
      * CLOSE
      * EXPUNGE
      * SEARCH
      * FETCH
      * STORE
      * COPY
      * UID

## IMAP4-Server-Implementationen
* [Cyrus IMAP](https://www.cyrusimap.org/) || [RFCs Supported by Cyrus IMAP](https://github.com/cyrusimap/cyrus-imapd/blob/master/docsrc/imap/rfc-support.rst)
* [Courier Mail Server](https://www.courier-mta.org/) || [Courier IMAP](https://www.courier-mta.org/imap/)
* [Dovecot IMAP and POP3 email server](https://doc.dovecot.org/)
