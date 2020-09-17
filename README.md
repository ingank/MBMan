# MBMan

MBMan - Eine IMAP Mailboxmanagement API in Perl.

## Installation
```
$ git clone git@github.com:ingank/MBMan.git
```

## Abhängigkeiten
```
cpan install Mail::IMAPClient
cpan Digest::MD5::File
cpan install FileHandle
```
## Anwendung
```
```

---

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

## Nomenklatur und Logik des IMAP4-Protokolls

* User / Nutzer
  * Ein menschlicher Benutzer.
* User Account / Nutzerkonto:
  * Username / Nutzerkennung
    * Die Nutzerkennung ist eine dem IMAP-Server bekannte Zeichenfolge für einen Nutzer.
  * Mailbox / Postfach
    * Dem Nutzer sind Postfächer zugeordnet.
  * Access Control List (ACL) / Zugriffskontrolle
    * Der Zugriff des Nutzers auf bestimmte Ressourcen kann mit Hilfe der Zugriffskontrolle geregelt sein.
  * Quota / Kontingent
    * Der Speicherplatz für Nachrichten kann mit Hilfe von Quotas kontingentiert werden.
* Mailbox / Postfach im Speziellen:
  * Ein Postfach kann als Ordner innerhalb eines Nutzerkontos aufgefasst werden.
  * Das Standard-Postfach trägt den Namen *INBOX*.
  * Jede Nachricht ist einem bestimmten Postfach zugeordnet.
  * Es können untergeordnete Postfächer erstellt werden.
  * Untergeordnete Mailboxen werden durch ein vom IMAP4-Server festgelegtes Zeichen (engl.: Delimiter) getrennt. Beispiel: *INBOX.Foo*
* Connection / Verbindung
  * Eine IMAP4-Verbindung besteht aus Client-Server-Kommandos und Server-Client-Antworten.
  * Sie besteht zeitlich gesehen direkt vom Ende des Aufbaus bis zum Beginn des Abbaus eines stabilen Datenstroms (link layer).
* Command / Befehl
  * Ein IMAP4-Befehl eines Clients an den Server.
* Response / Antwort
  * Eine IMAP4-Antwort eines Servers an den Client.
* State *of connection* / Zustand *der Verbindung*
  * Any State / (in) jedem Zustand
    * konretisiert den Zustand einer bestehenden **Verbindung** zwischen Client und Server. Dies schließt auch alle übergeordneten Zustände ein.
    * Mögliche IMAP-Befehle laut RFC3501:
      * CAPABILITY
      * NOOP
      * LOGOUT
  * Not Authenticated / Nicht authentifiziert
    * konkretisiert den Zustand vor/während der Authentifizierung des Users gegenüber dem Server.
    * wird beispielsweise mit der Server-Antwort `* OK IMAP4rev1 server ready` eingeleitet.
    * Mögliche IMAP-Befehle laut RFC3501:
      * CAPABILITY
      * NOOP
      * LOGOUT
      * STARTTLS
      * AUTHENTICATE
      * LOGIN
  * Authenticated / Authentifiziert
    * der Nutzer konnte sich gegenüber dem IMAP-Server identifizieren.
    * es wurde also ein erfolgreicher `LOGIN` oder `AUTHENTICATE` Befehl gesendet.
  * Selected / Angewählt
    * Eine bestimmte Mailbox wurde angewählt.
    * Der *angewählte Zustand* wurde mit dem IMAP4-Befehl `SELECT` herbeigeführt:
      * Auf die Mailbox kann lesend und schreibend zugegriffen werden.
    * Der *angewählte Zustand* wurde mit dem IMAP4-Befehl `EXAMINE` herbeigeführt:
      * Auf die Mailbox kann ausschließlich lesend zugegriffen werden.

## IMAP4-Server-Implementationen
* [Cyrus IMAP](https://www.cyrusimap.org/) || [RFCs Supported by Cyrus IMAP](https://github.com/cyrusimap/cyrus-imapd/blob/master/docsrc/imap/rfc-support.rst)
* [Courier Mail Server](https://www.courier-mta.org/) || [Courier IMAP](https://www.courier-mta.org/imap/)
* [Dovecot IMAP and POP3 email server](https://doc.dovecot.org/)
