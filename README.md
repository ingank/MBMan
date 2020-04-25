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
* Username / Nutzerkennung
  * Eine dem IMAP-Server bekannte Zeichenfolge für einen Nutzer.
* User Account / Nutzerkonto
  * Eine Datenbank, die einer bestimmten Nutzerkennung zugeordnet ist. Die Datenbank besteht aus Mailboxen und diesen Mailboxen zugeordneten Nachrichten.
* Mailbox
  * Eine Mailbox kann als Ordner innerhalb eines Nutzerkontos aufgefasst werden. Beachte: ein Wurzelordner ohne Namen ist nicht vorgesehen. Dementsprechend ist jede Nachricht einer bestimmten Mailbox zugeordnet. Es können untergeordnete Mailboxen erstellt und genutzt werden. Die Standard-Mailbox trägt den Namen *INBOX*.
* Connection / Verbindung
  * Eine IMAP4-Verbindung besteht aus Client-Server-Kommandos und Server-Client-Antworten. Sie besteht zeitlich gesehen direkt vom Ende des Aufbaus bis zum Beginn des Abbaus eines stabilen Datenstroms (link layer).
* Command / Befehl
  * Ein IMAP4-Befehl eines Clients an den Server.
* Response / Antwort
  * Eine IMAP4-Antwort eines Servers an den Client.
* State *of connection* / Zustand *der Verbindung*
  * Established / Verbunden
    * konretisiert den Zustand einer stehenden **Verbindung** zwischen Client und Server. IMAP4-Befehle und Antworten können übermittelt werden.
  * Authenticated / Authentifiziert
    * der Nutzer konnte sich gegenüber dem IMAP-Server identifizieren. (Erfolgreicher `LOGIN` oder `AUTHENTICATE` Befehl)
  * Selected / Angewählt
    * Eine bestimmte Mailbox wurde angewählt. Wurde der Zustand 'Selected' mit Hilfe des Befehls `SELECT` herbeigeführt, kann auf Inhalte lesend und schreibend zugegriffen werden. Auf mit Hilfe des Befehls `EXAMINE` selektierte Mailboxen kann ausschließlich lesend zugegriffen werden.

## IMAP4 Implementationen
* [RFCs Supported by Cyrus IMAP](https://github.com/cyrusimap/cyrus-imapd/blob/master/docsrc/imap/rfc-support.rst)
