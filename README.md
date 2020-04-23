# MBMan
Ein IMAP-Mailboxmanager in Perl.

## RFCs zum IMAP4-Protokoll
* [RFC1730](https://tools.ietf.org/html/rfc1730) 
  * INTERNET MESSAGE ACCESS PROTOCOL - VERSION 4
  * ersetzt durch [RFC2060](https://tools.ietf.org/html/rfc2060)
* [RFC2060](https://tools.ietf.org/html/rfc2060)
  * INTERNET MESSAGE ACCESS PROTOCOL - VERSION 4rev1
  * ersetzt durch [RFC3501](https://tools.ietf.org/html/rfc3501)
* [RFC3501](https://tools.ietf.org/html/rfc3501)
  * INTERNET MESSAGE ACCESS PROTOCOL - VERSION 4rev1

---

* [RFC1731](https://tools.ietf.org/html/rfc1731)
  * IMAP4 Authentication Mechanisms
* [RFC2359](https://tools.ietf.org/html/rfc2359)
  * IMAP4 UIDPLUS extension
* [RFC2971](https://tools.ietf.org/html/rfc2971)
  * IMAP4 ID extension

## Fachausdrücke im Sinne der IMAP VERSION 4rev1

* User / Nutzer
  * Ein menschlicher Benutzer.
* Username / Nutzername
  * Eine dem IMAP-Server bekannte Zeichenfolge.
* User Account / Nutzerkonto
  * Eine Datenbank bestehend aus Mailboxen und Emailnachrichten, die einem bestimmten Nutzernamen zugeordnet sind.
* Mailbox
  * Eine Mailbox kann als Ordner innerhalb eines Nutzerkontos aufgefasst werden. Beachte: ein Wurzelordner ohne Namen ist nicht vorgesehen. Dementsprechend ist jede Emailnachricht einer bestimmten Mailbox zugeordnet. Es können Unterordner (genauer: untergeordnete Mailboxen) erstellt und genutzt werden. Die Standard-Mailbox trägt den Namen `INBOX`.
* Connection / Verbindung
  * Eine IMAP4-Verbindung besteht aus Client-Server-Kommandos und Server-Client-Antworten. Sie besteht zeitlich gesehen direkt vom Ende des Aufbaus bis zum Beginn des Abbaus eines stabilen Datenstroms (link layer).
* Command / Befehl
  * Ein IMAP4-Befehl eines Clients an den Server.
* Response / Antwort
  * Eine IMAP4-Antwort eines Servers an den Client.
* (Connection) State / (Verbindungs-) Status
  * Established / Verbunden
    * konretisiert den Zustand **Verbindung**.
  * Authenticated / Authentifiziert
    * der Nutzer konnte sich gegenüber dem IMAP-Server identifizieren. (Erfolgreiches `LOGIN` oder `AUTHENTICATE` Kommando)
  * Selected / Angewählt
    * Eine bestimmte Mailbox wurde angewählt. Wurde der Zustand 'Selected' mit Hilfe des Kommandos `SELECT` herbeigeführt, kann auf Inhalte lesend und schreibend zugegriffen werden. Auf mit Hilfe des Kommandos `EXAMINE` selektierte Mailboxen kann ausschließlich lesend zugegriffen werden.

## IMAP4 Implementationen
* [RFCs Supported by Cyrus IMAP](https://github.com/cyrusimap/cyrus-imapd/blob/master/docsrc/imap/rfc-support.rst)
