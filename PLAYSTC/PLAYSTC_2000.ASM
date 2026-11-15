;-------------------------------------------------
;USB-PLAYER AC1 FÜR STC-SONGS
;WERO '2018
;PLAYER MACHT INTENSIVE STACKARBEIT, 
;TIEFE SYSTEMSTACK REICHT NICHT, VERLAGERUNG NÖTIG!
;version:    EQU  0             ;int. CTC AC1, K0
version:    EQU  1              ;CTC auf Soundkarte
;-------------------------------------------------
;VERSION 1.3:
;Anpassung für AC1-2010 mit 4 MHz CPU-Takt (05/2022):
;* HL-Registerwert bei der VDIP-Initialisierung
;  auf 600h gesetzt
;* CTC Kanäle K0+K1 kaskadiert und Nutzung des 
;  Quarzes 3,57954 MHz für den Interrupt
;* Definition Q358=1 bei Nutzung des Quarzes auf
;  der Sound-Leiterplatte
;* Änderungen in der ISR-Routine bei der Int.-Annahme
;-------------------------------------------------
;MONITOR- UND SPEICHERBEZÜGE----------------------
MS30:   EQU     07EBH           ;UP PAUSE
INLINE: EQU     07F4H           ;UP STRING-EINGABE
GETCO:  EQU     07FDH           ;RÜCKKEHR ZUM MONITOR
BWS:    EQU     17FFh           ;Bildschirmspeicher links oben
CURS:   EQU     1800h           ;ADRESSE AKT. KURSORPOSITION
INANF:  EQU     181AH           ;ADRESSE STRINGANFANG EINGABE
          
PROGR:  EQU     2000H           ;LADEADRESSE/PROGRAMMANFANG
ABL:    EQU     6000H           ;ABLAGE DATEINAMEN FÜR SERIENABSPIEL
ABLLEN: EQU     3000H           ;max. Länge Ablagebereich
;Für Include nötig---------------------------------
;x0001: EQU     38h             ;AY-BASISADRESSE 
USBPIO: EQU      0FCH           ;USB.PIO
CTCZK:  EQU      9Ch            ;Zeitkonstante für 2 MHz

if version=0       ;Interne CTC AC1 K3
    CTCBAS: EQU    0            ;CTC-Basisadresse
    CTCCHN: EQU    0            ;Kanal
else               ;CTC auf Soundkarte, K0
    CTCBAS: EQU   3Ch           ;CTC-Basisadresse
    CTCCHN: EQU    0            ;Kanal
endif
CTCINT: EQU     PROGR+10h       ;Interrupttabelle CTC
WORK:   EQU     PROGR+18h       ;Eingebettete Arbeitszellen
;-------------------------------------------------
;Q358:         EQU  0  ;nutzt AC1-Systemtakt 2 MHz
                       ;höherer CPU-Takt führt zum
                       ;schnelleren Abspielen
Q358:          EQU  1  ;benutzt Quarz 3,57954 MHz
                       ;CTC K0+K1 sind kaskadiert
                       ;CPU-Takt ist variabel
;-------------------------------------------------
ORG     PROGR                   ;Programmanfang
        DEFB    0,9,"x",0Dh     ;Startrahmen, Kennbuchstabe a
        LD      A,HI PROGR      ;20h
        LD      I,A             ;IV-Säule verbiegen
        LD      SP,PROGR        ;Stack: < 2000
        JP      START0
;-------------------------------------------------
ORG     CTCINT                  ;8 Bytes für IV CTC
;-------------------------------------------------
ORG     WORK                    ;Raum für Arbeitszellen
        DEFS    128              
;PLAYER-BEZÜGE:
ANFANG: EQU     WORK            ;ÜBERGABE LIEDANFANG
ANZAHL: EQU     WORK+2          ;ÜBERGABE ANZAHL LIEDABSPIELE
MUSTER: EQU     WORK+0DH        ;ANZAHL  MUSTER IM SONG
POSI:   EQU     WORK+35H        ;ABGESPIELTE MUSTERANZAHL
MISCHER:EQU     WORK+3EH        ;MISCHER
LAUT_A: EQU     WORK+3FH        ;LAUTSTÄRKE KANAL A  
LAUT_B: EQU     WORK+40H        ;LAUTSTÄRKE KANAL B  
LAUT_C: EQU     WORK+41H        ;LAUTSTÄRKE KANAL C
;
RAUSCHA:EQU     WORK+48H        ;RAUSCHEN A
RAUSCHB:EQU     WORK+49H        ;B
RAUSCHC:EQU     WORK+4AH        ;C
RAUSCHK:EQU     WORK+4BH        ;KANAL-MERKER FÜR RAUSCHEN
;USB-BEZÜGE:
DIRANZ: EQU     WORK+82         ;ANZAHL BEI DIR
DIRPS:  EQU     DIRANZ+2        ;1 BYTE EINTRÄGE PRO DIR SEITE
MENGE:  EQU     DIRPS+1         ;4 BYTES LADEN /SICHERN
RAMADR: EQU     MENGE+4         ;2 BYTES
INBUFF: EQU     RAMADR+2        ;EINGABEPUFFER 13
NAMBUF: EQU     INBUFF+13       ;PUFFER DATEINAME  13 ZEICHEN
DIRFLG: EQU     NAMBUF+13       ;FLAG FÜR SERIENABSPIEL
KATPOS: EQU     DIRFLG+1        ;2 BYTES
MAXWDH: EQU     KATPOS+2        ;1 BYTE
SONGNR: EQU     MAXWDH+1        ;2 Bytes!
;-------------------------------------------------      
PLAYER:
INCLUDE  "AYPLAC1.INC"
;Bezüge:
PLAY:   EQU     PLAYER          ;Song Starten
STOPP:  EQU     PLAYER+6        ;SOUND OFF
;-------------------------------------------------
start0: ;Arbeitszellen löschen!
        LD      HL,ctcint
        ld      (HL),0
        LD      DE,ctcint+1
        LD      BC,PLAYER-ctcint-1
        LDIR

USBTEST:CALL    CLS
        RST     18H
        DEFm    "INIT USB...",8dh
        call    setp_0
        jP      c,home          ;Fehler, kein Stick dran
        call    cd_stc          ;Wechsel in Songverzeichnis
        jp      nc,start        ;ok, STC gefunden
        ;EXISTIERT NICHT
        RST     18h
        DEFM    0dh,"Erst Unterverzeichnis /STC erzeugen und Songs dort ablegen!",8dh
        jp      home                   
;-------------------------------------------------
START:  CALL    STOPP           ;EVTL. LAUFENDEN SONG BEENDEN
START1: CALL    TITEL 
        RST     18H
        DEFM    0eh,"1120(L)aden Einzelsong"
        DEFM    0eh,"1220(P)layliste spielen"
        DEFM    0eh,"1320(A)lles abspielen"
        DEFM    0eh,"1520(U)SB Stickwechsel/Init"
        DEFM    0eh,"1620(E)nde"
        DEFM    0eh,"1820Auswahl?  ",80h                 
MENU:   RST     8               ;Tastatureingabe
        or      20h
        CP      "e"             ;"0"?
        JP      Z,HOME          ;RAUS
        cp      "u"
        jp      z,usbtest
        cp      "p"
        jp      z,liste
        CP      "a"             ;alles
        jp      z,all
        CP      "l"             
        JR      NZ,MENU
;LIED LADEN+ABSPIELEN------------------
        XOR     A
        ld      (DIRFLG),A      ;Normale BS-Anzeige
        call    dir0            ;Menge=0
        LD      HL,SONG         ;Ladeadresse
        LD      (RAMADR),HL     ;dorthin! 
        RST     18H
        DEFM    0CH,"<ET>=DIR, <.>=Abbruch",80H
namein: CALL    INPNAM          ;ABFRAGE/EINGABE DATEINAME
        jr      C,anzdir        ;war nur enter
        ld      a,(nambuf)
        cp      "."             ;War abbruch?
        jp      z,start         ;ja
        ;war Name
        jr      chknam
        ;war nur enter
anzdir: CALL    DIR             ;ANZEIGE USB-INHALTSVERZEICHNIS
        CALl    ISNULL          ;Bestand?
        jp      z,FUND_0        ;keine STC gefunden
        jr      namein
;------------------------------------------
chknam: ;1. Zeichen prüfen:
        ld      a,(nambuf)
        cp      "."             ;1. Zeichen
        jp      z,unzul         ;darf kein . sein

        ld     hl,nambuf-1
pruef:  inc    HL
        LD     A,(HL)
        cp     "."              ;Trenner?
        jr     z,pok            ;ja, alles ok
        call   inr              ;prüfen
        cp     0                ;Fehler?
        jp     z,unzul          ;ja
        jr     pruef
;----------------------------------------
pok:    ;name ok
        call    _LADEUSB
        
        jp      c,START         ;nicht gefunden, Abbruch! 

        ;Songanfang übergeben------------
        LD      HL,SONG     
        LD      (ANFANG),HL     ;für Player
        ;Anzahl erfragen-----------------
        RST     18h
        DEFM    "Wievielmal spielen (1)...9 ?",0A0h
wdh:    RST     8               ;Enter, 0...9 zugelassen
        LD      B,A
        cp      0dh             ;nur Enter=0
        LD      A,1
        jr      z,F0

        LD      A,B
        cp      "1"
        jr      c,wdh
        cp      "9"+1
        jr      nc,wdh
        sub     30h

f0:     LD      (ANZAHL),A      ;WDH für Player
        CALL    dir1            ;HL=1
        LD      (SONGNR),HL     ;laufende Nr. ab 1

        CALL    PLAY            ;Abspielen starten

        call    desk            ;Playeroberfläche, n* abspielen
        ;Lied fertig, Neustart
        JP      START 

;---------------------------------------------------
showname:
        LD      HL,nambuf       ;ab hier bis 00
F1:     LD      A,(HL)
        CP      0dh             ;Ende?
        RET     z
        CALL    PRINT
        INC     HL
        JR      F1
        RET
;---------------------------------------------------
leere:  LD      B,19
leer1:  call    space
        DJNZ    leer1
        LD      A,"!"
        jp      print
;--------------------------------------------------
;Playeroberfläche
desk:   CALL    TITEL

        rst     18h
        DEFM    0eh,"0818",0ABh
        call    line
        rst     18h
        DEFM    0eh,"0918!Titel",0BAh
        call    leere
        rst     18h
        DEFM    0eh,"1018!ID   ",0BAh
        call    leere
        RST     18h
        DEFM    0eh,"1118!Tempo",0BAh
        call    leere
        rst     18h
        DEFM    0eh,"1218",0ABh
        call    LINE
        RST     18h
        DEFM    0eh,"1318!Muster",80h
        call    leere
        RST     18h
        DEFM    0eh,"1418",0ABh
        call    line
        rst     18h
        DEFM    0eh,"1518!Kan. A",80h
        call    leere
        rst     18h
        DEFM    0eh,"1618!Kan. B",80h
        call    leere
        rst     18h
        DEFM    0eh,"1718!Kan. C",80h
        call    leere
        rst     18h
        DEFM    0eh,"1818",0ABh
        call    line
        rst     18h
        DEFM    0eh,"1918!Song ",0BAh
        call    leere
        rst     18h
        DEFM    0eh,"2018",0ABh
        call    line
        rst     18h
        DEFM    0eh,"2118!<X>=Stopp     <ET>=Weiter!"
        DEFM    0eh,"2218",0ABh
        call    line
        ;Songname anzeigen-------------------
        LD      HL,BWS-09*64+26
        LD      (CURS),HL
        call    showname

        ;ID-Kennung anzeigen-----------------
        LD      HL,BWS-10*64+26
        LD      (CURS),HL
        ;Wenn "nichtstandardmäßiger" Inhalt:
        ;Ersatz durch Leerzeichen!
        LD      HL,SONG+7       ;Textanfang
        LD      B,18            ;Länge immer 18 Zeichen
F21:    LD      C," "           ;Ersatzzeichen
        LD      a,(HL)
        cp      C
        jr      c,F22           ;<' ' ->Ersatz
        cp      7Eh
        JR      nc,F22          ;>7Eh ->Ersatz
        LD      C,A             ;normales Zeichen
F22:    LD      A,C
        Call    PRINT
        INC     HL
        DJNZ    f21

        ;Tempo anzeigen---------------------
        LD      HL,BWS-11*64+26
        LD      (CURS),HL
        LD      A,(SONG)        ;TEMPOWERT 01...0F
        CALL    DEZ_A

        ;
        ;HALT                   ;warten auf INT
LOOP:   ;Playerschleife---------------------------
        LD      HL,BWS-19*64+26
        LD      (CURS),HL
        ld      DE,(Songnr)     ;Wdh.
        CALL    DEZ_4           ;Dezimal 4stellig
                                
        RST     18h
        DEFM    " von",0A0h
        LD      DE,(DIRANZ)     ;
        CALL    DEZ_4           ;Dezimalausgabe 4stell
        
        RST     18h
        DEFM    " ",0A8h
        LD      A,(ANZAHL)      ;1...9
        add     A,30h
        call    PRINT
        rst     18h
        DEFM    "x",0A9H

        LD      HL,BWS-13*64+26
        LD      (CURS),HL 

        ld      a,(POSI)        ;akt Muster
        CALL    DEZ_A           ;Dezimalausgabe
        RST     18h
        DEFM    " von",0A0h
        LD      A,(MUSTER)      ;ANZAHL MUSTER
        CALL    DEZ_A           ;DEZIMALAUSGABE

        ;PEGEL+RAUSCHANZEIGE
        ;RAUSCHFREIGABE: MISCHER XXRRRTTT
        XOR     A
        LD      (RAUSCHA),A
        LD      (RAUSCHB),A
        LD      (RAUSCHC),A
        LD      (RAUSCHK),A

        LD      HL,MISCHER
        BIT     3,(HL)          ;RAUSCHBIT=0?
        JR      NZ,RA           ;NEIN
        LD      A,(LAUT_A)      ;RECHTS
        LD      (RAUSCHA),A     ;JA- > PEGEL
RA:     BIT     4,(HL)
        JR      NZ,RB
        LD      A,(LAUT_B)      ;MITTE
        LD      (RAUSCHB),A
RB:     BIT     5,(HL)
        JR      NZ,RC
        LD      A,(LAUT_C)      ;LINKS
        LD      (RAUSCHC),A
RC:     LD      HL,BWS-15*64+26
        LD      (CURS),HL 
        LD      A,1
        LD      (RAUSCHK),A     ;KANAL A RAUSCH
        LD      A,(LAUT_A)
        CALL    PEGEL

        LD      HL,BWS-16*64+26
        LD      (CURS),HL         
        LD      A,2
        LD      (RAUSCHK),A     ;KANAL B
        LD      A,(LAUT_B)
        CALL    PEGEL


        LD      HL,BWS-17*64+26
        LD      (CURS),HL 
        LD      A,3
        LD      (RAUSCHK),A     ;KANAL C
        LD      A,(LAUT_C)
        CALL    PEGEL
        ;ABBRUCHTASTE?----------------------------
        CALL    TASTE
        CP      'X'
        RET     Z
        CP      0DH
        RET     Z
        LD      A,(ANZAHL)      
        ;WIEDERHOLUNGEN, WIRD VOM PLAYER RUNTERGEZÄHLT!
        OR      A               ;FERTIG?
        JP      NZ,LOOP
        RET
;--------------------------------------------------
;PLAYLISTE ABARBEITEN
LISTE:  ;LISTE IN KATALOGBREICH LADEN:
        CALL    ABL_CLEAR
        LD      HL,ABL          ;KATALOG
        LD      (RAMADR),HL     ;ALS LADEADRESSE
        LD      HL,BATCH        ;NAME DER PLAYLISTE
        LD      DE,NAMBUF
        LD      BC,13
        LDIR
        RST     18h
        DEFM    0ch,"PLAYLIST",0C5h
        CALL    _LADEUSB        ;CARRY, WENN FEHLER
        JP      C,START1        ;PLAYLISTE NICHT GEFUNDEN
;-------------------------------------------
BAT0:   ;DATEIEN IM BATCHFILE (KATALOG) ZÄHLEN
        LD      HL,1            ;SONG-NR AUF 1 SETZEN
        LD      (SONGNR),HL
        CALL    DIR0            ;ANZAHL=0
        LD      HL,ABL          ;ANFANG KATALOG
BAT1:   LD      A,(HL)
        OR      A               ;ENDE?
        JP      Z,SERIE         ;FERTIG
        CP      0DH
        CALL    Z,DIRPLUS       ;1 DATEI MEHR
        INC     HL
        JR      BAT1
;----------------------------------------
DIRPLUS:PUSH    HL
        LD      HL,(DIRANZ)
        INC     HL              ;ZÄHLEN
        LD      (DIRANZ),HL
        push    hl
        RST     18H
        DEFM    0EH,"0100Songs:",0A0H
        pop     de
        CALL    DEZ_4
        POP     HL
        RET
;----------------------------------------
ABL_CLEAR: ;NAMENSABLAGE LÖSCHEN:
        LD      HL,ABL          ;AB 6000
        LD      (HL),0
        LD      DE,ABL+1
        LD      BC,ABLLEN       ;BIS 9000
        LDIR
        RET
;----------------------------------------
ALL:    ;ALLE SONGS KATALOGISIEREN UND ABSPIELEN
        ;CALL    MOMENT
        rst      18h
        DEFM     0ch,"ALLES SPIELE",0CEH
        LD      A,1
        LD      (DIRFLG),A
        LD      (SONGNR),A      ;LAUFENDE NR.
        CALL    ABL_CLEAR
        LD      HL,ABL          ;ABFANG ABLAGE C800
        LD      (KATPOS),HL
        CALL    DIR             ;EINLESEN/ZÄHLEN
SERIE:  CALL    ISNULL
        JR      NZ,GEFUNDEN     ;BESTAND!
FUND_0: RST     18H
        DEFM    0DH,"Keine STC-Songs unter 'STC' gefunden!",8DH
        CALL    PAUSE2
        JP      START
;------------------------------------------
GEFUNDEN:;KATALOG MIT STC-DATEINAMEN VORHANDEN
        ;JETZT AB C800 JEDEN DATEINAMEN HOLEN
        CALL    PAUSE1
        CALL    CLS
        LD      HL,ABL  ;ANFANG
        LD     (KATPOS),HL      ;1. DATEINAME
ALL0:   ;SCHLEIFE-------------------------------
        ;KOPIEREN NACH NAMBUF=DATEINAME, 0D-TERMINIERT
        LD     DE,nambuf
all1:   LD     A,(HL)
        or     A                ;Letzter Name?
        jp     z,start          ;ja, Menü
        cp     0ah              ;bei Playliste überlesen
        jr     z,all11
        cp     0dh              ;Name zuende?
        jr     z,all2
        LDI
        JR     all1

all11:  inc    HL
        JR     all1
all2:   ld     (de),a           ;0d noch übernehmen
        ;Dateiname ist in nambuf, laden+abspielen
        push   hl
        push   de
        RST    18h
        defm   0ch,"Lade:",0A0h
        ;Dateinamen anzeigen
        call    showname
        LD      HL,SONG         ;Ladeadresse
        LD      (RAMADR),HL     ;dorthin! 
        call    _LADEUSB        ;carry, wenn "DAtei nicht gefunden"
        jr      c,fehler

        ;Songanfang übergeben------------
        LD      HL,SONG     
        LD      (ANFANG),HL
        LD      A,1
        LD      (ANZAHL),A      ;1x
          
        CALL    PLAY            ;Song starten
        CALL    DESK            ;Oberfläche
        ;HIER WEITER, WENN 'X' oder ENTER ODER LIED-ENDE
        cp      "X"             ;war Abbruch
        jr      z,fehler
        LD      hl,SONGNR       ;laufende Nr.
        INC     (HL)
        ;überspringen?
        cp      0dh
        jr      z,over          ;Lied fertig/abgebrochen
        ;Pause vor nächstem Titel
        CALL    CLS
        RST     18h
        DEFM    0eh,"1628PAUSE..",8Eh
        call    pause2
over:   call    stopp
        pop     de
        pop     hl
        inc     HL
        LD      (KATPOS),HL     ;Anfang nächster Name
        jr      all0
;----------------------------------------------
fehler: pop     de              ;Stack

korri:  pop     hl              ;korrigieren
        jp      start           ;Neustart
;----------------------------------------
pause1: ld      b,32            ;ca 1 Sek.
        jr      warte2
pause2: ld      b,67            ;ca. 2 sek.
warte2: call    MS30
        djnz    warte2
        ret 
;----------------------------------------
;Dateianzahl (rück)setzen
dir0:   LD      HL,0
        JR      DIR2
dir1:   LD      HL,1
dir2:   LD      (DIRANZ),HL
        RET
;----------------------------------------
;Dezimalanzeige
DEZ_A:  ;Ausgabewert in A, 000...0255
        LD      L,A
        LD      H,0
DEZ_DE: ;Ausgabewert in DE, 000...999
        ex      de,hl
        ld      c,30h
        jr      DEZ_3
DEZ_4:  ;Ausgabewert in DE, 0000...9999
        LD      C,30H           ;"0"
        LD      HL,#03E7        ;999
        AND     A
        SBC     HL,DE
        JP      C,mD660
        LD      A,C
        CALL    print           ;ausgeben auf Schirm
DEZ_3:  LD      HL,0063h        ;99
        AND     A
        SBC     HL,DE
        JP      C,mD660
        LD      A,C
        CALL    print           ;ausgeben auf Schirm
mD653:  LD      HL,0009H        ;9
        AND     A
        SBC     HL,DE
        JP      C,mD660
        LD      A,C
        CALL    print           ;ausgeben auf Schirm
mD660:  EX      DE,HL
mD661:  LD      DE,000AH
        CALL    mD676
        LD      A,L
        LD      H,B
        LD      L,C
        PUSH    AF
        LD      A,L
        OR      H
        CALL    NZ,mD661
        POP     AF
        ADD     A,30h            ;Ziffer
        JP      print            ;ausgeben auf Schirm
mD676:  LD      B,L
        LD      L,H
        LD      H,0
        CALL    mD680
        LD      H,L
        LD      L,B
        LD      B,C
mD680:  LD      C,0FFh
mD682:  AND     A
        SBC     HL,DE
        INC     C
        JP      NC,mD682
        ADD     HL,DE
        RET          
 ;---------------------------------------        
HOME:   CALL    STOPP           ;Player aus
        call    cd_root         ;Wechsel zurück in ROOT
home1:  LD      A,02h           ;Standard
        LD      I,A             ;Interruptsäule      
        EI
        CALL    NEWL 
        ;;ZURÜCK ZUM LLC2 +originaler Stack
        jp      GETCO            ;setzt Standard SP=1856h
;-------------------------------------------------
PEGEL:  ;BALKENANZEIGE, KOMMT MIT WERT IN A, MAX. 15
        ;ES WIRD EINEN ANZAHL VON Symbolen GEZEICHNET, 
        ;DIE DEM WERT IN A ENTSPRICHT.
        ;DER REST BIS ZUR MAX. LÄNGE WIRD MIT LEERZEICHEN ÜBERSCHRIEBEN
        OR      A               ;0?
        LD      D,"*"           ;Symbol Balkenzeichen normal
        LD      C,16            ;MAX.
        JR      Z,P2            ;NUR 16X LEER!
        CP      16              ;Hüllkurve?
        JR      C,P0            ;<16        -> NORMAL
                                ;WAR >=16   -> HÜLLKURVE AKTIV
        LD      A,16            ;max. anzeigen
        LD      D,":"           ;Symbol Hüllkurve
P0:     LD      B,A             ;ANZAHL 
        LD      A,16            ;MAX.
        SUB     B               ;REST
        LD      C,A             ;ANZAHL LEERE MERKEN
        LD      A,D             ;Symbol
P1:     CALL    PRINT           ;AUSGEBEN
        DJNZ    P1
        ;ALTEN RESTBALKEN LÖSCHEN
P2:     LD      B,C
        XOR     A
        CP      B
        RET     Z
P3:     CALL    SPACE           ;AUSGEBEN
        DJNZ    P3
        ;call    space
        ;RAUSCHEN
        LD      HL,RAUSCHA      ;Rausch A
        LD      A,(RAUSCHK)     ;welcher Kanal?
        cp      1               ;A?
        JR      Z,P4            ;ja
        INC     HL              ;Rausch B
        cp      2               ;B?
        JR      Z,P4            ;ja
        INC     HL              ;Rausch C
P4:     LD      A,(HL)          ;Pegel
        OR      A               ; 
        JR      Z,P5            ;Pegel=0 oder Rauschen gesperrt!
        LD      A,"+"
        JR      P6
P5:     LD      A," "
P6:     CALl    PRINT
        RET
;******************************************************
;USB-Routinen
;******************************************************
SETP_0:;Programmieren USB-PIO
        ;PIO+USB-Init erfolgt nur beim ersten USB-Zugriff
        LD      A,0CFh          ;PIO_B: BITBETRIEB
        OUT     (USBPIO+3),A
        LD      A,33h           ;I/O FESTLEGEN: AAEE AAEE
        OUT     (USBPIO+3),A    
        LD      A,7             ;KEIN INT
        OUT     (USBPIO+3),A
        LD      A,84h           ;DATEN B = I000 0I00 = RESET
        OUT     (USBPIO+1),A
        ;gucken, ob USB-PIO vorhanden
         AND     0CCh           ;84
         LD      B,A            
         IN      A,(USBPIO+1)   ;ZURÜCKLESEN
         AND     0CCh           ;XX00 XX00
         CP      B              ;war 84, PIO VORH.
         JP      nZ,nopio       ;ungleich, keine PIO

        LD      A,8Fh           ;PIO_A: BIDIREKTIONAL
        OUT     (USBPIO+2),A
        LD      A,7             
        OUT     (USBPIO+2),A
        IN      A,(USBPIO)
        LD      A,0C4h
        OUT     (USBPIO+1),A
SETP_1: LD      HL,600H         ;2MHz-->200H WARTEZEIT
SETP_2: IN      A,(USBPIO+1)
        RRCA
        JR      C,SETP_3        ;fertig
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
        AND     03h
        CP      01h
        JR      NZ,SETP_1
        LD      A,0Dh
        CALL    PUTUSB
SETP_5: CALL    CHECKB
        JR      NZ,SETP_5
        LD      A,45h           ;E senden
        CALL    PUTUSB
        LD      A,0Dh
        CALL    PUTUSB  
SETP_6: CALL    GETUSB  
        CP      45h             ;E empfangen?
        JR      NZ,SETP_6
        CALL    CHECKB
                
        JR      NZ,SETP_6
        LD      A,10h
        CALL    PUTUSB  
        CALL    SETP_7
        LD      A,91h
        CALL    PUTUSB  
        CALL    SETP_7
SETP_7: LD      A,0Dh
        CALL    PUTUSB
        CALL    GETUSB  
        CP      3Eh
SETP_8: JR      NZ,SETP_9
        CALL    CHECKB
        RET     Z               ;INIT fertig
        ;hier wenn Fehler!
SETP_9: RST     10h             ;Zeichen in A an Schirm  (ND...)
        CALL    CHECKB
        JR      NZ,SETP_9
        ;POP     HL
        ;CALL    SETPIO         ;INIT PIO wiederholen
USBERR: rst     18H
        DEFM    " USB-Fehler..",8Eh
errx:   scf                     ;Fehlerflag
        ret
;------------------------------------------------------
NOPIO:  rst     18h
        DEFM    0dh,"Kein USB-Adapter.",8dh
        jp      home1      ;getco
;------------------------------------------------------
EXWAIT: CALL    EXEC            ;KOMMANDOABSCHLUSS
EXWAIT1:CALL    GETUSB          ;BYTE VON USB HOLEN
        CP      3EH             ;">" = FERTIGMELDUNG?
        JR      NZ,EXWAIT2      ;NEIN
        CALL    CHECKB          ;USB FERTIG?
        RET     Z               ;JA
        JR      USBERR          ;USB-Fehler
EXWAIT2:CALL    CHECKB          ;WEITER AUF FERTIG PRÜFEN
        JR      NZ,EXWAIT2      ;NEIN, WARTEN!
        RET 
;------------------------------------------------------
EXEC:   LD      A,0DH           ;KOMMANDOABSCHLUSS
PUTUSB: ;USB (UP PUT Daten zum VDIP senden)
        OUT     (USBPIO),A      ;Byte ausgeben
        PUSH    AF
PUT1:   IN      A,(USBPIO+1)
        RRCA
        RRCA
        JR      C,PUT1  
        LD      A,0CCh
        OUT     (USBPIO+1),A
        LD      A,0C4h
        OUT     (USBPIO+1),A
        POP     AF
        RET
;--------------------------------------------------
GETUSB: ;USB (UP GET Daten vom VDIP holen)
        PUSH    BC
        LD      BC,0FFFFh
GET1:   ;IN      A,(TASPIO)     ;Tastaturport
        ;CP      83h
        ;JP      Z,korri        ;Abbruch/Restart
        IN      A,(USBPIO+1)
        RRCA
        JR      NC,GET2
        DEC     BC
        LD      A,B
        OR      C
        JR      Z,SETP_8
        JR      GET1
GET2:   LD      A,0C0h
        OUT     (USBPIO+1),A
        IN      A,(USBPIO)
        LD      C,A
        LD      A,0C4h
        OUT     (USBPIO+1),A
        LD      A,C
        POP     BC
        RET        
;--------------------------------------------------
;INHALT USB ANZEIGEN/KATALOGISIEREN
DIR:    XOR     A
        LD      (DIRPS),A       ;EINTRÄGE PRO SEITE
        CALL    DIR0            ;DATEIZÄHLER
        LD      A,01H           ;DIR
        CALL    PUTUSB          ;FUNKTION
        CALL    EXEC            ;SENDEN
        LD      HL,INBUFF
        LD      (HL),0FFH
DIR_02: CALL    CHECKB          ;0D=ENDE EINES NAMENS?
        JP      NZ,DIR_10       ;NEIN, WEITER LESEN
        ;ENDE NAME!
        LD      (HL),0FFH 
        DEC     HL
        ;NAME VORHANDEN, ENDUNG TESTEN
        LD      DE,STCX         ;FILTER STC
        INC     DE
        INC     DE
        LD      A,(DE)
        CP      (HL)
        JP      NZ,DIR_09
        DEC     HL
        DEC     DE
        LD      A,(DE)
        CP      (HL)
        JP      NZ,DIR_09
        DEC     HL
        DEC     DE
        LD      A,(DE)
        CP      (HL)
        JP      NZ,DIR_09
        ;JA: NAME ERFÜLLT BEDINGUNG
        LD      A,(DIRFLG)      ;WELCHE FUNKTION?
        OR      A
        JR      NZ,DIR_06       ;KATALOG!
        ;TABULIERT AUF SCHIRM AUSGEBEN------------
        LD      HL,(DIRANZ)
        INC     HL              ;ZÄHLEN
        LD      (DIRANZ),HL

        LD      HL,INBUFF       ;NAMENSPUFFER
        CALL    TXTOUT          ;AUSGABE
        LD      A,(CURS)        ;ADRESSE KURSORPOSITION  LOW
        AND      0F0h           ;AC1 rückwärts adressiert!
        LD      (CURS),A
        CALL    SPACE

        
        PUSH    AF
        LD      HL,DIRPS        ;Anzahl pro Seite erhöhen
        INC     (HL)
        LD      A,(HL)
        CP      112             ;MAX. EINTRÄGE PRO SEITE, DANN STOPP
        JR      NZ,DIR_05
        LD      (HL),0          ;WIEDER AB 0
        RST     18H
        DEFM    0DH,"<ET>=weiter, <.>=Abbruc",0E8H
        RST     8H              ;Tastaturabfrage
        CP      0DH             ;ENTER?
        JR      NZ,DIR_03       ;NEIN
        CALL    NEWL            ;JA 
        JR      DIR_05          ;WEITER MIT DIR
DIR_03: CP      "."             ;ABBRUCH?
        JR      NZ,DIR_05       ;NEIN, WEITER MIT DIR
        ;REST VON DIR NOCH ABHOLEN!
        RST     18H         
        DEFM    " Moment...",8DH
DIR_04: CALL    CHECKB          ;0D=ENDE EINES NAMENS?
        CP      3EH
        JR      NZ,DIR_04
        CALL    CHECKB          ;FOLGT
        CP      0DH             ;0DH?   
        JP      NZ,USBERR       ;NEIN, USBERR
        POP     AF
        RET
DIR_05: POP       AF
        JR      DIR_09
        ;IN KATALOG KOPIEREN----------------------
DIR_06: LD      DE,(KATPOS)     ;AKT. POSI IM KATALOG
        LD      HL,INBUFF
        ;EINLESEN NAME BIS ".", STC ERGÄNZEN!
DIR_07: LD      A,(HL)
        CP      "."
        JR      Z,DIR_08        ;NOCH STC+0D ANHÄNGEN
        LDI
        JR      DIR_07
DIR_08: LD      (DE),A          ;. ABLEGEN
        INC     DE
        LD      HL,STCX
        LDI
        LDI
        LDI
        LD      A,0DH
        LD      (DE),A
        INC     DE
        LD      (KATPOS),DE     ;NEUE POS.
        CALL    DIRPLUS         ;ZÄHLEN+Anzeigen
        ;BEGRENZUNG KATALOGGRÖßE!
        LD     HL,KATPOS
        LD     E,(HL)
        INC    HL
        LD     D,(HL)           ;DE=LETZTE RAM-POSI
        LD     HL,09000H        ;MAX
        OR     A
        SBC    HL,DE
        ADD    HL,DE
        JR     NC,DIR_09
        ;ZUVIELE!
        RST     18H
        DEFM    0DH,"Zu viele Songs, nicht alle werden gespielt!",0A0H
        ;DIR-REST ABHOLEN
        PUSH    AF
        JP      DIR_04          ;REST
DIR_09: LD      HL,INBUFF       ;PUFFER NEU BEGINNEN
        JR      DIR_11
DIR_10: ;DATEINAME BAUEN
        LD      (HL),A
        INC     HL
DIR_11: CP      3EH             ;PROMPT = USB FERTIG?
        JP      NZ,DIR_02       ;NEIN
        CALL    CHECKB          ;JA, FOLGT 0D?
        JP      NZ,USBERR       ;NEIN, USBERR
        RET                     ;FERTIG!
;------------------------------------------------------
USBERR4:RST     18H
        DEFM    0dh,"Datei nicht gefunden" ,0A1h
        RST     8
        scf                     ;fehlerflag
        RET
;------------------------------------------------------
;USB-VERZEICHNISWECHSEL
;VERZEICHNISWECHSEL
CD_ROOT:LD      HL,ROOT
        JR      CD_X
CD_STC: LD      HL,STCX
CD_X:   CALL    USB_CD 
        RET
;-------------------------------------------------
;KOMMT MIT HL=ZEIGER AUF STRINGANFANG (ENDE=0DH)
USB_CD: PUSH    HL
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
        SCF
        CCF                     ;CARRY=0
        LD      HL,INBUFF
        LD      A,"C"
        CP      (HL)
        RET     NZ
        INC     HL
        LD      A,"F"
        CP      (HL)
        RET     NZ
        SCF         ;FEHLERFLAG =1
        RET
;-----------------------------------------------
;DATEINAME AN USB SENDEN:
;KOMMT MIT KOMMANDOBYTE IN A (Z.B. 0BH=> ÖFFNEN)
;IN IX STEHT ADRESSE DATEINAME
SENDNAM:PUSH    IX              ;merken
        CALL    PUTUSB          ;DATEN AN USB (KOMMANDO)
        ;ERST LEERZEICHEN VOR DER ÜBERMITTLUNG DES DATEINAMENS:
        LD      A,20H           ;
        CALL    PUTUSB          ;DATEN AN USB
        ;DANN DATEINAME SELBST:
        LD      B,0CH           ;max. 12X (8.3 !!!)
S2:     LD      A,(IX+00H)      ;ZEICHEN AUS DATEINAME
        INC     IX
        CP      0DH             ;NAMENS-ABSCHLUSS ERREICHT?
        JR      Z,S3            ;JA  => FERTIG!
        CP      21H             ;NEIN=> ZEICHEN GÜLTIG? (>21H)
        CALL    NC,PUTUSB       ;JA  => DATEN AN USB
        DJNZ    S2              ;NÄCHSTES ZEICHEN
S3:     POP     IX
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
_LadeUSB:       ;LESEN
;in  NAMBUF steht Adresse des Dateinamens
;in (RAMADR) steht Speicheradresse, auf die einzulesen ist
        LD      IX,nambuf       ;ADRESSE DATEINAME

        ;DATEIGRÖßE HOLEN (DIR MIT DATEINAME):
        LD      A,01H           ;DIR MIT FIELNAME
        CALL    SENDNAM         ;DATEINAMEN AN USB
        CALL    EXEC            ;KOMMANDOABSCHLUSS
        CALL    CHECKB          ;USB FERTIG? (0D)
        JP      NZ,USBERR       ;NEIN=> FEHLERABBRUCH      
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
        ;HIER DATEILÄNGE TESTEN-------------------------------
        LD      HL,MENGE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)          ;DE=GRÖSSE
        LD      HL,ABLLEN       ;max. 6000-9000 für Katalog!
        or      a               ;bzw. Playlistendatei
        sbc     hl,de
        add     hl,de
        jp      c,ZULANG
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
        XOR     A               ;2 X 0 (obere 16 Bit)
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
        LD      HL,(RAMADR)     ;dorthin
        CALL    ABHOLEN         ;n BYTES VON USB HOLEN+ABLEGEN

        CALL    EXWAIT1         ;WARTEN BIS USB FERTIG
        ;DATEI SCHLIEßEN-----------------------------------
CLOSE:  LD      A,0AH           ;USB CLOSE 
        CALL    SENDNAM         ;DATEINAMEN AN USB
        CALL    EXWAIT          ;KOMMANDOABSCHLUSS + WARTEN AUF FERTIG
        RET
;---------------------------------------------------
ZULANG:;DATEILÄNGE >2800H   MAX. 2C00=11K
        RST     18H
        DEFM    0DH,"Datei zu lang:",0A0H
        ;KONTROLLANZEIGE
KONTR:  LD      HL,NAMBUF-1
ZUL1:   INC     HL
        LD      A,(HL)
        CALL    PRINT
        CP      0DH
        JR      NZ,ZUL1
        RST     8
        SCF     ;FEHLERFLAG
        RET
;--------------------------------------------------  
;TEXT AUSGEBEN BIS FF
TXTOUT: LD      A,(HL)          ;ZEICHEN HOLEN
        CP      0FFH            ;ENDE ERREICHT?
        RET     Z               ;JA
        CALL    PRINT           ;AUSGEBEN AUF SCHIRM
        INC     HL
        JP      TXTOUT          ;NÄCHSTES
;-------------------------------------------------           
TASTE:  CALL    07FAh
        AND     A,7FH
        RET
;-------------------------------------------------
;NAMENSABFRAGE
;DATEINAME LIEGT DANN ALS "1234.xyz" 
;AB ADRESSE INBUFF,ENDEMARKIERUNG 0D
;WENN FEHLER/ABBRUCH, DANN IST CY GESETZT
;-------------------------------------------------
INPNAM: ld      hl,STCX         ;TYP
        RST     18H        
        DEFM    0dh,"Name:",0A0h
        call    INLINE          ;INLINE
        ld      hl,(INANF)      ;HL= Adresse 1. Eingabezeichen
        LD      A,(HL)          ;1.Zeichen
        cp      " "             ;Leer?
        jP      nz,IP0          ;nein              
        ;keine Eingabe (nur ENTER)
        CALl   NEWL
        scf
        RET
;-------Puffer Dateiname leeren:
IP0:    LD      DE,nambuf       
        LD      B,11
        XOR     a               
IP1:    LD      (DE),A   
        INC     DE
        DJNZ    IP1          
        
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
        LD      HL,STCX   
        LDI                     
        LDI                     ;ENDUNG
        LDI                     ;ANHÄNGEN
        LDI                     ;0D
        RET
;---------------------------------------------------
;Prüft Dateiname auf zulässiges Zeichen (in A)
;Rückgabe A=0, wenn unzulässig
INR:        PUSH    HL
            PUSH    BC
            LD      HL,RANGE
            LD      B,78        ;Menge zulässiger Zeichen
INR1:       CP      (HL)
            JR      Z,INR2      ;ist enthalten!
            INC     HL          ;nächstes
            DJNZ    INR1        ;prüfen
            ;alles geprüft, nicht enthalten
            XOR     A           ;Rückgabewert bei Fehler
INR2:       POP     BC
            POP     HL
            RET
RANGE:      DEFM    "1234567890"
            DEFM    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            DEFM    "abcdefghijklmnopqrstuvwxyz"
            DEFM    "$%-@!()#&",27H,5Eh,5Fh,60H,7BH,7Dh,7EH 
;----------------------------------------------------
unzul:  RST    18h
        DEFM   "Eingabe unzulaessig!",80h
        pop    hl
        call   pause1
        jp     start1
;----------------------------------------------------
ISNULL: ld      hl,(diranz)     ;Anzahl Songs
        ld      a,h
        or      l
        RET
;----------------------------------------------------
TITEL:  RST     18h
        DEFB    0Ch
        DEFM    0eh,"0518",0ABh
        call    line
        rst     18h
        DEFM    0eh,"0618!STC-USB-PLAYER   AC1-2010!"
        DEFM    0eh,"0718!Vers.1.3 (c) WeRo 01/2018!"
        DEFM    0eh,"0818",0ABh
        call    line
        RET
;---------------------------------------------------
line:   LD      B,25
        LD      A,"-"
line1:  CALL    PRINT
        DJNZ    line1
        LD      A,"+"
        JR      PRINT
;---------------------------------------------------
CLS:    LD      A,0Ch           ;Löschen alles
        Jr      PRINT
SPACE:  LD      A," "
        JR      PRINT
NEWL:   LD      A,0Dh
PRINT:  JP      10h
;----------------------------------------------------
STCX:   DEFM    "STC",0DH,0 
ROOT:   DEFM    "/",0DH,0
BATCH:  DEFM    "!PLAYLST.TXT",0Dh,0
;----------------------------------------------------
org     3000h
SONG:   ;HIERHIN WERDEN SONGS GELADEN
