# Sound-Programme für den AC1

## Hintergrund

Auf der Website [Robotron](https://sites.google.com/view/robotron) wird eine Soundkarte für K1520-Systeme vorgestellt.

Der zugehörige Diskussionsthread zum Aufbau der Soundkarte ist im [Robotrontechnik-Forum (#14846)](https://www.robotrontechnik.de/html/forum/thwb/showtopic.php?threadid=14846) zu finden.

## Funktionsweise

Die Software nutzt eine Z80-CTC im Interruptbetrieb, um den Soundchip AY-3-8910 alle 20 ms mit neuen Sounddaten zu versorgen.

In der ursprünglichen Implementierung wird die CTC über die I/O-Adresse `0x00` angesprochen. Die Interruptfrequenz wird dabei aus dem CPU-Takt abgeleitet.

## Anpassungen für AC1-2010 und picoAC1

Für den Einsatz der Soundkarte am AC1-2010 und am picoAC1 sind Anpassungen an der ursprünglichen Software erforderlich, da diese Systeme in der Regel mit einem variablen CPU-Takt von 4 MHz oder höher betrieben werden können.

Für die Interrupt-Erzeugung wird deshalb die CTC der Soundkarte mit der I/O-Adresse `0x3C` verwendet.

Da die Soundkarte über einen eigenen Quarzgenerator mit 3,57954 MHz verfügt, wird dessen Signal über eine feste Frequenzteilung zur Erzeugung der Interrupts genutzt. Dadurch ist die Interruptfrequenz unabhängig vom CPU-Takt.

Bei den PT3- und STC-Playern muss außerdem die Initialisierung des VDIP1-Moduls an den jeweils verwendeten CPU-Takt angepasst werden.

## Durchgeführte Änderungen

Folgende Anpassungen wurden vorgenommen:

- Kaskadierung der CTC-Kanäle K0 und K1 zur Nutzung des 3,57954-MHz-Quarzes für die Interrupt-Erzeugung.
- Anpassung des HL-Registerwertes bei der VDIP1-Initialisierung auf `0x0600`.
- Anpassung der CP/M-Programme: Verwendung der User-Interrupt-Tabelle im Adressbereich `0xFF90` bis `0xFF9F`.

## Voraussetzungen und Erstellung

Zum Erzeugen neuer Binärdateien aus den Assembler-Quelldateien wird der **ASide-Assembler** benötigt.

Für den Interrupt-Test der CTC ist im Verzeichnis `CTCTEST` ein entsprechendes Testprogramm abgelegt.
