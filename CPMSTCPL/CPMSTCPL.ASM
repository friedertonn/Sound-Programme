;------------------------------------------------
;CPMSTCPL
;STC-USB-PLAYER FÜR CP/M 
;angepasst für den AC1-2010 mit 4MHz CPU-Takt
;-------------------------------------------------
;WERO, 12/2017
;-------------------------------------------------

;Version 1.0.2 
;KW 03.02.2018
;Verwendung CP/M kompatible Rechner über Auswahlmenü
;z.B.A5120/K8924 unter CP/A, SCPX
;    K8915 unter SCP8915
;    NANOS unter EPOS
;    LLC2 unter CP/L 
;Bildschim-Ausgabe 80x24 und 64x32 möglich
;nur BDOS Aufrufe !!!
;Parameter (IO-Adressen, IV, ZK) als Patch, da sonst Timingprobleme 
; aufgetreten sind --- speziell beim K8915
;-------------------------------------------------

;Ergänzung mit INI-Datei 
;Heiko Poppe, 18. Februar 2018
;-------------------------------------------------

;Version 1.0.3
;KW 25.03.2018
;Einbindung von Heikos SOUND.INI
;USB-Routine aus PT3 Player eingefügt (keine include mehr)
;Song vorwärts und rückwärts einegfügt
;Loop Funktion eingefügt
;-------------------------------------------------

;Version 1.0.4
;27.05.2022
;Anpassung für AC1-2010 mit 4 MHz CPU-Takt:
;* HL-Registerwert bei der VDIP-Initialisierung
;  auf 600h gesetzt
;* CTC Kanäle K0+K1 kaskadiert und Nutzung des 
;  Quarzes 3,57954 MHz für den Interrupt
;* Definition Q358=1 bei Nutzung des Quarzes auf
;  der Sound-Leiterplatte
;* Anpassung für HRCPM12/HRDOS12
;  Nutzung der Interrupttabelle auf Adr. 0FF80H
;  (bisher nicht verwendeter Interrupt-Einsprung)
;------------------------------------------------

;Version 1.0.5
;10.11.2026
;Anpassung für AC1-2010 und picoAC1:
;* User-Interrupt-Tabelle von 0xFF90 bis 0xFF9F
;------------------------------------------------

AYBAS:   EQU     38H
CTCBAS:  EQU     AYBAS+4      ;CTC-BASISADRESSE
CTCCHN:  EQU     0            ;CTC-KANAL
CTCZK:   EQU     156          ;1 BYTE CTC ZK (für 2 MHz) 
CTCINT:  EQU     0FF90H       ;2 BYTE ADRESSE INTERRUPTTABELLE
USBPIO:  EQU     0FCH         ;1 BYTE ADRESSE PIO USB-PORT
;------------------------------------------------
;Q358:      EQU  0            ;nutzt AC1-Systemtakt 2 MHz
                              ;höherer CPU-Takt führt zum
                              ;schnelleren Abspielen
Q358:       EQU  1            ;benutzt Quarz 3,57954 MHz
                              ;CTC K0+K1 sind kaskadiert
                              ;CPU-Takt ist variabel
;------------------------------------------------
START:      EQU     100H        ;PROGRAMMANFANG
WORK:       EQU     START+10H   ;BEGINN ARBEITSZELLEN
;-------------------------------------------------
;PROGRAMMSTART
ORG         START
            JP      START0
;-------------------------------------------------
ORG         WORK                ;ARBEITSZELLEN
            DEFS    256 ;128         
;PLAYER-BEZÜGE
;WORK...WORK+71 ;RESERVIERT FÜR STC-PLAYER
SNGADR:     EQU     WORK        ;WORD, ANFANGSADRESSE SONG
WDH:        EQU     WORK+02     ;BYTE, ANZAHL WIEDERHOLUNGEN
MAXI:       EQU     WORK+0DH    ;BYTE, ANZAHL PATTERN IM SONG
POSI:       EQU     WORK+35H    ;BYTE, ABGESPIELTE PATTERNANZAHL
LAUT_A:     EQU     WORK+3FH    ;BYTE, REG. 8=LAUTSTÄRKE KANAL A
LAUT_B:     EQU     WORK+40H    ;BYTE, REG. 9=LAUTSTÄRKE KANAL B
LAUT_C:     EQU     WORK+41H    ;BYTE, REG.10=LAUTSTÄRKE KANAL
;-------------------------------------------------
PLAYER:     ;AY-PLAYER-ENGINE
INCLUDE     AYPLAC1.INC  
            ;NORMALVARIANTE MIT CTC AUF SOUNDKARTE
            ;BEZÜGE:
            ;PLAYER+0           ;SONG LADEN+ABSPIELEN
            ;PLAYER+6           ;SOUND AUS
;-------------------------------------------------

MODNR:      DEFB    0           ;BYTE, MODUS: 0=EINZEL, 
                                ;1=PLAYLISTE,2=REIHE,3=ZUFALL
ASCII:      DEFW    0           ;WORD,  BWS-ADRESSE SEL. EINTRAG
TICKS:      DEFW    0           ;SPIELDAUER IN INTERRUPTS
SNR:        DEFW    0           ;WORD, AKT. SONGNUMMER
CURPOS:     DEFW    0000h
SETUP:      DEFB    0

;USB-BEZÜGE
DIRANZ:     DEFW    0           ;ANZAHL BEI DIR
MAX:        DEFW    0           ;WORD, AKT. TITELANZAHL
TMAX:       DEFW    0           ;WORD, ANZAHL FÜR ZUFALL
SPZ:        DEFB    0           ;SPALTENZÄHLER DIR
MENGE:      DEFW    0           ;DWORD,4 BYTES LADEN /SICHERN
            DEFW    0
RAMADR:     DEFW    0           ;WORD, USB-LADEADRESSE
INBUFF:     DEFS    15          ;EINGABEPUFFER 13+2
NAMBUF:     DEFS    15          ;PUFFER DATEINAME  13+2 ZEICHEN
DIRFLG:     DEFB    0           ;BYTE, FLAG FÜR SERIENABSPIEL
KATPOS:     DEFW    0           ;WORD, AKT. POSI IM KATALOG
;------------------------------------------------
START0:     
;lokalen Stack einrichten
            LD      (SPSV),SP   ;Stackpointer merken
            LD      SP, STACK   ;lokaler Stack
;            
;-------------------------------------------------
;Hauptmenü            
start0c:    call    cuoff
            CALL    KOPF          ;TITEL
            call    setpio
            ;BEI PROGRAMMSTART WIRD USB INITALISIERT
            ;ERFORDERT ANGESTECKTEN STICK, SONST "ND"-FEHLER
            ld      hl,stcx       ;Endung STC übergeben
            CALL    USB_CD        ;WECHSEL IN SONGVERZEICHNIS
            JR      C,FEHL        ;STC NICHT GEFUNDEN
            LD      HL,0          ;RÜCKSETZEN
            LD      (TMAX),HL     ;MAX. SONGANZAHL
            JR      START2        ;OK, STC GEFUNDEN
 
FEHL:       LD      DE,T_NOSTC    ;\STC-VERZEICHNIS EXISTIERT NICHT"
            CALL    PRNST
            JP      RAUS

;-------------------------------------------------
RESTART:    CALL    CONSI         ;ANHALTEN ZUM LESEN DER FEHLERMELDUNG
;-------------------------------------------------
START1:     call    player+6      ;SONG STOPPEN
            CALL    KOPF          ;TITEL

START2:     ;HAUPTMENÜ----------------------------
            LD      DE,0700h
            ld      (curpos),de
            CALL    SETCUR
            LD      DE,BEFEHLE
            CALL    PRNST
            ;-------------------------------------
FNKT:       CALL    CONSI         ;ABFRAGE FUNKTION
            OR      20H           ;GROß=KLEIN           
            CP      "l"           ;SONG LADEN?
            JP      Z,EINZEL      ; 
            CP      "p"           ;Playliste
            JP      Z,BATCH       
            CP      "a"           ;ALLES SPIELEN
            JP      Z,SERIE
            CP      "u"           ;USB-INIT/TEST
            JP      Z,start0c
            CP      "i"
            JR      Z,INFOT       ;INFOTEXT
            CP      "e"           ;ENDE
            JR      NZ,FNKT
            ;PROGRAMM-ENDE------------------------
HOME:       CALL    PLAYER+6      ;SONG STOPPEN 
            CALL    CLS
HOME1:      LD      HL,ROOT
            CALL    USB_CD        ;WECHSEL ZURÜCK IN ROOT
            JR      NC,RAUS

RAUS2:      LD      DE,T_USBERR   ;USB FEHLER
            CALL    PRNST

RAUS:       call    cuon
            LD      SP,(SPSV)     ;alten Stackpointer zurückholen
            jp      0             ;ZURÜCK ZUM OS  
;-----------------------------------------------
;PROGRAMMINFO AUSGEBEN                
INFOT:      CALL    CLS
            CALL    KOPF
            LD      DE,T_INFO     
            CALL    PRNST  
            JR      RESTART
;------------------------------------------------            
DESK:       XOR     A
            LD      HL,SETUP      
            SET     0,(HL)        ;AUTO-LOOP =1 = aus !!!
            ;PLAYER-OBERFLÄCHE ZEICHNEN
DESKa:      CALL    OBERFL        
            ;DATEINAME (SONGTITEL) ANZEIGEN------
            LD      DE,090Dh      ;Zeile 9,Spalte 13
            ld      (curpos),de
            CALL    SETCUR
         ;CALL    INVON       ;EIN
            LD      DE,NAMBUF
            CALL    PRNAM    
         ;CALL    INVOFF      ;AUS
            ;SONG-ID----------------------------
            LD      DE,0A0Dh      ;Zeile 10, Spalte 13
            ld      (curpos),de
            CALL    SETCUR
            LD      HL,SONG+7     ;FESTE POSI IM SONG!
            LD      B,18          ;LÄNGE IMMER 18 ZEICHEN
DESK1:      LD      A,(HL)
            CALL    CONSO
            INC     HL
            DJNZ    DESK1
            ;TEMPO-----------------------------
            LD      DE,0B0Dh
            ld      (curpos),de
            CALL    SETCUR     
            LD      A,(SONG)      ;TEMPOWERT 01...0F
            CALL    DEZA
            ;MAX. MUSTERANZAHL-----------------
            LD      DE,0D16h
            ld      (curpos),de
            CALL    SETCUR
            LD      A,(MAXI)
            CALL    DEZA
            ;SONG "1 VON "---------------------
            LD      DE,060Dh
            ld      (curpos),de
            CALL    SETCUR
            LD      DE,(SNR)
            CALL    DEZDE
            ;MAX. SONGANZAHL-------------------
            LD      DE,0616h
            ld      (curpos),de
            CALL    SETCUR
            LD      DE,(DIRANZ)
            CALL    DEZDE
DESK2:      ;SCHLEIFE WÄHREND ABSPIEL----------
            ;LFD.MUSTERNUMMER------------------
            LD      DE,0D0Dh
            ld      (curpos),de
            CALL    SETCUR
            LD      A,(POSI)
            CALL    DEZA
            ;PEGELANZEIGE BEDIENEN-------------
            LD      DE,0F0Dh
            ld      (curpos),de
            CALL    SETCUR
            LD      A,(LAUT_A)
            CALL    PEGEL
            LD      DE,100Dh
            ld      (curpos),de
            CALL    SETCUR
            LD      A,(LAUT_B)
            CALL    PEGEL
            LD      DE,110Dh
            ld      (curpos),de
            CALL    SETCUR
            LD      A,(LAUT_C)
            CALL    PEGEL
            ;ABFRAGE TASTATUR------------------
            LD      DE,0E00h
            ld      (curpos),de
            CALL    SETCUR
            call    consts_2
            CP      "L"           ;LOOP
            JP      Z,LOOP_EA
            CP      "l"
            JP      Z,LOOP_EA
            CP      "m"           ;"M" Menü = Stopp?
            JR      Z,DESK3       
            CP      "M"
            JR      Z,DESK3
            cp      "+"           ;"+" nächster Song
            RET     Z
            cp      "-"           ;"-" vorheriger Song 
            RET     Z  
            ;FALSCHE EINGABE LÖSCHEN:
            LD      A," "
            CALL    CONSO
            ;SONG FERTIG?----------------------
            LD      A,(WDH)       ;SONG ZU ENDE?
            OR      A             ;NEIN  
            JP      Z,DESK4       ;SONG zu Ende
            JR      DESK2         ;NEIN Weiterspielen
            ;SONG STOPPEN
DESK3:      PUSH    AF
            CALL    PLAYER+6      ;JA, SONG STOPPEN 
            CALL    CLS
            POP     AF
            RET

DESK4:      LD      HL,SETUP
            BIT     0,(HL)        ;LOOP-BIT=0 GESETZT?
            JP      NZ,DESK3      ;NEIN Song zu Ende
            ;SONG Wiederholen
            LD      HL,SONG       ;SONGANFANG
            LD      (SNGADR),HL   ;ÜBERGEBEN
            LD      A,1
            LD      (WDH),A       ;1 X SPIELEN
            CALL    PLAYER        ;SONG STARTEN
            JP      DESK2
                               
;EINZELABSPIEL------------------------------------
EINZEL:     xor     a
            ld      (modnr),a  
            call    CLS
            LD      DE,T_WEITER   ;ET/*
            CALL    PRNST
            ;DATEINAME ALS ZEICHENKETTE EINGEBEN--
EINZEL1:    LD      DE, T_NAM     ;AUFFORDERUNG
            CALL    PRNST         ;AUSGEBEN
            LD      DE,INBUFF     ;PUFFERANFANG
            LD      A,8           ;max. Zeichenzahl
            LD      (DE),A        ;SETZEN
            CALl    RCONB         ;Read Console Buffer
            ;Keine richtige Abbruchmöglichkeit!
            ;^C bewirkt Warmstart, falls als 1. Zeichen
            ;^X löscht Buffer und beginnt neue Eingabe
            ;...
            ;INBUFF ist BEFÜLLT
            LD      A,(INBUFF+1)  ;lesen eingegebene Zeichenzahl
            OR      A             ;=0?
            JP      Z,H4          ;leere Zeichenkette (nur ENTER)
            ;
            ;EINGABE VORHANDEN, NUN TESTEN--------
            LD      B,A           ;Anzahl zu prüfende Zeichen
            LD      HL,INBUFF+2   ;1. Zeichen
            ld      a,(HL)        ;Holen
            cp      "."           ;Abbruchzeichen? 
            jp      z,START1      ;ja=> Menü
            CP      "."           ;Punkt extra prüfen, da als 1. 
            JR      Z,H3          ;unzulässig!
H1:         LD      A,(HL)        ;ZEICHEN AUS EINGABEZEILE           
            INC     HL            ;NÄCHSTES
            CP      "."           ;"."
            JR      Z,EINOK          ;ja, Rest ignorieren, Endung ergänzen    
            call    INR           ;Zeichen prüfen
            cp      0
            JR      z,H3          ;unzulässig
            DJNZ    H1            ;Eingabe weiter prüfen             
            ;kein Punkt gefunden, HL auf Posi nach Name
            LD      (HL),"."      ;“.“ anhängen 
            INC     HL        
EINOK:    ;DATEINAME OHNE ENDUNG, DIESEN KOPIEREN
            ld      a,(inbuff+1)  ;Anzahl Zeichen Dateiname ohne Endung
            LD      HL,INBUFF+2   ;BEGINN ZK
            LD      DE,NAMBUF     ;NACH HIER
            LD      B,0
            LD      C,A           ;ANZAHL ZEICHEN
            LDIR                  ;UMKOPIEREN IN LADEPUFFER
 ;ANHÄNGEN ENDUNG .STC + 0DH
            LD      A,"."
            LD      (DE),A
            INC     DE
            LD      HL,STCX
            LDI                   ;S
            LDI                   ;T
            LDI                   ;C
            LDI                   ;0D
            CALL    CLS
            LD      DE,130DH      ;MITTIG
            CALL    SETCUR
            LD      DE,T_LADE
            CALL    PRNST
         ;CALL    INVON           ;EIN
            LD      DE,NAMBUF
            CALL    PRNAM
         ;CALL    INVOFF          ;AUS
         ;call    short           ;PAUSE
            ;LADEN---------------------------
            LD      HL,SONG       ;ZIEL IM RAM
            LD      (RAMADR),HL   ;LADEADRESSE
            CALL    _LADEUSB
            JP      C,RESTART     ;NICHT GEFUNDEN,ZURÜCK ZUM MENÜ   
            ;SONG STARTEN-----------------------
            LD      A,1           ;1 = KEINE WIEDERHOLUNG
            LD      (WDH),A       ;ANZAHL!
            LD      HL,1
            LD      (SNR),HL
            LD      (max),HL
            CALL    PLAYER 
            CALL    DESK          ;HIERDRIN 1 LIED
            JP      START1        ;FERTIG      

;-------------------------------------------------
H3:        ;EINGABE WAR UNZULÄSSIG
            LD      DE,UNZUL
            CALL    PRNST
            JP      RESTART        ;Warten auf Taste, dann neustart

;-------------------------------------------------
H4:         ;LEERE EINGABE (NUR ENTER): DIR ANZEIGEN
            CALL    CLS
            XOR     A
            LD      (DIRFLG),A    ;NORMALE BS-ANZEIGE
            CALL    DIR           ;ANZEIGE USB-INHALTSVERZEICHNIS
            CALL    ISNULL        ;BESTAND?
            JP      NZ,EINZEL1    ;JA, Eingabe-Aufforderung
            LD      DE,T_NIX
            CALL    PRNST
            JP      RESTART
;-------------------------------------------------
;SONG STARTEN-----------------------
            LD      HL,1
            LD      (SNR),HL
            LD      (max),HL
            CALL    DESK          ;HIERDRIN 1 LIED
            JP      START1        ;FERTIG      
;-------------------------------------------------
;Prüft im Dateinamen zulässiges Zeichen in A
;Rückgabe A=0, wenn unzulässig
INR:        PUSH    HL
            PUSH    BC
            LD      HL,RANGE
            LD      B,RANGEE-RANGE ;Menge zulässiger Zeichen
INR1:       CP      (HL)
            JR      Z,INR2        ;ist enthalten!
            INC     HL            ;nächstes
            DJNZ    INR1          ;prüfen
            ;alles geprüft, nicht enthalten
            XOR     A             ;Rückgabewert bei Fehler
INR2:       POP     BC
            POP     HL
            RET

;------------------------------------------------
;PLAYLISTE ABSPIELEN------------------------------
BATCH:      LD      A,1
            LD      (MODNR),A     ;MODUS
            CALL    CLS
            CALL    KAT0          ;KATALOG LEEREN
            LD      HL,T_BNAM     ;NAME 
            LD      DE,NAMBUF     ;BATCHDATEI
            LD      BC,13
            LDIR
            LD      DE,T_STAPEL   ;Playliste...
            CALL    PRNST

            LD      HL,KAT        ;ZIELADRESSE
            LD      (RAMADR),HL
            CALL    _LADEUSB
            JP      C,RESTART     ;KEINE BAT VORHANDEN
            CALL    CLS
            ;DATEIEN IM BATCHFILE (KATALOG) ZÄHLEN
            CALL    SONG1         ;START MIT 1
            CALL    DIR0          ;ANZAHL=0
            LD      HL,KAT        ;ANFANG KATALOG
BAT1:       LD      A,(HL)
            OR      A             ;ENDE?
            JP      Z,SERIE1      ;FERTIG
            CP      0DH
            CALL    Z,DIRPLUS     ;1 DATEI MEHR
            INC     HL
            JR      BAT1

;SERIENABSPIEL------------------------------------
SERIE:      LD      A,2
            LD      (MODNR),A 
            CALL    CLS
            LD      DE,T_EINLES 
            CALL    PRNST
            CALL    KAT0          ;KATALOG LÖSCHEN
            LD      A,1
            LD      (DIRFLG),A    ;DIR ZEIGT NICHTS AN, 
                                  ;SONDERN SCHREIBT KATALOG
            CALL    SONG1         ;SONGNR AB 1
            CALL    DIR           ;EINLESEN
SERIE1:     CALL    ISNULL        ;BESTAND?
            JR      NZ,SERIE3     ;JA
            LD      DE,T_NIX      ;NEIN
SERIE2:     CALL    PRNST
            JP      RESTART
            
SERIE3:     CALL    SONG1         ;Beginn mit Songnr 1
            LD      HL,(DIRANZ)
            LD      (max),HL

        ;AUS KATALOG SONGNAMEN NACHEINANDER HOLEN
            LD      HL,KAT        ;ANFANGSADRESSE KATALOG
            LD      (KATPOS),HL   
          
            ;NAME HOLEN, KOPIEREN NACH NAMBUF=DATEINAME, 0D-TERMINIERT
SERIE4:     LD      HL,(KATPOS)
            LD      DE,NAMBUF
SERIE5:     LD      A,(HL)
            CP      0AH           ;ÜBERLESEN (TRITT BEI BATCH AUF)
            JR      NZ,SERIE6
            INC     HL            ;0A ÜBERLESEN
            JR      SERIE5
SERIE6:     OR      A
            JP      Z,START1      ;KEIN WEITERER NAME MEHR!
            CP      0DH           ;NAME FERTIG KOPIERT?
            JR      Z,SERIE7      ;NOCH NICHT
            LDI
            JR      SERIE5

SERIE7:     LDI                   ;0D NOCH ÜBERNEHMEN!
            ;HL=ANFANG NÄCHSTER NAME!
            LD      (KATPOS),HL   ;SETZEN
            ;DATEINAME IST IN NAMBUF
            CALL    CLS
            LD      DE,0D12h      ;MITTIG
            ld      (curpos),de
            CALL    SETCUR
            LD      DE,T_LADE     ;"LADEN"
            CALL    PRNST
         ;CALL    INVON       ;EIN
            LD      DE,NAMBUF
            CALL    PRNAM         ;NAME AUSGEBEN
         ;CALL    INVOFF      ;AUS
         ;call    short       ;pause
            LD      DE,0D12H      ;POSI
            CALL    SETCUR        ;VORBEREITEN FÜR EVTL. FEHLERMELDUNG
            CALL    CUOFF  

            ;LADEN-----------------------------          
            LD      HL,SONG       ;LADEADRESSE
            LD      (RAMADR),HL   ;DORTHIN!
            CALL    _LADEUSB      ;CARRY, WENN FEHLER
            JP      C,RESTART   

            ;SONGANFANG ÜBERGEBEN--------------
            LD      HL,SONG       ;SONGANFANG
            LD      (SNGADR),HL   ;ÜBERGEBEN
            LD      A,1
            LD      (WDH),A       ;1 X SPIELEN
            CALL    PLAYER        ;SONG STARTEN
            CALL    DESK          ;OBERFLÄCHE
            PUSH    AF
            CALL    PLAYER+6      ;SONG STOPPEN
            POP     AF
            ;HIER WEITER, WENN:
            ;SONG ZU ENDE, ODER
            CP      "m"
            JP      Z,START1      ;"M" Menü = Stopp 
            cp      "M"
            JP      Z,START1
            CP      "+"           ;"+" nächster Song
            JR      Z,SERIE10     
            CP      "-"           ;"-" vorheriger Song
            JR      Z,SERIE13
            ;PAUSE-----------------------------
            LD      B,3
SERIE8:     PUSH    BC
            LD      DE,0D12h
            ld      (curpos),de
            CALL    SETCUR
            LD      DE,T_PAUSE
            CALL    PRNST
            LD      A,B
            ADD     A,30H
            CALL    CONSO         ;PAUSENWERT AUSGEBEN 3...0
            LD      BC,0
SERIE9:     DEC     BC
            LD      A,B
            OR      C
            JR      NZ,SERIE9
            POP     BC
            DJNZ    SERIE8
            CALL    CLS
SERIE10:    LD      DE,(MAX)      ;SOVIEL SIND DA 
            LD      HL,(SNR)      ;LAUFENDE NR.
            OR      A
            SBC     HL,DE
            ADD     HL,DE
            JP      NC,START1     ;WAR SCHON LETZTER
            INC     HL            ;ERHÖHEN
SERIE11:    LD     (SNR),HL
            JP      SERIE4

SERIE13:;RÜCKWÄRTS--------------------------------
            LD      DE,1
            LD      HL,(SNR)
            OR      A
            SBC     HL,DE
            ADD     HL,DE
            JP      Z,START1      ;WAR SCHON 1, NICHT WEITER ZURÜCK!
            DEC     HL
            LD      (SNR),HL
            ;IM KATALOG EINEN EINTRAG ZURÜCK:
            LD      HL,(KATPOS)   ;STEHT AUF ANFANG NÄCHSTER NAME
            DEC     HL            ;AUF 0D (0A BEI PLAYLISTE)
            LD      A,0AH
            CP      (HL)
            JR      NZ,SERIE14
            DEC     HL            ;WAR PLAYLISTE
            ;HL= 0D DER AKT. DATEI
SERIE14:    DEC     HL
            LD      A,(HL)
            CP      0             ;KATALOG-ANFANG?
            JP      Z,START1      ;JA, 1. WIRD SCHON GESPIELT
            CP      0DH
            JR      NZ,SERIE14
SERIE15:    DEC     HL
            LD      A,(HL)
            CP      0             ;ZIEL=1. DATEI?
            JR      Z,SERIE16
            CP      0DH
            JR      NZ,SERIE15
SERIE16:    INC     HL            ;1. ZEICHEN NAME
            LD      (KATPOS),HL
            JP      SERIE4

;-----------------------------------------------
SONG1:      LD      HL,1          ;SONG-NR AUF 1 SETZEN
            LD      (SNR),HL
            RET

;-------------------------------------------------
LOOP_EA:    LD      DE,151EH
            LD      (CURPOS),DE
            CALL    SETCUR
            PUSH    AF
            LD      A,(SETUP)
            XOR     1             ;LOOP_BIT
            LD      (SETUP),A     ;INVERTIEREN
            ;ANZEIGE LOOP EIN/AUS
            OR      A             ;0=EIN ?
            LD      DE,T_EIN      ;ja "ein"
            JR      Z,PAU1 
            LD      DE,T_AUS      ;"aus"
            JR      PAU1          ;AUSGABE TEXT
PAU1:       CALL    PRNST
            POP     AF
            JP      DESK2
;PEGELANZEIGE-------------------------------------
;BALKENANZEIGE, LÄNGE in A
;DER REST BIS ZUR MAX. LÄNGE WIRD MIT LEERZEICHEN ÜBERSCHRIEBEN
     
PEGEL:      OR      A             ;0?
            LD      D,">"         ;SYMBOL BALKENZEICHEN NORMAL
            LD      C,16          ;MAX.
            JR      Z,P2          ;NUR 16X LEER!
            CP      16            ;HÜLLKURVE?
            JR      C,P0          ;<16        -> NORMAL
                                  ;WAR >=16   -> HÜLLKURVE AKTIV
            LD      A,16          ;MAX. ANZEIGEN
            LD      D,")"         ;SYMBOL HÜLLKURVE
P0:         LD      B,A           ;ANZAHL 
            LD      A,16          ;MAX.
            SUB     B             ;REST
            LD      C,A           ;ANZAHL LEERE MERKEN
P1:         LD      A,D           ;SYMBOL
            call    conso    
            DJNZ    P1
            ;ALTEN RESTBALKEN LÖSCHEN
P2:         LD      B,C
            XOR     A
            CP      B
            RET     Z
P3:         LD      A," ";
            call    conso
            DJNZ    P3
            RET
        
;-------------------------------------------------
;DEZIMALAUSGABE 000...999
;-------------------------------------------------
DEZDE:      ;WERT IN DE
            JR      DEZ1
DEZA:       ;Wert in A
            LD      L,A
            LD      H,0
            EX      DE,HL         ;DE=AUSGABEWERT
DEZ1:       LD      C,30H
            LD      HL,0063H      ;99
            AND     A
            SBC     HL,DE
            JP      C,DEZ2
            LD      A,C
            call    conso
            LD      HL,0009H      ;9
            AND     A
            SBC     HL,DE
            JP      C,DEZ2
            LD      A,C
            call    conso
DEZ2:       EX      DE,HL
DEZ3:       LD      DE,000AH
            CALL    DEZ4
            LD      A,L
            LD      H,B
            LD      L,C
            PUSH    AF
            LD      A,L
            OR      H
            CALL    NZ,DEZ3
            POP     AF
            ADD     A,30H         ;ZIFFER
            jp      conso

DEZ4:       LD      B,L
            LD      L,H
            LD      H,0
            CALL    DEZ5
            LD      H,L
            LD      L,B
            LD      B,C
DEZ5:       LD      C,0FFH
DEZ6:       AND     A
            SBC     HL,DE
            INC     C
            JP      NC,DEZ6
            ADD     HL,DE
            RET 
;-------------------------------------------------
PRNAM:      LD      A,(DE)
            CP      0DH           ;OHNE 0D-AUSGABE!
            RET     Z
            CALL    CONSO
            INC     DE
            JR      PRNAM  
             
;-------------------------------------------------
;PLAYEROBERFLÄCHE
OBERFL:     CALL    KOPF
            LD      DE,0600h      ;UNTER DEM KOPF:
            ld      (curpos),de
            CALL    SETCUR
            LD      DE,OBER
            CALL    PRNST
            RET

;-------------------------------------------------
;DATEIANZAHL (RÜCK)SETZEN, ERHÖHEN, PRÜFEN
DIR0:       PUSH    HL
            LD      HL,0
            JR      DIR2
DIR1:       PUSH    HL
            LD      HL,1
DIR2:       LD      (MENGE),HL
DIR3:       LD      (DIRANZ),HL
            POP     HL
            RET
DIRPLUS:    PUSH    HL
            LD      HL,(DIRANZ)
            INC     HL            ;ZÄHLEN
            JR      DIR3
ISNULL:     LD      HL,(DIRANZ)   ;ANZAHL SONGS
            LD      A,H
            OR      L
            RET

;-------------------------------------------------
KOPF:       CALL    CLS
            LD      DE,0101h
            ld      (curpos),de
            CALL    SETCUR
            LD      DE,KOPFT
            CALL    PRNST
            JP      CUOFF

;#################################################
;USB-ROUTINEN
;#################################################

SETPIO:;PROGRAMMIEREN USB-PIO
        LD      A,0CFH            ;PIO_B: BITBETRIEB
        OUT     (USBPIO+3),A
        LD      A,33H             ;I/O FESTLEGEN: AAEE AAEE
        OUT     (USBPIO+3),A
        LD      A,7               ;KEIN INT
        OUT     (USBPIO+3),A
        LD      A,84H             ;DATEN B = I000 0I00 = RESET
        OUT     (USBPIO+1),A
        LD      A,8FH             ;PIO_A: BIDIREKTIONAL
        OUT     (USBPIO+2),A
        LD      A,7         
        OUT     (USBPIO+2),A
        IN      A,(USBPIO)
        LD      A,0C4H
        OUT     (USBPIO+1),A
SETP_1: LD      HL,600H           ;0200H  ;WARTEZEIT
SETP_2: IN      A,(USBPIO+1)
        RRCA
        JR      C,SETP_3          ;FERTIG
        CALL    GETUSB
        JR      SETP_1
SETP_3: RRCA
        JR      C,SETP_1
SETP_4: DJNZ    SETP_4
        DEC     HL
        LD      A,H
        OR      L
        JR      NZ,SETP_2
        IN      A,(USBPIO+1)
        AND     03H
        CP      01H
        JR      NZ,SETP_1
        LD      A,0DH
        CALL    PUTUSB
SETP_5: CALL    CHECKB
        JR      NZ,SETP_5
        LD      A,45H             ;E SENDEN
        CALL    PUTUSB
        LD      A,0DH
        CALL    PUTUSB  
SETP_6: CALL    GETUSB  
        CP      45H               ;E EMPFANGEN?
        JR      NZ,SETP_6
        CALL    CHECKB
                
        JR      NZ,SETP_6
        LD      A,10H
        CALL    PUTUSB  
        CALL    SETP_7
        LD      A,91H
        CALL    PUTUSB  
        CALL    SETP_7
SETP_7: LD      A,0DH
        CALL    PUTUSB
        CALL    GETUSB  
        CP      3EH
SETP_8: JR      NZ,SETP_9
        CALL    CHECKB
        RET     Z                 ;INIT FERTIG

        ;HIER WENN FEHLER!
SETP_9: CALL    CONSO             ;ZEICHEN "ND" 
        CALL    CHECKB
        JR      NZ,SETP_9
USBERR: LD      DE,T_USBERR
        CALL    PRNST
        CALL    CONSI
        SCF                       ;FEHLERFLAG
        RET
;-----------------------------------------------
;INHALT USB ANZEIGEN/KATALOGISIEREN/ZÄHLEN(HOLEN
;KOMMT MIT(DIRFLG) = 0   -> ANZEIGE AUF SCHIRM
;                    1   -> KATALOGISIEREN
;                    2   -> NUR ZÄHLEN
;                    3   -> N-TEN DATEINAME HOLEN
;                           N IN (ASCII)
DIR:    CALL    DIR0              ;DATEIZÄHLER
        XOR     A
        LD      A,01H             ;DIR
        CALL    PUTUSB
        CALL    EXEC
        LD      HL,INBUFF
        LD      (HL),24h ;0FFH
DIR05:  CALL    CHECKB            ;0D=ENDE EINES NAMENS?
        JP      NZ,DIR10          ;NEIN, WEITER LESEN
        ;ENDE NAME!
        LD      (HL),24h ;0FFH 
        DEC     HL
        ;NAME VORHANDEN, ENDUNG TESTEN
        LD      DE,STCX           ;FILTER PT3
        INC     DE
        INC     DE
        LD      A,(DE)
        CP      (HL)
        JP      NZ,DIR09
        DEC     HL
        DEC     DE
        LD      A,(DE)
        CP      (HL)
        JP      NZ,DIR09
        DEC     HL
        DEC     DE
        LD      A,(DE)
        CP      (HL)
        JP      NZ,DIR09
        ;JA: NAME ERFÜLLT BEDINGUNG
        CALL    DIRPLUS           ;EINE MEHR
        LD      A,(MENGE)
        INC     A  
        LD      (MENGE),A         ;ANZAHL PRO SCHIRM
        ;GUCKEN, WELCHER MODUS-----------------
        LD      A,(DIRFLG)   
        OR      A                 ;ANZEIGEN?
        JR      Z,D_ANZ           ;JA
        CP      2                 ;ZÄHLEN?
        JP      Z,DIR09           ;JA
        CP      1                 ;KATALOGISIEREN?
        JP      Z,D_COP           ;JA.

        ;N-TEN NAMEN HOLEN: TEST (DIRANZ)=(ASCII)
        LD      HL,(DIRANZ)       ;AKT. ANZAHL
        LD      DE,(ASCII)        ;ZUFALLSZAHL
        OR      A
        SBC     HL,DE             ;ERREICHT?
        JP      Z,REST1           ;JA, REST ABHOLEN+RAUS
        JP      DIR09             ;WEITER SUCHEN

;NORMAL AUF SCHIRM AUSGEBEN, 
        ;FORMATIERUNG BEI BEDARF!!!!!!!!!!!!!!!!!
        ;HIER NUR 1 NAME /ZEILE
D_ANZ:  LD       DE,INBUFF        ;DATEINAME
        CALL     PRNST            ;AUSGEBEN
        CALL     NEWL             ;NEUE ZEILE NACH JEDEM
        ;ANHALTEN, WENN SCHIRM VOLL
        LD      A,(MENGE)
        cp      20                ;20 Zeilen
        JR      C,DIR09 
        LD      DE,T_WEITER       ;WEITER/ABBr.
        CALL    PRNST
        CALL    CONSI
        CP      "."               ;WAR STOPP
        JR      Z,REST            ;NOCH REST ABHOLEN 
        CALL    CLS
        XOR     A
        LD      (SPZ),A           ;VON VORN ANFANGEN
        LD      (MENGE),A
        JR      DIR09

        ;IN KATALOG KOPIEREN
D_COP:  LD      DE,(KATPOS)       ;AKT. POSI IM KATALOG
        LD      HL,INBUFF
COP:    LD      A,(HL)      
        CP      "."
        JR      Z,COP1            ;NOCH PT3+0D ANHÄNGEN
        LDI
        JR      COP
COP1:   LD      (DE),A            ;. ABLEGEN
        INC     DE
        LD      HL,STCX
        LDI
        LDI
        LDI
        LD      A,0DH
        LD      (DE),A
        INC     DE
        LD      (KATPOS),DE       ;NEUE POS.
        ;BEGRENZUNG KATALOGGRÖßE!
        ;DE= AKT. KATALOGADRESSE
        LD      HL,MAXKAT-13      ;8000
        OR      A
        SBC     HL,DE
        JR      NC,DIR09          ;NOCH IM BEREICH
        ;ZUVIELE!
        LD      DE,T_ZUVIEL
        CALL    PRNST
        CALL    CUOFF
        ;DIR-REST ABHOLEN
        JR      REST1
DIR09:  LD      HL,INBUFF         ;PUFFER NEU BEGINNEN
        JR      DIR11
DIR10:  ;DATEINAME BAUEN
        LD      (HL),A
        INC     HL
DIR11:  CP      3EH               ;PROMPT = USB FERTIG?
        JP      NZ,DIR05          ;NEIN
DIR12:  CALL    CHECKB            ;JA, FOLGT 0D?
        JP      NZ,USBERR         ;NEIN, USBERR
        RET                       ;FERTIG!    

REST:   LD      DE,T_MOMENT       ;REST ABHOLEN,
        CALL    PRNST             ;INFO
        CALL    CUOFF
REST1:  CALL    CHECKB
        CP      3EH
        JR      NZ,REST1
        JR      DIR12
;-------------------------------------------------
USBERR3:CALL    EXWAIT1           ;WARTEN BIS USB FERTIG
USBERR4:LD      DE,T_NOTFND
        CALL    PRNST
        SCF                       ;FEHLERFLAG
        RET
;------------------------------------------------------
;DATEINAME AN USB SENDEN:
;KOMMT MIT KOMMANDOBYTE IN A (Z.B. 0BH=> ÖFFNEN)
;IN IX STEHT ADRESSE DATEINAME
SENDNAM:PUSH    IX              ;MERKEN
        CALL    PUTUSB          ;DATEN AN USB (KOMMANDO)
        ;ERST LEERZEICHEN VOR DER ÜBERMITTLUNG DES DATEINAMENS:
        LD      A,20H           ;
        CALL    PUTUSB          ;DATEN AN USB
        ;DANN DATEINAME SELBST:
        LD      B,0CH           ;MAX. 12X (8.3 !!!)
SN2:    LD      A,(IX+00H)      ;ZEICHEN AUS DATEINAME
        INC     IX
        CP      0DH             ;NAMENS-ABSCHLUSS ERREICHT?
        JR      Z,SN3           ;JA  => FERTIG!
        CP      21H             ;NEIN=> ZEICHEN GÜLTIG? (>21H)
        CALL    NC,PUTUSB       ;JA  => DATEN AN USB
        DJNZ    SN2             ;NÄCHSTES ZEICHEN
SN3:    POP     IX
        RET
;------------------------------------------------------
;EINLESEN  N BYTES (MENGE IN BC) UND ABLEGEN AB HL 
ABHOLEN:
        PUSH    IX              ;DATEINAME!
ABHOL0: LD      A,C
        OR      B               ;BC=0 ?
        JR      Z,ABHOL3        ;FERTIG!
        XOR     A
        CALL    GETUSB          ;BYTE VON USB HOLEN 
ABHOL1: LD      (HL),A          ;ABLEGEN
        INC     HL              ;NÄCHSTER ABLAGEPLATZ
ABHOL2: DEC     BC              ;MENGE-1
        JR      ABHOL0
ABHOL3: POP     IX
        RET
;------------------------------------------------------
;ALS LETZTES ZEICHEN SENDET DAS VDIP NACH EINER AUSGABE IMMER 0DH
CHECKB: CALL    GETUSB          ;JA   => BYTE VON USB HOLEN
        CP      0DH             ;VORGANG BEENDET?
        RET   
;------------------------------------------------------
EXWAIT: CALL    EXEC            ;KOMMANDOABSCHLUSS
EXWAIT1:CALL    GETUSB          ;BYTE VON USB HOLEN
        CP      3EH             ;">" = FERTIGMELDUNG?
        JR      NZ,EXWAIT2      ;NEIN
        CALL    CHECKB          ;USB FERTIG?
        RET     Z               ;JA
        JP      USBERR          ;USB-FEHLER
EXWAIT2:CALL    CHECKB          ;WEITER AUF FERTIG PRÜFEN
        JR      NZ,EXWAIT2      ;NEIN, WARTEN!
        RET 
;------------------------------------------------------
EXEC:   LD      A,0DH           ;KOMMANDOABSCHLUSS
PUTUSB: ;USB (UP PUT DATEN ZUM VDIP SENDEN)
        OUT     (USBPIO),A      ;DATENBYTE ANLEGEN
        PUSH    AF
PUT1:   IN      A,(USBPIO+1)    ;VDIP BEREIT?
        RRCA
        RRCA
        JR      C,PUT1          ;NOCH NICHT
        LD      A,0CCH          ;SCHREIBIMPULS
        OUT     (USBPIO+1),A
        LD      A,0C4H
        OUT     (USBPIO+1),A
        POP     AF
        RET
;--------------------------------------------------
GETUSB: ;USB (UP GET DATEN VOM VDIP HOLEN)
        PUSH    BC
        LD      BC,0FFFFH
GET1:   ;CALL    CSTS           ;TASTATURSTATUS
        ;CP      3              ;<STOP> ?
        ;JP      Z,RESET       ;ABBRUCH/RESTART
        IN      A,(USBPIO+1)
        RRCA
        JR      NC,GET2
        DEC     BC
        LD      A,B
        OR      C
        JP      Z,SETP_8
        JR      GET1
GET2:   LD      A,0C0H
        OUT     (USBPIO+1),A
        IN      A,(USBPIO)
        LD      C,A
        LD      A,0C4H
        OUT     (USBPIO+1),A
        LD      A,C
        POP     BC
        RET      
;-------------------------------------------------
USB_CD: ;KOMMT MIT HL=ZEIGER AUF STRINGANFANG (ENDE=0DH)
        PUSH    HL
        POP     IX
        LD      A,02H           ;CHDIR
        CALL    SENDNAM         ;DATEINAMEN AN USB
        CALL    EXEC            ;AUSFÜHREN
        ;ANTWORT ABHOLEN + FÜR TEST AUSWERTEN
        LD      DE,INBUFF       ;ALS ZIEL FÜR TEST
UI_048: CALL    CHECKB          ;EVTL. FEHLERMELDUNG AUSWERTEN
        LD      (DE),A
        INC     DE        
        JR      NZ,UI_048
        LD      (DE),A          ;0D ALS ABSCHLUSS
        ;TEST DER FEHLERMELDUNG 
        ;"CF"  = FILENAME OR DIRECTORY NAME NOT FOUND.
        XOR     A
        LD      HL,INBUFF
        LD      A,"C"
        CP      (HL)
        RET     NZ
        INC     HL
        LD      A,"F"
        CP      (HL)
        RET     NZ
        SCF                     ;FEHLERFLAG =1
        RET
;-------------------------------------------------
_LADEUSB:   ;DATEI PER USB LADEN
;IN  NAMBUF STEHT ADRESSE DES DATEINAMENS
;IN (RAMADR) STEHT SPEICHERADRESSE, AUF DIE EINZULESEN IST
        LD      IX,NAMBUF      ;ADRESSE DATEINAME
        ;DATEIGRÖßE HOLEN (DIR MIT DATEINAME):
        LD      A,01H               ;DIR MIT FIELNAME
        CALL    SENDNAM             ;DATEINAMEN AN USB
        CALL    EXEC                ;KOMMANDOABSCHLUSS
        CALL    CHECKB              ;USB FERTIG? (0D)
        JP      NZ,USBERR3          ;NEIN=> FEHLERABBRUCH      
LESEN1: CALL    CHECKB              ;USB FERTIG? (0D)
        JP      Z,USBERR4           ;DATEI NICHT GEFUNDEN!
        ;ZEICHEN WURDE EMPFANGEN------------------------------ 
        CP      20H                 ;LEERZEICHEN NACH DEM NAMEN 
        JR      NZ,LESEN1           ;SUCHEN
        ;DATEI GEFUNDEN!
        LD      B,04H               ;NÄCHSTE 4 BYTES =DATEILÄNGE
        LD      HL,MENGE            ;HIERHIN ABLEGEN
LESEN2: CALL    GETUSB              ;BYTE VON USB HOLEN
        LD      (HL),A              ;ABLEGEN
        INC     HL                  ;NÄCHSTES
        DJNZ    LESEN2
        ;DATEILÄNGE IST EINGELESEN UND STEHT AB (MENGE)-------
LESEN3: CALL    CHECKB              ;USB FERTIG?
        JR      NZ,LESEN3           ;NEIN
        CALL    GETUSB              ;BYTE VON USB HOLEN
        CP      3EH                 ;ENDE ERREICHT?
        JR      NZ,LESEN4           ;NEIN => FEHLERABBRUCH
        CALL    CHECKB              ;USB FERTIG?
LESEN4: JP      NZ,USBERR           ;FEHLERABBRUCH
        ;JETZT DATEI ÖFFNEN-----------------------------------
        LD      A,0EH               ;USB OPEN FOR READ
        CALL    SENDNAM             ;DATEINAMEN AN USB
        CALL    EXWAIT              ;KOMMANDOABSCHLUSS + WARTEN AUF FERTIG
        ;ZU LESENDE ANZAHL BYTES ÜBERMITTELN-----------------      
        LD      A,0BH               ;USB READ 
        CALL    PUTUSB              ;DATEN AN USB
        LD      A,20H               ;20H=> N BYTES SOLLEN GEHOLT WERDEN
        CALL    PUTUSB              ;DATEN AN USB
        ;MENGE N ALS DWORD ÜBERMITTELN:
        XOR     A                   ;2 X 0 (OBERE 16 BIT)
        CALL    PUTUSB              ;DATEN AN USB
        CALL    PUTUSB              ;DATEN AN USB
        LD      BC,(MENGE)          ;DATEILÄNGE HOLEN 
        ;ES WIRD IMMER SOVIEL GELESEN, WIE DIE DATEI LANG IST
        LD      A,B                 ;HWT MENGE
        CALL    PUTUSB              ;DATEN AN USB
        LD      A,C                 ;NWT MENGE
        CALL    PUTUSB              ;DATEN AN USB
        CALL    EXEC                ;KOMMANDOABSCHLUSS
        ;EINLESEN DES DATEIINHALTES---------------
        LD      HL,(RAMADR)         ;DORTHIN
        CALL    ABHOLEN             ;N BYTES VON USB HOLEN+ABLEGEN
CL1:    CALL    EXWAIT1             ;WARTEN BIS USB FERTIG
        ;DATEI SCHLIEßEN--------------------------
CLOSE:  LD      A,0AH               ;USB CLOSE 
        CALL    SENDNAM             ;DATEINAMEN AN USB
        JP      EXWAIT              ;KOMMANDOABSCHLUSS + WARTEN AUF FERTIG

;-------------------------------------------------
KAT0:   LD      HL,KAT              ;ANFANGSADRESSE KATALOG
        LD      (KATPOS),HL         ;MAX. 8 K BEI 511 SONGS
        DEC     HL                  ;VORBYTE AUCH!
        LD      (HL),0              ;LÖSCHEN
        LD      DE,KAT              ;
        LD      BC,1FFFH            ;Anzahl
        LDIR 
        RET

;-------------------------------------------------
SHORT:  ;Anzeigepause
        PUSH    BC
        LD      BC,08000h
SHORT1: DEC     BC
        LD      A,B
        OR      C
        JR      NZ,SHORT1
        POP     BC
        RET
      
;-------------------------------------------------
;BDOS-FUNKTIONEN
;-------------------------------------------------
;CONSOLE AUSGABE ZEICHEN
NEWL:       ;Neue Zeile
            LD      a,0Dh
            call    conso
            ld      a,0Ah
            jr      conso
            ;Clear Screen
CLS:        ld      a,0Ch     
            jr      conso
            ;Invers ON
INVON:      ld      a,085h
            jr      conso
            ;Invers OFF
INVOFF:     ld      a,084h
            jr      conso
            ;Cursor ON
CUON:       ld      a,082h
            jr      conso
            ;Cursor OFF
CUOFF:      ld      a,083h
;
CONSO:      PUSH    HL
            PUSH    DE
            PUSH    BC
            LD      E,A
            LD      C,2           ;AUSGABE
            JR      xbdos
;--------------------------------------------------
CONSI:      PUSH    HL
            PUSH    DE
            PUSH    BC
            LD      C,1           ;EINGABE
            JR      xbdos
;-------------------------------------------------
CONSTS: ;TASTATURSTATUS, WARTET NICHT
        ;RÜCKGABE A=0 WENN KEINE TASTE, SONST CODE
            PUSH    HL
            PUSH    DE
            PUSH    BC
            LD      C,6
            LD      E,0FFH        ;CONSOLENEINGABE
            JR      xbdos
;-------------------------------------------------
;UP ZEICHENKETTE AUSGEBEN,ANFANGSADRESSE IN DE
;ENDE 24H
PRNST:      PUSH    HL
            PUSH    DE
            PUSH    BC
            LD      C,09     
xbdos:      CALL    5
            POP     BC
            POP     DE
            POP     HL
            RET 
;-------------------------------------------------
;CONSOLE EINGABE ZEICHENKETTE
RCONB:      ld      c,10          ;Read Console Buffer
            jp      5             ;BIS ENTER ODER 8 ZEICHEN  
;-------------------------------------------------
;CONSOLE STATUS+EINGABE
;BDOS Funktion 6 macht bei SCPX Probleme 
;(doppelte Tastatureingabe nötig)
CONSTS_2:   push    hl
            push    de
            push    bc
            ld      c,11          ;consolen status
            call    5
            cp      0             ;Taste gedrückt?
            jp      z,consts_2a   ; nein -> zurück
            ld      c,1           ;sonst Zeichen holen
            call    5
consts_2a:  pop     bc
            pop     de
            pop     hl
            ret
;--------------------------------------------
;CURSOR POSITIONIEREN: "ESC,ZEILE+80H,SPALTE+80H" 
SETCUR:     PUSH    BC
            PUSH    DE
            PUSH    HL
            LD      A,(CURPOS+1) ;ZIEL-ZEILE
            OR      80H
            LD      (zeile),A
            LD      A,(CURPOS)   ;ZIEL-SPALTE
            OR      80H
            LD      (spalte),A
            LD      DE,zs_txt
            CALL    PRNST        ;ESC-SEQUENZ AUSGEBEN
            POP     HL
            POP     DE
            POP     BC
            RET

;ARBEITSZELLEN DAZU:
zs_txt:     DEFB    1BH          ;ESC
zeile:      DEFB    80H          ;Zeile+80h
spalte:     DEFB    80H          ;Spalte+80h
            DEFB    24H          ;Ende ZK
;-------------------------------------------------
T_INFO:     DEFM  "     UNTER VERWENDUNG FOLGENDER GRUNDROUTINEN:",0Dh,0Ah
            DEFB  0Ah
            DEFM  "     *ABSPIELROUTINE FUER ZX81 MIT AY-3-8910",0Dh,0Ah
            DEFM  "     PLAYEROBERFLAECHE, USB UNTERSTUETZUNG UND",0Dh,0Ah
            DEFM  "     ANPASSUNG AN CP/M: WeRo / KW / HP, 2018",0Dh,0Ah
            DEFM  "     Anpassung an AC1-2010 mit 4 MHz CPU-Takt",024h
;-------------------------------------------------
KOPFT:      DEFB  0DH,0AH
            DEFM  "     ","USB-STC-PLAYER - CP/M-VERSION (v.1.0.5)",0DH,0AH
            DEFM  "     ","        (C)WeRo/KW/HP-2018",0DH,0AH
            DEFM  "     ","---------------------------------------",0DH,0AH
            DEFM  "     ",
            DEFB  0DH,0AH,024h
;-------------------------------------------------
BEFEHLE:    DEFM  "       (L)ADEN EINZELSONG",0DH,0AH,0AH 
            DEFM  "       (P)LAYLISTE  SPIELEN",0DH,0AH,0AH
            DEFM  "       (A)LLE SONGS SPIELEN",0DH,0AH,0AH 
            DEFM  "       (U)SB STICKWECHSEL/INIT",0DH,0AH,0AH
            DEFM  "       (I)NFO",0DH,0AH,0AH           
            DEFM  "       (E)NDE",0DH,0AH,0AH  
            DEFM  "        -> FUNKTION:",024h
;-------------------------------------------------
OBER:       DEFM  "     ","SONG  :     VON     ",0DH,0AH 
            DEFM  0DH,0AH
            DEFM  "     ",0AH,"TITEL :                    "
            DEFM  0AH,0DH
            DEFM  "     ","ID    :                    ",0DH,0AH
            DEFM  "     ","TEMPO :                    ",0DH,0AH
            DEFM  "     "
            DEFM  0DH,0AH
            DEFM  "     ","MUSTER:     VON            ",0DH,0AH
            DEFM  "     "
            DEFB  0DH,0AH
            DEFM  "     ","KAN. A:                    ",0DH,0AH 
            DEFM  "     ","KAN. B:                    ",0DH,0AH 
            DEFM  "     ","KAN. C:                    ",0DH,0AH
            DEFM  "     "
            DEFB  0DH,0AH      
            DEFM  "     ","<+>=NAECHSTER  <->=VORHERIGER",0DH,0AH,0AH
            DEFM  "     ","<M>=MENUE      <L>=LOOP: aus",24h
;-------------------------------------------------
STCX:       DEFM    "STC",0DH,024h   ;UNTERVERZEICHNISNAME
ROOT:       DEFM    "/",0DH,024h     ;WURZELVERZEICHNIS
;-------------------------------------------------
T_EIN:      DEFM   "ein",024h
T_AUS:      DEFM   "aus",024h 
T_MOMENT:   DEFM   " MOMENT...",024h
T_USBERR:   DEFM   "USB-FEHLER!",024h
T_NOTFND:   DEFM   " NICHT GEFUNDEN!",024h
T_NOSTC:    DEFM   "      KEIN STC-VERZEICHNIS!",0DH,0AH,024h
T_NIX:      DEFM   0DH,0AH,"KEINE SONGS IN /STC!",024h
T_ZUVIEL:   DEFM   "ZU VIELE SONGS, NUR EINZELMODUS!",024h
T_WEITER:   DEFM   0DH,0AH,"<ET>=DIR, <.=ABBRUCH>",024h
T_NAM:      DEFM   0DH,0AH,"DATEINAME (OHNE .STC) ? ",024h
T_LADE:     DEFM   "LADEN: ",024h
T_EINLES:   DEFM   "LESE SONGS EIN...",024h
T_PAUSE:    DEFM   "PAUSE ",024h
T_STAPEL:   DEFM   "PLAYLISTE...",024h
T_WIEDER:   DEFM   0DH,0AH,"WIEDERHOLUNG (0)...8:",024h
T_BNAM:     DEFM   "!PLAYLST.TXT",0DH,024h
;
UNZUL:      DEFM    0DH,0AH,"EINGABE UNZULAESSIG",24h
;
RANGE:      DEFM    "1234567890"
            DEFM    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            DEFM    "abcdefghijklmnopqrstuvwxyz"
            DEFM    "$%-@!()#&",27H,5Eh,5Fh,60H,7BH,7Dh,7EH 
RANGEE:
;*************************************************
;LOKALER STACK 40h
SPSV:       DEFM   0000h          ;Merker für Stackpointer
            DEFS   40h            ;lokaler Stack  
STACK:
;*************************************************
;KATALOG 2000h
KAT:        EQU     STACK+2       ;Stack nicht überschreiben
MAXKAT:     EQU     KAT+2000h
           
;*************************************************
;SONG-BEGINN 
SONG:       EQU     MAXKAT+2      ;HIER BEGINNT GELADENER SONG
                                  ;2 byte Sicherheitsabstand zum KATALOG
;*************************************************
;

