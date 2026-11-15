;DEMO-BETRIEB DER K1520-SOUNDKARTE AM AC1
;BENUTZT AYPLAC1.INC
;WeRo, 1/2018
;Assembler: ASIde
;version:    EQU  0             ;int. CTC AC1, K0
version:    EQU  1              ;CTC auf Soundkarte
;-------------------------------------------------
;VERSION 1.3:
;Anpassung für AC1-2010 mit 4 MHz CPU-Takt (05/2022):
;* CTC Kanäle K0+K1 kaskadiert und Nutzung des 
;  Quarzes 3,57954 MHz für den Interrupt
;* Definition Q358=1 bei Nutzung des Quarzes auf
;  der Sound-Leiterplatte
;* Änderungen in der ISR-Routine bei der Int.-Annahme
;-------------------------------------------------
;AC1-Monitor spezifisch--------------------------
BWS:    EQU     17FFh           ;links oben, rückwärts
CURS:   EQU     1800h                  
;-------------------------------------------------
;IN INCLUDE FESTGELEGT:
;X0001: EQU     38h             ;AY-BASISADRESSE 
;------------------------------------------------
;Für Include nötig:
if version=0
   CTCBAS: EQU     0            ;CTC-Basisadresse
   CTCCHN: EQU     0            ;Kanal
else
   CTCBAS: EQU     3Ch          ;CTC-Basisadresse
   CTCCHN: EQU     0            ;Kanal
endif
ZKCTC:  EQU     9Ch             ;Zeitkonstante für 2 MHz
PROGR:  EQU     2000h
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
        DEFB    0,9,"a",0Dh     ;Startrahmen, Kennbuchstabe a
        LD      A,HI PROGR      ;20h
        LD      I,A             ;IV-Säule verbiegen
        LD      SP,PROGR        ;Stack: < 2000
        JP      START
;-------------------------------------------------
ORG     CTCINT                  ;8 Bytes für IV CTC
;-------------------------------------------------
ORG     WORK                    ;Raum für Arbeitszellen
        DEFS    72              
;BEZÜGE:
;WORK:                          ;Übergabe Lied-/Geräuschanfang
;WORK+2                         ;Übergabe Anzahl Liedabspiele
;-------------------------------------------------      
PLAYER:
INCLUDE  "AYPLAC1.INC"
PLAY:   EQU     PLAYER          ;Song Starten
TON:    EQU     PLAYER+3        ;GERÄUSCH LADEN+ABSPIELEN
STOPP:  EQU     PLAYER+6        ;SOUND OFF
;-------------------------------------------------
START:  RST 18H                 ;Text ausgeben
        DEFM    0Ch,0dh,0dh
        DEFM    "Demo: K1520-Soundkarte am AC1 - WeRo 1/2018",0Dh
        DEFM    "-------------------------------------------",0dh
if version=0
        DEFM    "AC1-Int. CTC Kanal 0",0dh,0dh
else
        DEFM    "CTC auf Soundkarte K0+K1",0dh,0dh
endif
        DEFM    '   A = Ping Kanal A',0Dh
        DEFM    '   B = Ping Kanal B',0dh
        DEFM    '   C = Ping Kanal C',0dh
        DEFM    '   D = Dampfer',0Dh
        DEFM    '   H = Hubschrauber',0Dh,0dh
        DEFM    '   S = STC-Song',0Dh,0dh
        DEFM    'Leer = STOPP',0Dh,0dh
        DEFM    '   0 = Demo beenden',0Dh,0dh,0dh
        DEFM    'Auswahl?  ',80h
        
m0:     call    clear
        
MENU:   ld      a,(work+2)      ;Fertig?
        cp      0FFh            ;noch nicht gestartet
        jr      z,eing
               
        cp      0               ;fertig?
        jr      z,m0            ;ja

        ld      hl,BWS-12*64+22        
        ld      (curs),HL
        call    7eeh            ;Anzeigen
                
eing:   CALL    7fah            ;Eingabe 
        and     7Fh
        push    af
        CP      #20             ;LEERTASTE?
        CALL    Z,AUS           ;=> STOPP SOUND
        pop     af
        CP      "0"             ;"0"?
        JR      Z,HOME          ;RAUS
        CP      "A"
        LD      HL,KANA         ;Kanal A
        JR      Z,LOAD
        CP      "B"
        LD      HL,KANB         ;Kanal B
        JR      Z,LOAD
        CP      "C"
        LD      HL,KANC         ;KAnal C
        JR      Z,LOAD
        CP      'D'
        LD      HL,DAMPF        ;ANFANGSADRESSE KLANG
        JR      Z,LOAD          ;LADEN&ABSPIELEN
        CP      'H'
        LD      HL,HUBI
        JR      Z,LOAD
        CP      "S"             
        JR      NZ,MENU
;LIED LADEN+ABSPIELEN------------------
LIED:   LD      A,3             ;Anzahl
        LD      (WORK+2),A 
        ld      hl,BWS-12*64+16        
        ld      (curs),HL
        rst     18h
        defm     "loop: ",80h
        LD      HL,SONG         ;SONGANFANG
        LD      (WORK),HL       ;ablegen 
        CALL    PLAY
        XOR     A
        JR      MENU
;---------------------------------------
AUS:   call     stopp
;---------------------------------------
clear:  ld      hl,BWS-12*64+16 
        Ld      (curs),HL
        ld      a,3             ;Loop löschen
        rst     10h

        ld      a,0FFh
        LD      (work+2),A
        RET
;---------------------------------------
;Ton/Geräusch abspielen:
LOAD:   ;Kommt mit HL=Anfangsadresse    
        LD      (WORK),HL       ;setzen
        call    clear
        CALL    TON             ;Abspielen
        JP      MENU
;---------------------------------------        
HOME:   CALL    AUS
        LD      A,02h           ;Standard
        LD      I,A             ;Interruptsäule 02xx        
        EI
        ld      hl,BWS-19*64        
        ld      (curs),HL
        LD      A,0Dh
        RST     10h
        JP      07FDh       ;GETCO
;TÖNE/GERÄUSCHE-----------------------------------
;REGISTER       0,  1,  2   3   4   5   6   7   8   9   10  11  12  13
KANA:   DEFB    #EE,#00,#00,#00,#00,#00,#00,#FE,#10,#00,#00,#00,#30,#01 
KANB:   DEFB    #00,#00,#EE,#00,#00,#00,#00,#FD,#00,#10,#00,#00,#30,#01 
KANC:   DEFB    #00,#00,#00,#00,#EE,#00,#00,#FB,#00,#00,#10,#00,#30,#01 
DAMPF:  DEFB    #DD,#01,#7B,#01,#3E,#01,#00,#F8,#10,#10,#10,#00,#08,#0D     
HUBI:   DEFB    #6F,#00,#00,#00,#00,#00,#1E,#F6,#10,#00,#00,#2C,#01,#0E     
SONG:    ;(JINGLE)
INCLUDEBINARY   JINGLE.STC
