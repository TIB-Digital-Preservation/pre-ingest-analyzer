The code in this repo is a public snapshot from the TIB's digital preservation
team. Although the development happens in our internal git repo, we are very
open for feedback here on GitHub.

PIA is an interactive shell script that analyzes SIPs before they are ingested
in the digital preservation system. This allows to fix common mistakes early.


# P<sub>re</sub> I<sub>ngest</sub> A<sub>nalyzer</sub>


PIA ist ein interaktives Shell-Skript, das im Vorfeld des Ingests in
das LZA-System versucht, potentiell problematische Dateien oder
Strukturen in SIPs zu finden.


## Workflow

PIA analysiert die in der Konfiguration angegebenen SIPs. Falls die
durchgeführten Tests positiv ausfallen, werden Listen mit den betroffenen
Dateien oder Ordnern ausgegeben (Textdateien oder CSVs).

Nach dem Start des Skripts können verschiedene Test-Szenarien ausgewählt
werden. In der Regel genügt es, mit der ersten Option ("perform all checks")
einen Komplettdurchlauf durchzuführen.

Falls gewünscht, können die Tests jedoch auch selektiv gestartet werden.
Dies ist zum Beispiel sinnvoll, wenn die (vergleichsweise zeitaufwändige)
Suche nach Dubletten zu einem anderen Zeitpunkt stattfinden soll.

PIAs Ergebnisse werden in einem Unterordner abgelegt, der nach dem
Zeitstempel der Skriptausführung benannt ist.

### Konfiguration

In der Datei `pia.config` werden zur Ausführung benötige Parameter
angegeben.

__Input__  
Der Pfad zu den SIPs, die analysiert werden sollen.

__Output__  
Pfad für die von PIA erzeugten Reports.

__Check for MM__  
Gibt an, ob die SIP-Struktur einen "MODIFIED_MASTER" enthält.

__ID Depth__  
Optionaler Parameter. Gibt die relative Verzeichnistiefe der ID-Ordner in
Relation zum unter "Input" angegebenen Ort an. Im Normalfall sollte die
Angabe auskommentiert sein ("#" am Zeilenanfang), da das Skript den Wert
selbst ermittelt. Bei (bekannten) Abweichungen der Ordnerstruktur von
der Vorgabe kann der Wert hier explizit angegeben werden.

Die `search-patterns_archive_mime_types.lst` enthält eine Liste von
MIME-Types, die zur Identifikation von Archiv-Dateien verwendet werden.
Anpassungen sind hier möglich, sei es durch Hinzufügen fehlender Typen
oder die Entfernung praktisch nicht relevanter Typen.

## Voraussetzungen

### System

PIA ist ein BASH-Skript, das auf Linux oder anderen unixoiden Systemen
ausgeführt werden kann. Produktiv genutzt wird es mit Cygwin und Fedora.

Die meisten Funktionen benötigen nur Tools, die auf diesen Systemen in
der Regel vorhanden sind. Zur Analyse der Inhalte von Archivdateien kann
es jedoch notwendig sein, Programme wie Zip oder Rar zu installieren.
Das Skript erkennt das Fehlen solcher Abhängigkeiten und weist darauf
hin, dass betroffene Tests übersprungen werden.

### Installation

Das Skript muss nicht installiert werden, es kann direkt ausgeführt
werden. Ein einfaches Klonen des Repos sollte genügen. Gegebenenfalls muss
die Datei `pre-ingest-analyzer.sh` ausführbar gemacht werden:

~~~
$ chmod ug+x pre-ingest-analyzer.sh
~~~

Der Programmstart erfolgt dann mit

~~~
$ ./pre-ingest-analyzer.sh
~~~

Eventuell ist das Klonen/Kopieren des Repos nicht gewünscht. Folgende
Dateien müssen mindestens vorhanden sein:

* `pia.config`
* `pre-ingest-analyzer.sh`
* `search-patterns_archive_mime_types.lst`


## Durchgeführte Tests

__Überprüfung von Dateinamen__  
Findet Dateinamen, die gemäß der Dateinamen-Policy des TIB-Archivs nicht
erlaubt sind.

Erstellt mehrere Textdateien `filenames_____.txt` für verschiedene
Kategorien von Treffern.

__Überprüfung von Ordnernamen__  
Führt den gleichen Test mit Dateiordnern durch.

Erstellt mehrere Textdateien nach dem Schema `foldernames_____.txt`.

__Suche nach systemspezifischen Dateien__  
Findet Dateien, die automatisch von Betriebssystemen erzeugt werden. In
dem meisten Fällen sind diese ungewollt.
Derzeit sucht der Test nur nach `Thumbs.db` und `.DS_Store`.

Erstellt Textdatei `systemdateien.txt`.

__Suche nach versteckten Dateien/Ordnern__  
Findet Dateien/Ordner, deren Name mit einem Punkt beginnt.

Erstellt Textdatei `hidden_files.txt`.

__Suche nach leeren Dateien/Ordnern__  
Findet leere Dateien oder Ordner ohne Inhalt.

Erstellt Textdatei `empty.txt`.

__Überprüfung der SIP-Struktur__  
Überprüft, ob die ggf. erforderlichen Ordner "MASTER", "MODIFIED_MASTER"
oder "DERIVATIVE_COPY" vorhanden sind oder unerlaubte Ordner in der
Struktur auftauchen.

Erstellt Textdatei `sip_structure_not_ok.txt`.

__Suche nach großen Dateien__  
Findet Dateien, die größer als 2 GiB sind.

Erstellt Textdatei `big_files.txt`.

__Suche nach Dubletten__  
Findet Dateien, die doppelt auftauchen, ohne false positives zu melden,
die aus der erwarteten Duplikation durch derivative Dateien entstehen.

Erstellt Textdatei `duplicates_sorted_by_occurance.txt`. Die Treffer
sind blockweise nach ihrer Häufigkeit aufsteigend sortiert.

__Suche nach Archivdateien__  
Listet Archivdateien auf, die anhand ihres MIME-Typs identifiziert werden.
Die Datei `search-patterns_archive_mime_types.lst` enthält die Liste der
gesuchten Typen. Einige Dateien (z.B. manche ePubs oder Office Dokumente)
werden aus der initialen Trefferliste als false positives entfernt.

Die Ergebnisse können Dubletten enthalten. Da die Bezeichnungen von MIME
types wie z.B. "application/x-rar" und "application/x-rar-compressed"
teilweise identisch sind, werden letztere auch beim ersten Typ gefunden.

_Ressource Forks (macOS):_  
Im Anschluss werden alle ZIP-Archive nach macOS-Ressource-Fork-Dateien
durchsucht und die Treffer aufgelistet.

Erstellt die CSV-Datei `archive_files.csv`. Diese enthält die Pfad- und
Dateiangabe, gefolgt von dem zugehörigen MIME-Typ.
Erstellt Textdatei `macos_ressource_fork_files.txt`.

## Lizenz

Dieses Projekt steht unter der [Apache 2.0 License](LICENSE).
