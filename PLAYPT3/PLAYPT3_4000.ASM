;PLAYER-ENGINE:
;VORTEX TRACKER II V1.0 PT3 PLAYER FOR ZX SPECTRUM
;(C)2004,2007 S.V.BULBA <VOROBEY@MAIL.KHSTU.RU>
;HTTP://BULBA.UNTERGRUND.NET (HTTP://BULBA.AT.KZ)
;-------------------------------------------------
;Anpassung für AC1 mit 4 MHz CPU-Takt (05/2022):
;* HL-Registerwert bei der VDIP-Initialisierung
;  auf 600h gesetzt
;* CTC Kanäle K0+K1 kaskadiert und Nutzung des 
;  Quarzes 3,57954 MHz für den Interrupt
;* Definition Q358=1 bei Nutzung des Quarzes auf
;  der Sound-Leiterplatte
;-------------------------------------------------
;ANPASSUNG FÜR AC1: WERO 03/2018
;* USB-TREIBER FÜR LADEN DER SONGS
;* Farbfähig mit Farbkarte
;* Farbwerte: Bit 7 6 5 4  3 2 1 0
;                 I B G R  I B G R
;                 HINTEN-  --VORN-
;* PLAYER (NACH BULBA) ALS INCLUDE
;* SPIELZEITBESTIMMUNG (NACH BULBA)
;* EINFACHE SPEKTRUMANZEIGE WIE IM SOUNDTRACKER 1.X
;-------------------------------------------------
;ASSEMBLER: ASIDE 
;#################################################
EMU:    EQU     0               ;1=EMU-TEST TONLOS
;#################################################

PROGR:  EQU     4000H           ;LADEADRESSE/PROGRAMMANFANG
MS30:   EQU     07EBH           ;UP PAUSE
INLINE: EQU     07F4H           ;UP STRING-EINGABE
GETCO:  EQU     07FDH           ;RÜCKKEHR ZUM MONITOR
BWS:    EQU     17FFh           ;Bildschirmspeicher links oben
CURS:   EQU     1800h           ;ADRESSE AKT. KURSORPOSITION
INANF:  EQU     181AH           ;ADRESSE STRINGANFANG EINGABE
COLTST: EQU     181fH           ;Farb-Reset-Byte 00=keine Farbkarte
USBPIO: EQU      0FCH           ;BASISADRESSE USB-PIO     DC?
AYBAS:  EQU       38H           ;AY-BASISADRESSE
CTCZK:  EQU       9Ch           ;Zeitkonstante für 2 MHz
CTCINT: EQU     PROGR+10h       ;Interrupttabelle CTC

KAT:    EQU     2000H           ;KATALOG-ANFANG
MAXKAT: EQU     4000H           ;-"-     Ende+1

IF EMU=1
   CTCBAS:  EQU 0h              ;INT. CTC-BASISADRESSE AC1
   CTCKAN:  EQU 0               ;FREI: KAN. 0
ELSE
   CTCBAS:  EQU 3CH             ;CTC-BASISADRESSE
   CTCKAN:  EQU 0               ;K0
ENDIF
;-------------------------------------------------
;Q358:         EQU  0  ;nutzt AC1-Systemtakt 2 MHz
                       ;höherer CPU-Takt führt zum
                       ;schnelleren Abspielen
Q358:          EQU  1  ;benutzt Quarz 3,57954 MHz
                       ;CTC K0+K1 sind kaskadiert
                       ;CPU-Takt ist variabel
;-------------------------------------------------
;PROGRAMMKOPF (4000)
ORG     PROGR                   ;Programmanfang
        DEFB    0,9,"3",0Dh,0   ;Startrahmen, Kennbuchstabe '3'
        JP      START0
        ;max. 8 Config-Bytes als Patch-Bereich:
ZK:     DEFB    0F0h            ;IO-Adr. AC1 Farbkarte
                                ;
F0:     DEFB    0CFh            ;Grundfarbe Player, 
                                ;00=System
                                ;xx=benutzerdefiniert
F1:     DEFB    0FFh            ;Farbe Titel-/Autor-Info
                                ;00=Syste
                                ;FF=System invers
                                ;xx=benutzerdefiniert
ZG1:    DEFB    0A0h            ;0AFh=waagerechter Strich ACC
ZG2:    DEFB    0B4h            ;85hh=Säule ACC
;noch frei
        DEFB    0
        DEFB    0
        DEFB    0        
;------------------------------------------------
ORG     CTCINT
        DEFS    8,0             ;INT-Adressen CTC
;------------------------------------------------
INCLUDE PT3TIME.INC             ;SPIELDAUERBERECHNUNG
;NAMENSBEZÜGE!
;(MODADR)                       ;ÜBERGABE SONGADRESSE
;CALL CALC                      ;BERECHNUNG, RÜCKGABE: H=MINUTEN, L=SEKUNDEN
;(PT3TIME)                      ;RÜCKGABE SPIELDAUER ALS ANZAHL INTERRUPTS
;--------------------------------------------------
Include PT3PLAY.INC             ;der Player
;Bezüge:
;CALL PLAY          ;init CTC, init song, play
;CALL STOPP         ;Abspiel Stoppen, INT. aus
;CALL MUTE          ;stummschalten
;(MODADR)           ;WORD, SONGADRESSE
;(SETUP)            ;BYTE, setup und status flags
;(CrPsPtr)          ;WORD, Adresse mit Akt. Pattern
;(POSI)             ;BYTE, LFD. NR. in Positionsliste
TON_A:  EQU     AYREGS          ;TONHÖHE
TON_B:  EQU     AYREGS+2
TON_C:  EQU     AYREGS+4
;RAUSCH: EQU     AYREGS+6
;MIXER:  EQU     AYREGS+7 
VOL_A:  EQU     AYREGS+8        ;LAUTSTÄRKE
VOL_B:  EQU     AYREGS+9
VOL_C:  EQU     AYREGS+10
HK_D:   EQU     AYREGS+11
HK_F:   EQU     AYREGS+13
;PORTA:  EQU     AYREGS+14
;PORTB:  EQU     AYREGS+15
;-------------------------------------------------
MODNR:  DEFB    0               ;BYTE, MODUS: 0=EINZEL, 
                                ;1=PLAYLISTE,2=REIHE,3=ZUFALL
ASCII:  DEFW    0               ;WORD,  BWS-ADRESSE SEL. EINTRAG
TICKS:  DEFW    0               ;SPIELDAUER IN INTERRUPTS
SNR:    DEFW    0               ;WORD, AKT. SONGNUMMER
        DEFB    0               ;SPEKBU -1 WEGEN +/- HALBER BALKEN
SPEKBU: DEFS    32,0            ;Puffer Spektrum
        DEFB    0               ;+1 WEGEN +/- HALBER BALKEN
SEED:   DEFW    0               ;WORD, STARTWERT ZUFALLSGENERATOR
;USB-BEZÜGE
DIRANZ: DEFW    0               ;ANZAHL BEI DIR
MAX:    DEFW    0               ;WORD, AKT. TITELANZAHL
TMAX:   DEFW    0               ;WORD, ANZAHL FÜR ZUFALL
MENGE:  DEFW    0               ;DWORD
        DEFW    0               ;4 Bytes Menge beim Laden
RAMADR: DEFW    0               ;WORD, USB-LADEADRESSE
INBUFF: DEFS    15              ;EINGABEPUFFER 13+2
NAMBUF: DEFS    15              ;PUFFER DATEINAME  13+2 ZEICHEN
DIRFLG: DEFB    0               ;BYTE, FLAG FÜR SERIENABSPIEL
KATPOS: DEFW    0               ;WORD, AKT. POSI IM KATALOG
FARBE:  DEFB    0               ;Flag: 00= nein,  xx=ja
BASECOL:DEFB    0               ;Basis-Farbe
COLOR:  DEFB    0               ;akt.Farbbyte
;-----------------------------------------------
START0: LD      A,HI PROGR      ;20h
        LD      I,A             ;IV-Säule verbiegen
        LD      SP,KAT-1        ;Stack: < 1fff
        call    config          ;Testen Farbkarte/Zeichensatz

start01:CALL    KOPF            ;TITEL
        ld      hl,bws-9*64+15
        ld      (curs),HL

        LD      DE,T_INIT
        CALL    TXT1
        CALL    SETPIO          ;USB-INIT+TEST
        JP      C,RAUS          ;FEHLER !

        LD      HL,PT3X
        CALL    USB_CD          ;WECHSEL IN SONGVERZEICHNIS
        JP      C,FEHL          ;NICHT DA
        LD      HL,0            ;RÜCKSETZEN
        LD      (TMAX),HL       ;MAX. SONGANZAHL
        JR      START2          ;OK, PT3 GEFUNDEN
FEHL:   LD      DE,T_NOPT3      ;PT3-VERZEICHNIS EXISTIERT NICHT
        CALL    TXT1
        JP      RAUS
;---------------------------------------------
Config: xor     a
        LD      (FARBE),A       ;Flag=0 =>keine Farbe benutzen
        ld      a,0Fh           ;SW
        ld      (BASECOL),A     ;als Systemfarbe

        LD      A,(COLTST)      ;Farbe RESET-BYTE
        cp      0AFh            ;monitor 10/88 und 8 = Ausnahmen!
        RET     z               ;keine Farbe!
        or      A               ;andere 0 oder xx
        RET     z               ;keine Farbe!
        ;Farbkarte vorhanden:
        LD      (Farbe),A       ;Flag<>0 => Farbe benutzen
        ld      (BASECOL),A     ;als Systemfarbe  
        ;Welche Karte?
        LD      A,(ZK)          ;Port F0 oder F2
        cp      0F0h            ;ori?
        jr      z,conf1         ;ja
        ;Heiko:
        ;A=F2
        LD      (FP1),A         ;Patchen Port
        LD      (FP2),A         ;Patchen Port
        LD      (FP3),A         ;Patchen Port
        LD      A,0C7h          ;CB C7=SET 0, (sonst 2)
        LD      (FP4),A         ;Patchen Bit
        LD      A,087h          ;CB 87=RES 0, (sonst 2)
        LD      (FP5),A         ;Patchen Bit

conf1:  ld      a,(F0)          ;eigene Grundfarbe?
        or      a
        RET     z               ;nein
        ld      (BASECOL),A     ;ja, als Grundfarbe
        RET
;-------------------------------------------------
RESTART:;ANHALTEN ZUM LESEN DER FEHLERMELDUNG
        RST     8                      
START1: CALl    STOPP
        CALL    KOPF
        LD      A,R
        LD      (SEED+1),A      ;Zufallsgenerator
        ;HAUPTMENÜ-----------------------------  
START2:  CALL    Befehle
FNKT:   RST     8               ;ABFRAGE FUNKTION
        OR      20H             ;GROß=KLEIN           
        CP      "l"             ;EINZELSONG?
        JR      Z,EINZEL     
        CP      "p"             ;Playliste
        JP      Z,LISTE       
        CP      "a"             ;ALLES SPIELEN
        JP      Z,SERIE
        CP      "z"             ;ZUFALLSMODUS
        JP      Z,ZUFALL
        CP      "u"             ;USB-INIT
        JP      Z,START01
        cp      "i"
        JR      Z,INFO
        CP      "e"             ;ENDE
        JR      NZ,FNKT
        ;PROGRAMM-ENDE----------------------------
HOME:   CALL    STOPP           ;ENDE, INT DEAKTIVIEREN 
        CALL    CLEARSP         ;SPEKTRUM LÖSCHEN
        LD      HL,ROOT
        CALL    USB_CD
        CALL    CLS
RAUS:   LD      A,02h           ;Standard-IV
        LD      I,A   
        EI
        LD      A,(COLTST)      ;Farbe RESET-BYTE
        LD      (BASECOL),A     ;wiederherstellen
        call    cls
        JP      GETCO           ;ZURÜCK ZUM Monitor   
;-------------------------------------------------
INFO:   CALL    KOPF
        LD      DE,T_INFO     
        CALL    TXT1
        JR      RESTART
;EINZELABSPIEL----------------------------------
EINZEL: XOR     A
        LD      (MODNR),A       ;Modus
        CALL    CLS
EIN1:   LD      DE,T_DIR
        CALL    TXT1
        ;NAMENSABFRAGE
        ;DATEINAME LIEGT DANN ALS "1234.xyz" 
        ;AB ADRESSE INBUFF,ENDEMARKIERUNG 0D
        ;WENN FEHLER/ABBRUCH, DANN IST CY GESETZT
        ld      hl,PT3X        ;TYP
        RST     18H        
        DEFM    0dh,"Name:",0A0h
        call    INLINE          ;INLINE
        ld      hl,(INANF)      ;HL= Adresse 1. Eingabezeichen
        LD      A,(HL)          ;1.Zeichen
        cp      '.'             ;Abbruch?
        jp      z,start1        ;ja
        cp      " "             ;Leer?
        jP      nz,IP0          ;nein              
        ;keine Eingabe (nur ENTER): Inhalt anzeigen
        CALL    CLS
        XOR     A
        LD      (DIRFLG),A      ;NORMALE BS-ANZEIGE
        CALL    DIR             ;ANZEIGE USB-INHALTSVERZEICHNIS
        CALL    ISNULL          ;BESTAND?
        JR      NZ,EIN1         ;JA => Namenseingabe
        LD      DE,T_NIX
        CALL    TXT1
        JP      RESTART
IP0:   ;-------Puffer Dateiname leeren:
        LD      DE,nambuf       ;
        LD      B,11
        XOR     a               
IP1:    LD      (DE),A   
        INC     DE
        DJNZ    IP1          ;
        
        ;HL= Eingabepuffer, Dateinamen lesen 
        ;DE= nambuf, aufbereiten         
        LD      DE,NAMBUF       ;Zielpuffer
        ld      a,(HL)          ;1. Zeichen
       
        LD      B,9             ;max. 8 Zeichen      
HFN1:   LD      (DE),A          ;ablegen
        DEC     HL              ;AC1 rückwärts!
        INC     DE
        DEC     B               ;Längenzähler
        jr      z,hfn0          ;nur max. 8 Zeichen!

        LD      A,(HL)          ;nächstes Zeichen
        cp      "."             ;Dateierweiterung angegeben?
        JR      Z,hfn0          ;ja, durch Standard ersetzen
        cp      " "             ;Name im Eingabepuffer fertig?
        jr      nz,HFN1         ;nein
        ;Name fertig, kein ., Vorgabe-Endung anhängen
hfn0:   ld      a,'.'
        LD      (DE),A
        INC     DE
        LD      HL,PT3X   
        LDI                     ;
        LDI                     ;ENDUNG
        LDI                     ;ANHÄNGEN
        LDI                     ;0D
        ;DATEINAME JETZT IN NAMBUF
        ;KONTROLLANZEIGE
        CALL    CLS
        ld      HL,bws-15*64+20 ;Mittig
        ld      (curs),HL

        LD      DE,T_LADE
        CALL    TXT1
        CALL    INVERS_E        ;EIN
        LD      DE,NAMBUF
        CALL    PRNAM
        call    space
        CALL    INVERS_A        ;AUS

        call    short           ;PAUSE
        ;LADEN---------------------------
        LD      HL,SONG         ;ZIEL IM RAM
        LD      (RAMADR),HL     ;LADEADRESSE

        ld      HL,bws-17*64+20 ;Mittig
        ld      (curs),HL

        CALL    _LADEUSB
        JP      C,restart       ;NICHT GEFUNDEN,ZURÜCK ZUM MENÜ   
        ;SONG STARTEN-----------------------
        LD      HL,1
        LD      (SNR),HL
        LD      (max),HL
        CALL    OBER            ;HIERDRIN 1 LIED
        JP      START1          ;FERTIG
;------------------------------------------------
LISTE:  LD      A,1
        LD      (MODNR),A       ;MODUS
        CALL    CLS
        CALL    KAT0            ;KATALOG LEEREN

        LD      HL,T_BNAM       ;NAME der Playliste
        LD      DE,NAMBUF       ;BATCHDATEI
        LD      BC,13
        LDIR
        
        ld      HL,bws-15*64+20 ;Mittig
        ld      (curs),HL
        LD      DE,T_STAPEL     ;Playliste...
        CALL    TXT1

        LD      HL,KAT          ;ZIELADRESSE
        LD      (RAMADR),HL
        CALL    _LADEUSB        ;PLAYLISTE LADEN
        JP      C,RESTART       ;KEINE VORHANDEN
        CALL    CLS
        ;DATEIEN IM BATCHFILE (KATALOG) ZÄHLEN
        CALL    DIR0            ;ANZAHL=0
        LD      HL,KAT          ;ANFANG KATALOG
LISTE1: LD      A,(HL)
        OR      A               ;ENDE?
        JR      Z,SERIE1        ;FERTIG
        CP      0DH
        CALL    Z,DIRPLUS       ;1 DATEI MEHR
        INC     HL
        JR      LISTE1
;------------------------------------------------
SERIE:  LD      A,2
        LD      (MODNR),A
        CALL    CLS
        ld      HL,bws-15*64+20 ;Mittig
        ld      (curs),HL
        LD      DE,T_EINLES 
        CALL    PRNST

        CALL    KAT0            ;KATALOG LÖSCHEN
        LD      A,1
        LD      (DIRFLG),A      ;DIR ZEIGT NICHTS AN, 
                                ;SONDERN SCHREIBT KATALOG
        CALL    SONG1           ;SONGNR AB 1
        CALL    DIR             ;EINLESEN
SERIE1: CALL    ISNULL          ;BESTAND?
        JR      NZ,SERIE3       ;JA
        LD      DE,T_NIX        ;NEIN
SERIE2: CALL    PRNST
        JP      RESTART
SERIE3: CALL    SONG1           ;Beginn mit Songnr 1
        LD      HL,(DIRANZ)
        LD      (max),HL

        ;AUS KATALOG SONGNAMEN NACHEINANDER HOLEN
        LD      HL,KAT          ;ANFANGSADRESSE KATALOG
        LD      (KATPOS),HL     
        ;NAME HOLEN, KOPIEREN NACH NAMBUF=DATEINAME, 0D-TERMINIERT
SERIE4: LD      HL,(KATPOS)
        LD      DE,NAMBUF
SERIE5: LD      A,(HL)
        CP      0AH             ;ÜBERLESEN (TRITT BEI BATCH AUF)
        JR      NZ,SERIE6
        INC     HL              
        JR      SERIE5
SERIE6: OR      A
        JP      Z,START1        ;KEIN WEITERER NAME MEHR!
        CP      0DH             ;NAME FERTIG KOPIERT?
        JR      Z,SERIE7        ;NOCH NICHT
        LDI
        JR      SERIE5
SERIE7: LDI                     ;0D NOCH ÜBERNEHMEN!
        ;HL=ANFANG NÄCHSTER NAME!
        LD      (KATPOS),HL     ;SETZEN
        ;DATEINAME IST IN NAMBUF
        CALL    CLS
        ld      HL,bws-15*64+20 ;Mittig
        ld      (curs),HL

        LD      DE,T_LADE       ;"LADEN"
        CALL    PRNST
        CALL    INVERS_E        ;EIN
        LD      DE,NAMBUF
        CALL    PRNAM           ;NAME AUSGEBEN
        call    space
        CALL    INVERS_A        ;AUS
 
        call    short           ;Pause
        ld      HL,bws-17*64+20 ;Mittig
        ld      (curs),HL       ;VORBEREITEN FÜR EVTL. FEHLERMELDUNG
  
        ;LADEN---------------------------          
        LD      HL,SONG         ;LADEADRESSE
        LD      (RAMADR),HL     ;DORTHIN! 
        CALL    _LADEUSB        ;CARRY, WENN FEHLER
        Jr      nC,fund1
        ;nicht gefunden!
        call   short            ;Anzeigepause
        jr       serie10        ;nächster SOng
           
fund1:  CALL    OBER            ;HIERDRIN 1 LIED
        PUSH    AF
        CALL    STOPP
        POP     AF
        ;HIER WEITER, WENN SONG ZU ENDE/STOPP/+/-
        ;RÜCKGABEWERT TESTEN:
        CP      "M"             ;Menü?
        JP      Z,START1        ;JA
        CP      "+"             ;Nächster
        JR      Z,SERIE10       ;JA
        cp      "-"
        jr      Z,SERIE13
        ;PAUSE--------------------------------
        CALL    CLS
        LD      B,3
SERIE8: PUSH    BC
        ld      HL,bws-15*64+25 ;Mittig
        ld      (curs),HL
        LD      DE,T_PAUSE
        CALL    PRNST
        LD      A,B
        ADD     A,30H
        CALL    PRINT           ;PAUSENWERT AUSGEBEN 3...0
        ;Pause----------------
        LD      BC,0
SERIE9: DEC     BC
        LD      A,B
        OR      C
        JR      NZ,SERIE9
        POP     BC
        DJNZ    SERIE8
        ;--------------------
SERIE10:CALL    CLS
        LD      DE,(MAX)        ;SOVIEL SIND DA
        LD      HL,(SNR)        ;LAUFENDE NR.
        OR      A
        SBC     HL,DE
        ADD     HL,DE
        JP      NC,START1       ;WAR SCHON LETZTER
        INC     HL              ;ERHÖHEN
SERIE11: LD    (SNR),HL
        JP      SERIE4
SERIE13:;RÜCKWÄRTS--------------------------------
        LD      DE,1
        LD      HL,(SNR)
        OR      A
        SBC     HL,DE
        ADD     HL,DE
        JP      Z,START1        ;WAR SCHON 1, NICHT WEITER ZURÜCK!
        DEC     HL
        LD      (SNR),HL
        ;IM KATALOG EINEN EINTRAG ZURÜCK:
        LD      HL,(KATPOS)     ;STEHT AUF ANFANG NÄCHSTER NAME
        DEC     HL              ;AUF 0D (0A BEI PLAYLISTE)
        LD      A,0AH
        CP      (HL)
        JR      NZ,SERIE14
        DEC     HL              ;WAR PLAYLISTE
        ;HL= 0D DER AKT. DATEI
SERIE14:DEC     HL
        LD      A,(HL)
        CP      0               ;KATALOG-ANFANG?
        JP      Z,START1        ;JA, 1. WIRD SCHON GESPIELT
        CP      0DH
        JR      NZ,SERIE14
SERIE15:DEC     HL
        LD      A,(HL)
        CP      0               ;ZIEL=1. DATEI?
        JR      Z,SERIE16
        CP      0DH
        JR      NZ,SERIE15
SERIE16: INC     HL             ;1. ZEICHEN NAME
        LD      (KATPOS),HL
        JP      SERIE4
;-------------------------------------------------            
SONG1:  LD      HL,1            ;SONG-NR AUF 1 SETZEN
        LD      (SNR),HL
        RET 
;------------------------------------------------
ZUFALL: LD      A,3
        LD      (MODNR),A
        CALL    CLS
        ;GUCKEN, OB SCHON MAL GEZÄHLT:

        LD      HL,(TMAX)
        LD      A,H
        OR      L
        JR      NZ,ZUF2         ;JA, SUMME VORHANDEN
        ;NOCH NICHT, ERST ZÄHLEN:
        ld      HL,bws-13*64+20  ;Mittig
        ld      (curs),HL
        LD      DE,T_ZAEHLE     
        CALL    PRNST  
        LD      A,2             ;NUR ZÄHLEN
        LD      (DIRFLG),A      ;
        CALL    DIR             ;DIR
        ;(DATANZ) IST BEFÜLLT
        LD      HL,(DIRANZ)
        LD      (TMAX),HL       ;ANZAHL MERKEN
        CALL    ISNULL          ;BESTAND?
        JR      NZ,ZUF1         ;JA
        ld      HL,bws-14*64+20 ;Mittig
        ld      (curs),HL
        LD      DE,T_NIX        ;NEIN
        CALL    PRNST
        JP      RESTART
        ;SUMME ANZEIGEN:
ZUF1:   PUSH    HL
        POP     DE
        LD      HL,BWS-13*64+30 ;gefundene
        CALL    DEZDE
ZUF2:   ld      HL,bws-15*64+20 ;Mittig
        ld      (curs),HL
        LD      DE,T_SUCHE     
        CALL    PRNST  

        CALL    SHORT           ;KURZE PAUSE 
        LD      A,R
        LD      (SEED),A
        CALL    ZUFGEN          ;ZUFALLSZAHL
        INC     HL              ;DA 0...N-1
        LD      (ASCII),HL      ;NUMMER MERKEN
        ;PER DIR MIT NUMMER SONGNAME HOLEN
        LD      A,3             ;HOLEN DATEINAME
        LD      (DIRFLG),A      ;
        CALL    DIR             ;DIR
        ;IN INBUFF STEHT DATEINAME,OHNE 0D
        ;UMKOPIEREN NACH NAMBUF
        LD      HL,INBUFF
        LD      DE,NAMBUF
        LD      A,"."
ZUF3:   LDI
        CP      (HL)
        JR      NZ,ZUF3         ;.SUCHEN
        LDI     ;.              ;ENDUNG+0D ANHÄNGEN!
        LDI     ;P
        LDI     ;T
        LDI     ;3
        LD      A,0DH
        LD      (DE),A
        ;ANZEIGE AUSGEWÄHLER ZUFALLSSONG
        ;CALL    INVERS         ;EIN
        LD      DE,NAMBUF
        CALL    PRNAM
        call    space
        ;
        CALL    SHORT           ;KURZE PAUSE
        LD      HL,SONG         ;LADEADRESSE
        LD      (RAMADR),HL     ;DORTHIN! 
        CALL    _LADEUSB        ;CARRY, WENN FEHLER
        jp       c,START1       ;nicht gefunden

        LD      HL,(ASCII)
        LD      (SNR),HL        ;ZUFALLSNUMMER
        LD      HL,(TMAX)
        LD      (MAX),HL        ;GESAMTANZAHL
ZUF4:   CALL    OBER
        PUSH    AF
        CALL    STOPP
        POP     AF
        CP      "-"
        JP      Z,ZUF4          ;AKTUELLEN SONG NOCHMAL
        CP      "M"
        JP      Z,START1        ;ENDE, ZUM MENÜ
        ;WAR + ODER SONGENDE: 
        JP      ZUFALL          ;NEUER ZUFALLSSONG
;------------------------------------------------
;PLAYEROBERFLÄCHE
;ENDET MIT A='+', '-' ODER 'M' FÜR SONGSTEUERUNG
OBER:   XOR      A
        LD      (PAUSE),A       ;KEINE PAUSE
        LD      HL,SETUP        ;
        SET     0,(HL)          ;AUTO-LOOP aus

        ;SONGADRESSE
        LD       HL,SONG
        LD      (MODADR),HL ;FÜR PLAYER ÜBERGEBEN
        ;OBERFLÄCHE------------------------------
        CALL    RAHMEN

        ;DATEINAME-------------------------------
        LD      HL,BWS-5*64+22
        ld      (CURS),HL
        LD      DE,NAMBUF
        CALL    PRNAM           ;BIS 0D

         ;SONGNUMMER-----------------------------
        LD      DE,(SNR)        ;1...(MAX)
        LD      HL,BWS-23*64+23
        CALL    DEZDE


        ;MAXIMALANZAHL SONGS--------------------
        LD      DE,(MAX)        ;GESAMTANZAHL
        LD      HL,BWS-24*64+23
        CALL    DEZDE  

        ;SONGTITEL------------------------------
        LD      HL,BWS-7*64+6+9
        LD      (CURS),HL
        LD      DE,SONG+30      ;(MODADR)
        CALL    PRINFO          ;32 BYTES
        ;Songautor-------------------------------
        LD      HL,BWS-8*64+6+9
        LD      (CURS),HL
        LD      DE,SONG+66      ;(MODADR)
        CALL    PRINFO          ;32 BYTES   

        ;SONGTEMPO------------------------------
        LD      HL,SONG+100
        LD      A,(HL)
        LD      HL,BWS-10*64+22
        CALL    DEZA

        ;POSITIONEN GESAMT------------------------
        LD      HL,SONG+101     ;ANZAHL MUSTER GESAMT
        LD      A,(HL)
        LD      HL,BWS-13*64+22
        CALL    DEZA

        ;MODUS-----------------------------------------
        LD      HL,BWS-23*64+42
        LD      (CURS),HL

        LD      A,(MODNR)
        LD      DE,T_SINGL
        OR      A               ;EINZEL?
        JR      Z,OBER1
        LD      DE,T_LISTE        
        CP      1
        JR      Z,OBER1
        LD      DE,T_REIHE 
        CP      2
        JR      Z,OBER1 
        LD      DE,T_ZUFAL
OBER1:  ;CALL    INVERS
        CALL    TXTOUT
        ;CALL    INVERS

        ;SPIELDAUER--------------------------------

        CALL    CALC
        PUSH    HL
        LD      A,H
        LD      HL,BWS-13*64+43     
        CALL    DEZA            ;DEZIMALANZEIGE MINUTEN
        LD      A,":"           ;TRENNER
        CALL    PRINT
        POP     HL
        LD      A,L
        LD      HL,BWS-13*64+46   
        CALL    DEZA            ;DEZIMALANZEIGE SEKUNDEN
        LD      HL,(PT3TIME)    ;
        LD      (TICKS),HL      ;MERKEN

        ;ABSPIEL STARTEN----------------------------
        CALL    PLAY
        EI                      ;INT FREIGEBEN, SONG STARTET
        ;HALT                   ;SYNCHR.

;SCHLEIFE FÜR ANZEIGE-----------------------
LOOP:  ;NACH JEDEM n. DURCHLAUF BALKENABFALL
        ;Höhe 4 Durchläufe halten
        LD      A,2             ;'2' wird modifiziert
OBER2:  equ $-1      
        INC     A
        AND     03H
        LD      (OBER2),A
        Jr      NZ,OBER5        ;HALTEN

        ;SPEKTRUM-PUFFER: ABFALL DES LETZTEN WERTES
OBER2A: LD      B,20H           ;32X
        LD      HL,SPEKBU       ;PUFFERANFANG
OBER3:  XOR     A               ;
        OR      (HL)            ;INHALT AN POSI=0?
        JR      Z,OBER4         ;JA, NÄCHSTEN
        DEC     (HL)            ;NEIN, HÖHE VERMINDERN
OBER4:  INC     HL    
        DJNZ    OBER3
        ;SPEKTRUMWERTE ERMITTELN+ANZEIGEN
OBER5:  LD      HL,(TON_A)      ;TONHÖHE A
        LD      A,(VOL_A)       ;LAUTSTÄRKE A
        CALL    SPEKT
        LD      HL,(TON_B)      ;TONHÖHE B
        LD      A,(VOL_B)       ;LAUTSTÄRKE B
        CALL    SPEKT
        LD      HL,(TON_C)      ;TONHÖHE C
        LD      A,(VOL_C)       ;LAUTSTÄRKE C
        CALL    SPEKT 
        ;Erweiterung für Hüllkurventöne
        LD      A,(HK_F)        ;HK-FORM
        BIT     3,A             ;WIEDERHOLT?
        JR      Z,ober5a        ;NEIN
        LD      HL,(HK_D)       ;HÜLLKURVENPERIODE
        ADD     HL,HL           ;*2
        ADD     HL,HL           ;*4
        ADD     HL,HL           ;*8
        ADD     HL,HL           ;*16
        ADD     HL,HL           ;*32
        LD      A,15            ;VOLLE PULLE BEI HK-TON
        call    spekt
ober5a:
        CALL    SPEKANZ         ;SPEKTRUM ANZEIGEN
        ;ANZEIGE FORTSCHRITT
        LD      A,(POSI)        ;AKT. POSI
        LD      HL,BWS-12*64+22
        CALL    DEZA
        ;AKT. MUSTER-NR.
        ;LD      HL,(CRPSPTR)   ;ADRESSE MIT AKT. PATTERN
        ;LD      A,(HL)         ;PATTERN-NR.
        ;CALL    DIV3           ;./. 3
        ;LD      HL,BWS-9*64+44
        ;CALL    DEZA
        ;RESTZEITANZEIGE
        CALL    PT3T_EXIT       ;HOLEN
        LD      A,20            ;TEST AUF
        CP      H               ;ÜBERLAUF?
        JR      c,xxx           ;JA!
        PUSH    HL
        LD      A,H
        LD      HL,BWS-12*64+43     
        CALL    DEZA            ;DEZIMALANZEIGE MINUTEN
        LD      A,":"           ;TRENNER
        CALL    PRINT
        POP     HL
        LD      A,L
        LD      HL,BWS-12*64+46   
        CALL    DEZA            ;DEZIMALANZEIGE SEKUNDEN
xxx:   ;SONGENDE BERÜCKSICHTIGEN
        LD      HL,SETUP
        BIT     7,(HL)          ;ENDE-BIT =1 GESETZT?
        JR      Z,OBER6         ;NOCH NICHT
        ;SONG ZUENDE
        RES     7,(HL)          ;ZURÜCKSETZEN 
        LD      A,1
        LD      (POSI),A
        BIT     0,(HL)          ;LOOP-BIT=0 GESETZT ?
        RET     NZ              ;KEIN LOOP
        ;LOOP:
        LD      HL,(TICKS)      ;GESAMTZEIT
        LD      (PT3TIME),HL    ;ALS NEUE RESTZEIT
OBER6:  ;TASTATURABFRAGE
        xor     a
        CALL    TASTE           ;TASTATURSTATUS
        CP      "L"             ;LOOP EIN/AUS
        jr      nz,TP
        CALL    LOOP_EA
        jp      loop

tp:     CP      "P"
        jr      nz,zur
        CALL    PAU_EA          ;PAUSE E/A
        jp      loop

zur:    CP      "-"
        RET     Z
        CP      "+"
        RET     Z
        CP      "M"             ;MENÜ
        RET     Z
        JP      LOOP
;-------------------------------------------------
;TITEL+AUTOR ANZEIGEN (32 BYTES ab HL)
PRINFO: ld      a,(F1)          ;Farbe Titel/Autor
        or      a               ;00=Standard?
        jr      z,T1            ;ja, basecol
        cp      0ffh            ;standard invers?
        jr      nz,T0           ;nein, eigene!
        ld      a,(BASECOL)     ;Akt. Standardfarbe
        xor     01110111b       ;invers
T0:     ld      (color),A       ;
T1:     LD      B,33            ;Länge
T2:     LD      A,(DE)
        CALL    PRINT           ;ZEICHEN AN SCHIRM
        INC     DE
        DJNZ    T2
        ld      a,(BASECOL)     ;Akt. Standardfarbe
        LD      (COLOR),A
        ret
;-------------------------------------------------
PAU_EA: ;PAUSE EIN/AUS
        PUSH    AF
        LD      A,(PAUSE)
        CPL
        LD      (PAUSE),A
        OR      A
        LD      DE,T_AUS        ;"AUS"
        JR      Z,PAU1          ;NEIN
        CALL    STOPP1          ;STUMMSCHALTEN
        CALL    CLEARSP         ;SPEKTRUM LÖSCHEN
        LD      DE,T_EIN        ;"EIN"
PAU1:   LD      HL,BWS-26*64+36
PAU2:   CALL    TXTOUT

        ;warten
        ld       b,3
pau3:   call     ms30
        djnz pau3
        POP     AF
        RET
;-----------------------------------------
LOOP_EA:PUSH    AF
        LD      A,(SETUP)
        XOR     1               ;LOOP_BIT
        LD      (SETUP),A       ;INVERTIEREN
        ;ANZEIGE LOOP EIN/AUS
        LD      HL,BWS-26*64+12+9
        OR      A               ;0=EIN ?
        LD      DE,T_EIN        ;ja
        JR      Z,PAU2 
        LD      DE,T_AUS        ;"AUS"
        JR      PAU2            ;AUSGABE TEXT
;-------------------------------------------------
;DEZIMALANZEIGE DE, 4STELLIG
;POSITION IN HL
DEZDE:  LD      (CURS),HL       ;AUSGABE-POSITION
        LD      C,30H           ;KEINE VORNULL-UNTERDRÜCKUNG!
        LD      HL,03E7h        ;999
        AND     A
        SBC     HL,DE
        JR      C,DEZ3
        LD      A,C
        CALL    PRINT           ;AUSGEBEN AUF SCHIRM
        JR      DEZ1
        ;DEZIMALANZEIGE  A=AUSGABEWERT
        ;HL=SCHIRMPOSITION ZEILE,SPALTE
DEZA:   LD      (CURS),HL
        LD      C,30H
        LD      E,A
        LD      D,0
        JR      DEZ2
DEZ1:   LD      C,30H
        LD      HL,0063H        ;99
        AND     A
        SBC     HL,DE
        JR      C,DEZ3
        LD      A,C
        CALL    PRINT           ;AUSGEBEN AUF SCHIRM
DEZ2:   LD      HL,0009H        ;9
        AND     A
        SBC     HL,DE
        JP      C,DEZ3
        LD      A,C
        CALL    PRINT           ;AUSGEBEN AUF SCHIRM
DEZ3:   EX      DE,HL
DEZ4:   LD      DE,000AH
        CALL    DEZ5
        LD      A,L
        LD      H,B
        LD      L,C
        PUSH    AF
        LD      A,L
        OR      H
        CALL    NZ,DEZ4
        POP     AF
        ADD     A,30H           ;ZIFFER
        CALL    PRINT           ;AUSGEBEN AUF SCHIRM
        RET                     ;AUSGEBEN AUF SCHIRM
DEZ5:   LD      B,L
        LD      L,H
        LD      H,0
        CALL    DEZ6
        LD      H,L
        LD      L,B
        LD      B,C
DEZ6:   LD      C,0FFH
DEZ7:   AND     A
        SBC     HL,DE
        INC     C
        JP      NC,DEZ7
        ADD     HL,DE
        RET
;-------------------------------------------------
;A:=A/3
DIV3:   LD      D,A
        LD      E,3
        XOR     A
        LD      B, 8
_LOOP:  SLA     D
        RLA
        CP      E
        JR      C, $+4
        SUB     E
        INC     D
        DJNZ    _LOOP
        LD      A,D
        RET
;Spektrum-----------------------------------------
;PUFFER LÖSCHEN
CLEARSP:LD       HL,SPEKBU-1
        LD       (HL),0
        LD       DE,SPEKBU
        LD       BC,34
        LDIR
        CALL     SPEKANZ
        RET
;SPEKTRUMWERTE ERMITTELN-------------------------
;KOMMT MIT  
; A= LAUTSTÄRKE (0...15+)   = AKT. BALKENHÖHE
;HL= TONHÖHE  (0FFF...0001) = BALKENPOSITION

SPEKT:  RRA                     ;./. 2
        AND     7               ;0...7 LAUTSTÄRKE
        LD      B,A             ;MERKEN
        SCF
        CCF
        RL      L
        RL      H               ;HL=FREQUENZWERT *2
        RL      L               ;NOCHMAL, SO
        RL      H               ;BESSERER VERLAUF
        
        LD      A,H             ;NUR HIGH-TEIL
        AND     1FH             ;0...31
        LD      L,A
        LD      H,0
        ;HL=0...1F  = 32 FREQUENZ-STUFEN        
        ;NICHTLINEAR, OBEN SEHR GEDRÄNGT!
        ;AUF ENTSPRECHENDER TABELLENPOSITION WIRD 
        ;NUN DIE AKTUELLE LAUTSTÄRKE ABGELEGT:
        ;DIE DREI KANÄLE VERODERT
        LD      DE,SPEKBU       ;PUFFERANFANG
        ADD     HL,DE           ;AKT. POSI
        ;LD     B,A             ;LAUT
        LD      A,B
        OR      (HL)            ;MIT ALTEM WERT VERODERN
        LD      (HL),A          ;ABLEGEN
        ;RECHTS UND LINKS DANEBEN NOCH JEWEILS HALBE SÄULE
        ;DAMIT WIRD DER LINKE STARK GEDEHNTE NIEDERFREQUENTE
        ;BEREICH BESSER "GEFÜLLT"
        INC     HL              ;NÄCHSTES
        SRL     B               ;B:= B/2
        LD      A,B
        OR      (HL)
        LD      (HL),A          ;RECHTS DANEBEN
        DEC     HL
        DEC     HL
        LD      A,B
        OR      (HL)
        LD      (HL),A          ;LINKS DANEBEN
        RET
;-------------------------------------------------
SPEKANZ:;SPEKTRUM-PUFFER IST BEFÜLLT, JETZT DARSTELLEN
;METHODE ABHÄNGIG VON BWS-BEHANDLUNG
        LD      B,20H           ;32 BÄNDER
        LD      HL,SPEKBU       ;ANFANG
SPANZ1: PUSH    BC
        LD      A,(HL)          ;PUFFERWERT HOLEN
        INC     HL
        PUSH    HL              ;NÄCHSTEN
        ;1 BALKEN DARSTELLEN
        LD       HL,BWS-21*64+15 ;LAGE SPEKTRUM LINKS UNTEN
        LD       E,B            ;DE= N*+100H   0...7 
        LD       D,0
        OR       A
        SBC      HL,DE          ;BALKEN RECHTS DANEBEN
        LD       DE,64          ;ABSTAND SENKRECHT
        OR       A
        JR       Z,SPANZ3       ;KEIN BALKEN
        ;JE NACH AMPLITUDE MEHRERE KLÖTZER:
        LD      B,A             ;PUFFERWERT = BALKENHÖHE
SPANZ2: push    af
        ld      a,(ZG2)         ;
        LD      (HL),A          ;0B4h   ;KLOTZ ZEICHNEN
        pop     af
        
        
        ADD      HL,DE          ;1 ZEILE HÖHER
        DJNZ    SPANZ2
        ;RESTL. KLÖTZER LÖSCHEN
SPANZ3: LD       B,A            ;AKT. HÖHE
        LD       A,7            ;MAX
        SUB      B
        LD       B,A            ;RESTHÖHE
        OR       A
        JR       Z,SPANZ5       ;NICHTS ZU LÖSCHEN
        
SPANZ4: LD       (HL),' '       ;LÖSCHEN
        ADD      HL,DE          ;1 ZEILE HÖHER
        DJNZ     SPANZ4         
        ;NÄCHSTER BALKEN
SPANZ5: POP     HL
        POP     BC
        DJNZ    SPANZ1          ;32X
        RET
;-------------------------------------------------
RAHMEN: RST     18h
        defb    0ch,8ah
        ;Grafikzeichen ein
        ld      hl,1820h
        set     7,(hl)
        ld      de,T_R1
        call    MALEN
        ;Grafikzeichen aus
        ld      hl,1820h
        RES     7,(hl)
        ;Spektrumfläche Vordergrundfarbe invertieren , wenn Farbe
        call    iscol
        ret     z
        call    colon
        ld      a,(BASECOL)     ;reset-Farbe
        xor     00000111b       ;Vordergrund invertieren
        or      00001000b       ;immer intensiv
        LD      HL,BWS-21*64+16 ;LAGE SPEKTRUM LINKS UNTEN
        LD      DE,64
        ld      B,7
R1:     PUSH    HL
        PUSH    BC
        LD      b,32
R2:     LD      (HL),A
        DEC     HL
        DJNZ    R2
        POP     BC
        POP     HL
        ADD     HL,DE
        DJNZ    R1
        call    coloff
        RET
;-------------------------------------------------
MALEN:  LD      A,(DE)          ;ZEICHEN HOLEN
        OR      A               ;ENDE ERREICHT?
        RET     Z               ;JA
        CP      "$"
        JR      Z,REPL
        cp      "&"
        jr      z,REPL2
        cp      "?"
        jr      z,repl3
        CALL    PRINT           ;AUSGEBEN AUF SCHIRM
MALEN1: INC     DE
        JR      MALEN           ;NÄCHSTES
REPL:   LD      B,13
        ld      a," "
REP1:   CALL    PRINT
        DJNZ    REP1
        JR      MALEN1
        RET
REPL2:  LD      B,35
        ld      a,(ZG1)         ;0A0h
        jr      rep1
REPL3:  LD      B,35
        ld      a,' '
        jr      rep1
;----------------------------------------------------
KOPF:   call cls
        ld      hl,1820h
        set     7,(hl)          ;Grafikzeichen ein
        ld      a,(BASECOL)     ;Reset-Farbe
        ld      (color),A
        ld      hl,bws-4*64
        ld      (curs),HL
        ld      de,T_Kopf
        call    MALEN
        ld      hl,1820h        ;Grafikzeichen aus
        RES     7,(hl)
        ld      a,(BASECOL)
        ld      (color),A       ;Standard-(RESET-)Farbe
        RET

T_Kopf: defm    24h,0a8h,"&",0a9h,0dh
        defm    24h,0a1h,"PT3-USB-Player AC1-2010   WeRo'2018",0a1h,0dh
        defm    24h,0A1h,"V1.3   4MHz CPU + CTC-Quarz 3,58MHz",0A1h,0dh
        defm    24h,0a7h,"&",0aah,0

T_R1:   defm    0ch,0eh,"0400"
        defm    24h,0a8h,"&",0a9h,0dh
        defm    24h,0a1h," Datei:$$  ",0a1h,0dh
        defm    24h,0A3h,"&",0A5h,0dh
        defm    24h,0a1h,"?",0a1h,0dh
        defm    24h,0a1h,"?",0a1h,0dh
        defm    24h,0a3h,"&",0a5h,0dh
        defm    24h,0a1h,"Tempo:$$   ",0a1h,0dh
        defm    24h,0a3h,"&",0a5h,0dh
        defm    24h,0a1h,"Muster:$  Dauer:       ",0a1h,0dh
        defm    24h,0a1h,"   von$     von        ",0a1h,0dh
        defm    24h,0a3h,"&",0a5h,0dh
        defm    24h,0a1h,"?",0a1h,0dh
        defm    24h,0a1h,"?",0a1h,0dh
        defm    24h,0a1h,"?",0a1h,0dh
        defm    24h,0a1h,"?",0a1h,0dh
        defm    24h,0a1h,"?",0a1h,0dh
        defm    24h,0a1h,"?",0a1h,0dh
        defm    24h,0a1h,"?",0a1h,0dh
        defm    24h,0a3h,"&",0a5h,0dh
        defm    24h,0a1h,"Song: (-)    (+)     Modus:        ",0a1h,0dh
        defm    24h,0A1h," von$$     ",0A1h,0dh
        defm    24h,0A3h,"&",0A5h,0dh
        ;ein/aus ist invers:
        defm    24h,0a1h,"(L)oop",11h,"aus ",10h,"  (P)ause",11h,"aus ",10h," (M)enu ",0a1h,0dh
        defm    24h,0a7h,"&",0aah,0
;ZUFALLSGENERATOR
;SEED WIRD BEIM PROGRAMMSTART GESETZT (R-REGISTER)
ZUFGEN: LD      DE,(SEED)       ;STARTWERT
        LD      A,D
        LD      H,E
        LD      L,253
        OR      A
        SBC     HL,DE
        SBC     A,0
        SBC     HL,DE
        LD      D,0
        SBC     A,D
        LD      E,A
        SBC     HL,DE
        JR      NC,RAND
        INC     HL
RAND:   LD      (SEED),HL       ;SEED GGF. FÜR NÄCHSTEN LAUF
        ;HL= PSEUDO-ZUFALLSZAHL 0000...FFFF
        ;BEGRENZEN AUF (TMAX) : DIVISION, REST NEHMEN!
        LD      DE,(TMAX)
        LD      A,H
        LD      C,L
        ;DIV_AC_DE, REST IN HL
        LD      HL, 0
        LD      B, 16
Z_LOOP: DEFB    0CBh,31h        ;"SLL C"=UNDOKUMENTIERTER OP-CODE
        RLA
        ADC     HL, HL
        SBC     HL, DE
        JR      NC, $+4
        ADD     HL, DE
        DEC     C
        DJNZ    Z_LOOP
        ;REST=HL=BEGRENZTE ZAHL 0...(DATANZ-1)
        RET
;#Farbkram#############################################
;test, ob Farbausgabe
ISCOL:  LD      A,(FARBE)       ;
        OR      A
        RET                     ;Z gesetzt, wenn keine Farbe
;FARBRAM ein/aus---------------------------------------
COLON:  push    af
        in      a,(0F0h)        ;original
FP1:    equ     $-1             ;ggf. patchen F2
        set     2,a             ;original    cb d7
FP4:    equ     $-1             ;ggf patchen cb C7      
        jr      wrcol
COLOFF: push    af
        in      a,(0F0h)        ;original
FP2:    equ     $-1             ;ggf. patchen!
        res     2,a             ;CB 97 original
FP5:    equ     $-1             ;ggf. patchen cb C7 87
wrcol:  out     (0F0h),a        ;ori
FP3:    equ     $-1             ;ggf. patchen
        pop af
        ret
;--------------------------------------------
TASTE:  CALL    07FAh
        AND     A,7FH
        RET

CLS:    ld      a,0ch
        rst     10h
        call    iscol
        ret     z
        ;noch Farb-.Ram löschen, wenn vorhanden
        call    COLON
        ld      a,(BASECOL)     ;Reset-Farbe         
        ld      hl,1000h
        ld      (HL),A
        LD      DE,1001h
        ld      BC,0800h
        LDIR
        call    coloff
        ;--------------
        ld      a,1 ;home
        jr      pout
;------------------------------------------
NEWL:   LD      A,0Dh
        jr      pout
INVERS_E:LD     A,11h
        jr      pout
INVERS_A:ld     a,10h
        jr      pout
SPACE:  LD      A,' '
;------------------------------------------
PRINT:  ;FARBE (COLOR) bei PRINT setzen
        ld      hl,(CURS)       ;akt. BWS-Adresse
        push    af        
        call    ISCOL           ;Z wenn keine Farbe 
        jr      z,setcolx       ;keine Farbe
        ;FARBE:
        ld      a,(COLOR)       ;holen
SETCOL: call    COLON           ;Umschalten auf Farb-RAM
        ld      (HL),A          ;Farbe setzen
        call    coloff          ;Umschalten auf ASCII-RAM
setcolx:pop     af
POUT:   JP      10h

;-----------------------------------------------
PRNST:  ;Ausgabe Text ab DE bis 0
        LD      A,(DE)          ;ZEICHEN HOLEN
        CP      0;0FFH          ;ENDE ERREICHT?
        RET     Z               ;JA
        CALL    PRINT           ;AUSGEBEN AUF SCHIRM
        INC     DE
        JP      PRNST           ;NÄCHSTES
;-------------------------------------------------
;TEXT AB DE DIREKT AUSGEBEN AUF BWS, BIS 0
;KOMMT MIT HL=ANFANGSADRESSE SCHIRM
TXTOUT: LD      (CURS),HL 
TXT1:   LD      A,(DE)          ;ZEICHEN HOLEN
        OR      A               ;ENDE ERREICHT?
        RET     Z               ;JA
        CALL    PRINT           ;AUSGEBEN AUF SCHIRM
        INC     DE
        JR      TXT1            ;NÄCHSTES
;-------------------------------------------------
;TEXT AUSGEBEN BIS FF
TOUT:   LD      A,(DE)          ;ZEICHEN HOLEN
        CP      0FFH            ;ENDE ERREICHT?
        RET     Z               ;JA
        CALL    PRINT           ;AUSGEBEN AUF SCHIRM
        INC     DE
        JR      TOUT            ;NÄCHSTES
;--------------------------------------------------

BEFEHLE:RST  18h
        DEFM 0eh,"0915(L)aden Einzelsong",0DH,0AH
        DEFM 0eh,"1115(P)layliste  spielen",0DH,0AH
        DEFM 0eh,"1315(A)lle Songs in Reihe spielen",0DH,0AH
        DEFM 0eh,"1515(Z)ufallsabspiel",0DH,0AH 
        DEFM 0eh,"1715(U)SB Stickwechsel/Init",0DH,0AH
        DEFM 0eh,"1915(I)nfo",0DH,0AH          
        DEFM 0eh,"2115(E)nde",0DH,0AH  
        DEFM 0eh,"2315-> Funktion:",0A0h
        RET


;-----------------------------------------------------
T_INFO: DEFM 0DH,0AH,0EH,"1010"
        DEFM "Unter Verwendung von Grundroutinen aus:",0dh,0ah
        DEFM 15,"  * PT3 PLAYER ZX SPECTRUM : S. BULBA, 2007",0dh
        DEFM 15,"  * PT3 DURATION CALCULATOR: S. BULBA, 2005",0dh
        DEFM 15,"  * SPEKTRUMANZEIGE (ST1.x): 'BZYK',   1992",0dh,0ah
        DEFM 15,"  Config-Bytes:",0dh,0ah
        defm 15,"  (4008h)=Port Farbkarte",0dh
        defm 15,"  (4009h)=Standardfarben Player  (00=wie Moni)",0dh
        defm 15,'  (400Ah)=Farben Titel-/Autorinfo     -"-     ',0dh
        defm 15,"  (400Bh)=Rahmenzeichen '-'",0dh
        defm 15,"  (400Ch)=Grafikzeichen Spektrum",0
;-------------------------------------------------------

T_EIN:  DEFM "ein",0
T_AUS:  DEFM "aus",0
T_SINGL:DEFM "EINZEL",0
T_LISTE:DEFM "LISTE",0
T_REIHE:DEFM "REIHE",0
T_ZUFAL:DEFM "ZUFALL",0
T_INIT: DEFM "INIT USB...",0
T_NOPT3:DEFM "      KEIN PT3-VERZEICHNIS!",0DH,0AH,0
T_NIX:  DEFM "KEINE SONGS IN /PT3!",0
PT3X:   DEFM "PT3",0DH,0        ;UNTERVERZEICHNISNAME
ROOT:   DEFM "/",0DH,0          ;WURZELVERZEICHNIS
T_USBERR:   DEFM " USB-FEHLER!",0
T_NOTFND:   DEFM " NICHT GEFUNDEN!",0
T_DIR:      DEFM 0DH,0AH,"<ET>=DIR, <.>=ABBRUCH>",0
T_WEITER:   DEFM 0DH,"<ET>=weiter, <.>=ABBRUCH>",0
T_NAM:      DEFM 0DH,"DATEINAME (OHNE .PT3) ? ",0
T_ZAEHLE:   DEFM "ZAEHLEN...",0
T_LADE:     DEFM "LADEN: ",0
T_SUCHE:    DEFM "SUCHEN... ",0
T_MOMENT:   DEFM 6,3,17,"DIR abgebrochen, MOMENT...",16,0
T_BNAM:     DEFM "!PLAYLST.TXT",0DH,0
T_STAPEL:   DEFM "PLAYLISTE...",0
T_EINLES:   DEFM "LESE SONGS EIN...",0
T_ZUVIEL:   DEFM "ZU VIELE SONGS.",0
T_PAUSE:    DEFM "PAUSE ",0
;------------------------------------------------------
KAT0:   
        LD      HL,KAT          ;ANFANGSADRESSE KATALOG
        LD      (KATPOS),HL     ;MAX. 8 K BEI 511 SONGS

        DEC     HL              ;VORBYTE AUCH!
        LD      (HL),0          ;LÖSCHEN

        LD      DE,KAT          ;
        LD      BC,1fffh        ;1ffeh geht noch????
        LDIR 
        RET
;-------------------------------------------------
;DATEIANZAHL (RÜCK)SETZEN, ERHÖHEN, PRÜFEN
DIR0:   PUSH    HL
        LD      HL,0
        JR      DIR2
DIR1:   PUSH    HL
        LD      HL,1
DIR2:   LD      (MENGE),HL
DIR3:   LD      (DIRANZ),HL
        POP     HL
        RET
;--------------------------------------------
DIRPLUS:PUSH    HL
        LD      HL,(DIRANZ)
        INC     HL              ;ZÄHLEN
        JR      DIR3
;--------------------------------------------
ISNULL: LD      HL,(DIRANZ)     ;ANZAHL SONGS
        LD      A,H
        OR      L               ;=0?
        RET
;-----------------------------------------------
PRNAM:  LD      A,(DE)
        CP      0DH             ;OHNE 0D!
        RET     Z
        CALL    PRINT
        INC     DE
        JR      PRNAM 
;-----------------------------------------------------
SHORT:  ;Anzeigepause
        PUSH    BC
        LD      BC,08000h
SHORT1: DEC     BC
        LD      A,B
        OR      C
        JR      NZ,SHORT1
        POP     BC
        RET
;#####################################################
;USB-ROUTINEN
;#####################################################
SETPIO:;PROGRAMMIEREN USB-PIO
        LD      A,0CFH          ;PIO_B: BITBETRIEB
        OUT     (USBPIO+3),A
        LD      A,33H           ;I/O FESTLEGEN: AAEE AAEE
        OUT     (USBPIO+3),A
        LD      A,7             ;KEIN INT
        OUT     (USBPIO+3),A
        LD      A,84H           ;DATEN B = I000 0I00 = RESET
        OUT     (USBPIO+1),A
        LD      A,8FH           ;PIO_A: BIDIREKTIONAL
        OUT     (USBPIO+2),A
        LD      A,7         
        OUT     (USBPIO+2),A
        IN      A,(USBPIO)
        LD      A,0C4H
        OUT     (USBPIO+1),A
SETP_1: LD      HL,600H         ;2MHz-->200H WARTEZEIT
SETP_2: IN      A,(USBPIO+1)
        RRCA
        JR      C,SETP_3        ;FERTIG
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
        LD      A,45H           ;E SENDEN
        CALL    PUTUSB
        LD      A,0DH
        CALL    PUTUSB  
SETP_6: CALL    GETUSB  
        CP      45H             ;E EMPFANGEN?
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
        RET     Z               ;INIT FERTIG
        ;HIER WENN FEHLER!      
SETP_9: CALL    PRINT           ;ZEICHEN "ND" 
        CALL    CHECKB
        JR      NZ,SETP_9
USBERR: LD      DE,T_USBERR
        CALL    PRNST
        RST     8
        SCF                     ;FEHLERFLAG
        RET
;-----------------------------------------------
;INHALT USB ANZEIGEN/KATALOGISIEREN/ZÄHLEN(HOLEN
;KOMMT MIT(DIRFLG) = 0   -> ANZEIGE AUF SCHIRM
;                    1   -> KATALOGISIEREN
;                    2   -> NUR ZÄHLEN
;                    3   -> N-TEN DATEINAME HOLEN
;                           N IN (ASCII)
DIR:    CALL    DIR0            ;DATEIZÄHLER=0
        XOR     A
        LD      A,01H           ;DIR
        CALL    PUTUSB
        CALL    EXEC
        LD      HL,INBUFF
        LD      (HL),0FFH

DIR05:  CALL    CHECKB          ;0D=ENDE EINES NAMENS?
        JP      NZ,DIR10        ;NEIN, WEITER LESEN
        ;ENDE NAME!
        LD      (HL),0FFH 
        DEC     HL
        ;NAME VORHANDEN, ENDUNG TESTEN
        LD      DE,PT3X         ;FILTER PT3
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
        CALL    DIRPLUS         ;EINE MEHR
        LD      A,(MENGE)
        INC     A  
        LD      (MENGE),A   ;ANZAHL PRO SCHIRM
        ;GUCKEN, WELCHER MODUS-----------------
        LD      A,(DIRFLG)   
        OR      A               ;ANZEIGEN?
        JR      Z,D_ANZ         ;JA
        CP      2               ;ZÄHLEN?
        JP      Z,DIR09         ;JA
        CP      1               ;KATALOGISIEREN?
        JP      Z,D_COP         ;JA.
        ;N-TEN NAMEN HOLEN: TEST (DIRANZ)=(ASCII)
        LD      HL,(DIRANZ)     ;AKT. ANZAHL
        LD      DE,(ASCII)      ;ZUFALLSZAHL
        OR      A
        SBC     HL,DE           ;ERREICHT?
        JP      Z,REST          ;JA, REST ABHOLEN+RAUS
        JP      DIR09           ;WEITER SUCHEN
 D_ANZ: ;NORMAL AUF SCHIRM AUSGEBEN---------------------
        LD      DE,INBUFF       ;NAMENSPUFFER
        CALL    TOUT            ;AUSGABE
        ;FORMATIERT IN 4 SPALTEN
        LD      A,(CURS)        ;ADRESSE KURSORPOSITION  LOW
        AND     0F0h            ;AC1 rückwärts adressiert!
        LD      (CURS),A
        CALL    SPACE
        ;ANZAHLTEN, WENN SCHIRM VOLL
        LD      A,(MENGE)
        cp      112             ;max. pro Schirm
        JR      c,DIR09         ;< Vorgabe
        ;anhalten
        LD      DE,T_WEITER     ;ET=Blättern
        CALL    TXT1
        RST     8
        CP      '.'             ;WAR STOPP
        JR      Z,REST1         ;NOCH REST ABHOLEN 
        ;weiter auflisten
        CALL    CLS
        XOR     A
        LD      (MENGE),A
        JR      DIR09
        ;--------------------------------------------
        ;IN KATALOG KOPIEREN
D_COP:  LD      DE,(KATPOS)     ;AKT. POSI IM KATALOG
        LD      HL,INBUFF
COP:    LD      A,(HL)      
        CP      "."
        JR      Z,COP1          ;NOCH PT3+0D ANHÄNGEN
        LDI
        JR      COP
COP1:   LD      (DE),A          ;. ABLEGEN
        INC     DE
        LD      HL,PT3X
        LDI
        LDI
        LDI
        LD      A,0DH
        LD      (DE),A
        INC     DE
        LD      (KATPOS),DE     ;NEUE POS.
        ;BEGRENZUNG KATALOGGRÖßE!
        ;DE= AKT. KATALOGADRESSE
        LD      HL,MAXKAT-13    ;8000
        OR      A
        SBC     HL,DE
        JR      NC,DIR09        ;NOCH IM BEREICH
        ;ZUVIELE!
        LD      DE,T_ZUVIEL
        CALL    TXT1
        JR      REST            ;DIR-REST ABHOLEN
        ;-------------------------------------------
DIR09:  LD      HL,INBUFF       ;PUFFER NEU BEGINNEN
        XOR     A
        JR      DIR11
DIR10:  ;DATEINAME BAUEN
        LD      (HL),A
        INC     HL
DIR11:  CP      3EH             ;PROMPT = USB FERTIG?
        JP      NZ,DIR05        ;NEIN, weiter einlesen
        ;Endeprompt erreicht
DIR12:  CALL    CHECKB          ;JA, FOLGT 0D?
        JP      NZ,USBERR       ;NEIN, USBERR
        RET                     ;FERTIG!
        ;
        ;bei Abbruch Rest noch abholen:                
REST1:  ;pop AF
        LD      DE,T_MOMENT
        CALL TXT1
        
REST:   CALL    CHECKB          ;Byte holen
        CP      3EH             ;Ende DIR?
        JR      NZ,REST         ;nein
        CALL    CHECKB          ;FOLGT 0D?
        JP      NZ,USBERR       ;NEIN, USBERR
        RET
;-------------------------------------------------
USBERR3:CALL    EXWAIT1         ;WARTEN BIS USB FERTIG
USBERR4:LD      DE,T_NOTFND
        CALL    PRNST
        SCF                     ;FEHLERFLAG
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
        ;JP      Z,RESET        ;ABBRUCH/RESTART
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
        XOR    A
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
;------------------------------------------------------
_LADEUSB:   ;DATEI PER USB LADEN
;IN  NAMBUF STEHT ADRESSE DES DATEINAMENS
;IN (RAMADR) STEHT SPEICHERADRESSE, AUF DIE EINZULESEN IST
        LD      IX,NAMBUF       ;ADRESSE DATEINAME
        ;DATEIGRÖßE HOLEN (DIR MIT DATEINAME):
        LD      A,01H           ;DIR MIT FIELNAME
        CALL    SENDNAM         ;DATEINAMEN AN USB
        CALL    EXEC            ;KOMMANDOABSCHLUSS
        CALL    CHECKB          ;USB FERTIG? (0D)
        JP      NZ,USBERR3      ;NEIN=> FEHLERABBRUCH      
LESEN1: CALL    CHECKB          ;USB FERTIG? (0D)
        JP      Z,USBERR4       ;DATEI NICHT GEFUNDEN!
        ;ZEICHEN WURDE EMPFANGEN------------------------------ 
        CP      20H             ;LEERZEICHEN NACH DEM NAMEN 
        JR      NZ,LESEN1       ;SUCHEN
        ;DATEI GEFUNDEN!
        LD      B,04H           ;NÄCHSTE 4 BYTES =DATEILÄNGE
        LD      HL,MENGE        ;HIERHIN ABLEGEN
LESEN2: CALL    GETUSB          ;BYTE VON USB HOLEN
        LD      (HL),A          ;ABLEGEN
        INC     HL              ;NÄCHSTES
        DJNZ    LESEN2
        ;DATEILÄNGE IST EINGELESEN UND STEHT AB (MENGE)-------
LESEN3: CALL    CHECKB          ;USB FERTIG?
        JR      NZ,LESEN3       ;NEIN
        CALL    GETUSB          ;BYTE VON USB HOLEN
        CP      3EH             ;ENDE ERREICHT?
        JR      NZ,LESEN4       ;NEIN => FEHLERABBRUCH
        CALL    CHECKB          ;USB FERTIG?
LESEN4: JP      NZ,USBERR       ;FEHLERABBRUCH
        ;JETZT DATEI ÖFFNEN-----------------------------------
        LD      A,0EH           ;USB OPEN FOR READ
        CALL    SENDNAM         ;DATEINAMEN AN USB
        CALL    EXWAIT          ;KOMMANDOABSCHLUSS + WARTEN AUF FERTIG
        ;ZU LESENDE ANZAHL BYTES ÜBERMITTELN-----------------      
        LD      A,0BH           ;USB READ 
        CALL    PUTUSB          ;DATEN AN USB
        LD      A,20H           ;20H=> N BYTES SOLLEN GEHOLT WERDEN
        CALL    PUTUSB          ;DATEN AN USB
        ;MENGE N ALS DWORD ÜBERMITTELN:
        XOR     A               ;2 X 0 (OBERE 16 BIT)
        CALL    PUTUSB          ;DATEN AN USB
        CALL    PUTUSB          ;DATEN AN USB
        LD      BC,(MENGE)      ;DATEILÄNGE HOLEN 
        ;ES WIRD IMMER SOVIEL GELESEN, WIE DIE DATEI LANG IST
        LD      A,B             ;HWT MENGE
        CALL    PUTUSB          ;DATEN AN USB
        LD      A,C             ;NWT MENGE
        CALL    PUTUSB          ;DATEN AN USB
        CALL    EXEC            ;KOMMANDOABSCHLUSS
        ;EINLESEN DES DATEIINHALTES------------------------
        LD      HL,(RAMADR)     ;DORTHIN
        CALL    ABHOLEN         ;N BYTES VON USB HOLEN+ABLEGEN
CL1:    CALL    EXWAIT1         ;WARTEN BIS USB FERTIG
        ;DATEI SCHLIEßEN-----------------------------------
CLOSE:  LD      A,0AH           ;USB CLOSE 
        CALL    SENDNAM         ;DATEINAMEN AN USB
        JP      EXWAIT          ;KOMMANDOABSCHLUSS + WARTEN AUF FERTIG
;-------------------------------------------------
SONG:   ;AB HIER STEHT PT3-DATEI
ENDE:
