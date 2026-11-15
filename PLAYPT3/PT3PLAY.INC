;INCLUDE-DATEI FÜR PT3-PLAYER
;-------------------------------------------------
;BASIS:
;VORTEX TRACKER II V1.0 PT3 PLAYER FOR ZX SPECTRUM
;(C)2004,2007 S.V.BULBA <VOROBEY@MAIL.KHSTU.RU>
;HTTP://BULBA.UNTERGRUND.NET (HTTP://BULBA.AT.KZ)
RELEASE:EQU "7"                  ;RELEASE NUMBER
;-------------------------------------------------
;MODS:
; * EINGEBAUTE INT-ERZEUGUNG PER CTC
; * ERSATZ IX DURCH IY WEGEN KC85/X
; * AY-ADRESSIERUNG ANGEPASST
; * AY-MIXERBITS IMMER BELASSEN!
; * POSITIONSZÄHLER EINGEFÜGT 
; * PAUSENFLAG EINGEFÜGT
; * INT-ZÄHLER EINGEFÜGT (PT3TIME)
;-------------------------------------------------
;NÖTIGE KONSTANTEN IM HAUPTPROGRAMM:
;AYBAS:     BASISADRESSE AY-3-8910
;CTCBAS:    BASISADRESSE DER CTC    
;CTCKAN:    KANAL DER CTC       
;CTCZK:     ZEITKONSTANTE
;CTCINT:    ANFANG INTERRUPTTABELLE
;Q358:      CTC-Kaskadierung K0+K1
;-------------------------------------------------
DEFM "=VTII PT3 Player r.",Release,"="  ;IDENTIFIER
;BEZÜGE-------------------------------------------
;CALL   PLAY:   ;INIT CTC + PLAYER
;CALL   STOPP:  ;CTC INTERRUPT AUS, TON AUS
;CALL   MUTE:   ;NUR TON AUS
;-------------------------------------------------
;VARIABLEN:
;-------------------------------------------------
MODADR: DEFW    0               ;ÜBERGABE SONGADRESSE
SETUP:  DEFB    0               ;STATUS-RÜCKGABE 
        ;SET BIT0 TO 1, IF YOU WANT TO PLAY WITHOUT LOOPING
        ;BIT7 IS SET EACH TIME, WHEN LOOP POINT IS PASSED
CRPSPTR:DEFW    0               ;POINTER TO CURRENT POSITION VALUE IN PT3 MODULE;
                                ;AFTER INIT (START+11) POINTS TO POSTION0-1
POSI:   DEFB    0               ;POSITION IN MUSTERLISTE
PAUSE:  DEFB    0               ;FLAG FÜR PAUSIEREN
;AYREGS:        ;TABELLENANFANG AUSGABEINHALTE DER 13 AY-REGISTER
                ;Z.B. (AYREGS+8) = AMPLITUDE KANAL A
;-------------------------------------------------
;AUTO-LOOP
CHECKLP:LD      HL,SETUP
        SET     7,(HL)          ;ENDEBIT SETZEN
        BIT     0,(HL)          ;LOOP?
        RET     Z               ;JA
        ;SONGENDE
        POP     HL              ;PLAY VERLASSEN
        LD      HL,DELYCNT
        INC     (HL)
        LD      HL,CHANA+CHP_NTSKCN
        INC     (HL)
MUTE:   XOR     A
        LD      H,A
        LD      L,A
        LD      (AYREGS+8),A    ;AMPLA
        LD      (AYREGS+9),HL   ;AMPLB
        JP      ROUT_A0         ;AY-REGISTER SETZEN
;-------------------------------------------------
ISR:    DI
        LD      (SPSV2),SP   ;Stackpointer merken
        LD      SP, STACK2   ;lokaler Stack
        PUSH    IY
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    AF
        EX      AF,AF'
        PUSH    AF
        LD      A,(PAUSE)
        OR      A
        JR      NZ,PAUSE1       ;KEIN FORTSCHRITT
        CALL    PLAY_Q          ;1 SEGMENT ABSPIELEN
PAUSE1: POP     AF
        EX      AF,AF'
        POP     AF
        POP     BC
        POP     DE
        POP     HL
        POP     IY
        LD      SP,(SPSV2)   ;alten Stackpointer zurückholen
        EI                      
        ;ERST HIER FREIGEBEN, PLAYER MANIPULIERT STACK!!!!
        RETI
;-------------------------------------------------        
STOPP:  ;SONG ANHANLTEN, INTERRUPT STOPPEN
        ;REGISTERWERTE FUER "ALLES AUS
        DI
        LD      A,#43           ;STEUERWORT (INT AUS)
if Q358=1                       ;K0+K1 KASKADIERT
        OUT     (CTCBAS+1),A
else                            ;nur KAN. x
        OUT     (CTCBAS+CTCKAN),A
endif
STOPP1: LD      HL,STOPP2       ;REGISTERWERTE FUER ANHALTEN
        LD      DE,AYREGS       ;TABELLE AUSGABE-WERTE
        LD      BC,14           ;14 REGISTERWERTE
        LDIR                    ;UMLADEN        
        CALL    ROUT            ;IN AY3 SCHREIBEN
        EI
        RET
STOPP2: DEFB    0,0,0,0,0,0,0,0FFH,0,0,0,0,0,0 
;-------------------------------------------------
;ABSPIEL STARTEN
PLAY:   ;(1)Arbeitszellen löschen-----------------
        LD      HL,VARs
        LD      (HL),0
        LD      DE,VArS+1
        LD      BC,VAR0END-1 - VArs
        LDIR
        ;(2) CTC INITIALISIEREN-------------------
        DI
        LD      HL,ISR          ;ADR. PLAYERROUTINE
;#################################################
if Q358=1                       ;K0+K1 KASKADIERT
        LD      (CTCINT+2),HL   ;ALS INTERRUPT-ADRESSE K1
else                            ;nur KAN. x
        LD      (CTCINT+CTCKAN*2),HL  ;ALS INTERRUPT-ADRESSE Kx
endif
        LD      A,LO CTCINT     ;IV (01)C8
        OUT     (CTCBAS),A      ;K0
;#################################################
if Q358=1                       ;K0+K1 KASKADIERT
        LD      A,#47           ;STEUERWORT, KEIN INT
        OUT     (CTCBAS),A      ;K0   
        LD      A,#9D           ;ZK1=157
        OUT     (CTCBAS),A      
        LD      A,#C7           ;STEUERWORT, INT!
        OUT     (CTCBAS+1),A    ;K1
        LD      A,#39           ;ZK2=57 
        OUT     (CTCBAS+1),A    ;FÜR 3,57954 MHz --> 49,999 Hz
else                            ;nur KAN. x
        LD      A,0A7H          ;STEUERWORT, MIT INT, VT 256
        OUT     (CTCBAS+CTCKAN),A  ;Kx  
        LD      A,CTCZK         ;ZK JE NACH TAKTFREQUENZ
        OUT     (CTCBAS+CTCKAN),A  
endif
;#################################################
        EI
        ;(3) PLAYER INITIALISIEREN----------------
        XOR     A
        LD      (POSI),A        ;POSITIONSZÄHLER
        LD      HL,(MODADR)     ;HL - ADDRESS OF MODULE
        LD      (MODADDR),HL
        LD      (MDADDR2),HL
        PUSH    HL
        LD      DE,100
        ADD     HL,DE
        LD      A,(HL)
        LD      (DELAY),A
        PUSH    HL
        POP     IY
        ADD     HL,DE
        LD      (CRPSPTR),HL        ;AKT. MUSTERADRESSE
        LD      E,(IY+102-100)
        ADD     HL,DE
        INC     HL
        LD      (LPOSPTR),HL
        POP     DE
        LD      L,(IY+103-100)
        LD      H,(IY+104-100)
        ADD     HL,DE
        LD      (PATSPTR),HL
        LD      HL,169
        ADD     HL,DE
        LD      (ORNPTRS),HL
        LD      HL,105
        ADD     HL,DE
        LD      (SAMPTRS),HL
        LD      HL,SETUP
        RES     7,(HL)             ;ENDEBIT RÜCKSETZEN
;NOTE TABLE DATA DEPACKER
        LD      DE,T_PACK
        LD      BC,T1_+(2*49)-1
TP_0:   LD      A,(DE)
        INC     DE
        CP      15*2
        JR      NC,TP_1
        LD      H,A
        LD      A,(DE)
        LD      L,A
        INC     DE
        JR      TP_2
TP_1:   PUSH    DE
        LD      D,0
        LD      E,A
        ADD     HL,DE
        ADD     HL,DE
        POP     DE
TP_2:   LD      A,H
        LD      (BC),A
        DEC     BC
        LD      A,L
        LD      (BC),A
        DEC     BC
        SUB     0F0H             ;#F8*2
        JR      NZ,TP_0
        LD      HL,VARS
        LD      (HL),A
        LD      DE,VARS+1
        LD      BC,VAR0END-VARS-1
        LDIR
        INC     A
        LD      (DELYCNT),A
        LD      HL,0F001H               ;H - CHP_VOLUME, L - CHP_NTSKCN
        LD      (CHANA+CHP_NTSKCN),HL
        LD      (CHANB+CHP_NTSKCN),HL
        LD      (CHANC+CHP_NTSKCN),HL
        LD      HL,EMPTYSAMORN
        LD      (ADINPTA),HL            ;PTR TO ZERO
        LD      (CHANA+CHP_ORNPTR),HL   ;ORNAMENT 0 IS "0,1,0"
        LD      (CHANB+CHP_ORNPTR),HL   ;IN ALL VERSIONS FROM
        LD      (CHANC+CHP_ORNPTR),HL   ;3.XX TO 3.6X AND VTII
        LD      (CHANA+CHP_SAMPTR),HL   ;S1 THERE IS NO DEFAULT
        LD      (CHANB+CHP_SAMPTR),HL   ;S2 SAMPLE IN PT3, SO, YOU
        LD      (CHANC+CHP_SAMPTR),HL   ;S3 CAN COMMENT S1,2,3; SEE
                                        ;ALSO EMPTYSAMORN COMMENT
        ;IY AUF DELAY = OFFSET 100
        LD      A,(IY+13-100)           ;EXTRACT VERSION NUMBER
        SUB     30H
        JR      C,L20
        CP      10
        JR      C,L21
L20:    LD      A,6
L21:    LD      (VERSION),A
        PUSH    AF
        CP      4
        LD      A,(IY+99-100) ;TONE TABLE NUMBER
        RLA
        AND     7
;NOTETABLECREATOR (C) IVAN ROSHIN-----------------
;A - NOTETABLENUMBER*2+VERSIONFORNOTETABLE
;(XX1B - 3.XX..3.4R, XX0B - 3.4X..3.6X..VTII1.0)

        LD      HL,NT_DATA
        PUSH    DE
        LD      D,B
        ADD     A,A
        LD      E,A
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        SRL     E
        SBC     A,A
        AND     0A7H         ;#00 (NOP) OR #A7 (AND A)
        LD      (L3),A
        EX      DE,HL
        POP     BC          ;BC=T1_
        ADD     HL,BC
        LD      A,(DE)
        ;--------
        ;ADD    A,T_  
        ;LD     C,A
        ;ADC    A,C         ;T_/256
        ;SUB    C
        ;LD     B,A
        ;----
        LD      BC,T_
        ADD     A,C
        LD      C,A
        ADC     A,B

        SUB     C
        LD      B,A
        ;----
        PUSH    BC
        LD      DE,NT_
        PUSH    DE
        LD      B,12
L1:     PUSH    BC
        LD      C,(HL)
        INC     HL
        PUSH    HL
        LD      B,(HL)

        PUSH    DE
        EX      DE,HL
        LD      DE,23
        LD      IYH,8

L2:     SRL     B
        RR      C
L3:     DEFB    19H    ;AND A OR NOP
        LD      A,C
        ADC     A,D ;=ADC 0
        LD      (HL),A
        INC     HL
        LD      A,B
        ADC     A,D
        LD      (HL),A
        ADD     HL,DE
        DEC     IYH
        JR      NZ,L2

        POP     DE
        INC     DE
        INC     DE
        POP     HL
        INC     HL
        POP     BC
        DJNZ    L1

        POP     HL
        POP     DE

        LD      A,E
        PUSH    DE
        LD      DE,TCOLD_1
        CP      E
        POP     DE

        JR      NZ,CORR_1
        LD      A,0FDH
        LD      (NT_+2EH),A

CORR_1: LD      A,(DE)
        AND     A
        JR      Z,TC_EXIT
        RRA
        PUSH    AF
        ADD     A,A
        LD      C,A
        ADD     HL,BC
        POP     AF
        JR      NC,CORR_2
        DEC     (HL)
        DEC     (HL)
CORR_2: INC     (HL)
        AND     A
        SBC     HL,BC
        INC     DE
        JR      CORR_1

TC_EXIT:POP     AF
;VOLTABLECREATOR (C) IVAN ROSHIN------------------
;A - VERSIONFORVOLUMETABLE 
;0..4 - 3.XX..3.4X;
;5..  - 3.5X..3.6X..VTII1.0)

        CP      5
        LD      HL,11H
        LD      D,H
        LD      E,H
        LD      A,17H
        JR      NC,M1
        DEC     L
        LD      E,L
        XOR     A
M1:     LD      (M2),A
        LD      IY,VT_+16
        LD      C,10H
INITV2: PUSH    HL
        ADD     HL,DE
        EX      DE,HL
        SBC     HL,HL

INITV1: LD      A,L
M2:     DEFB    7DH
        LD      A,H
        ADC     A,0
        LD      (IY),A
        INC     IY
        ADD     HL,DE
        INC     C
        LD      A,C
        AND     15
        JR      NZ,INITV1

        POP     HL
        LD      A,E
        CP      77H
        JR      NZ,M3
        INC     E
M3:     LD      A,C
        AND     A
        JR      NZ,INITV2
        JP      ROUT_A0         ;AUSGABE AN AY-REGISTER
;PATTERN DECODER----------------------------------
PD_ORSM:LD      (IY-12+CHP_ENV_EN),0
        CALL    SETORN
        LD      A,(BC)
        INC     BC
        RRCA
PD_SAM: ADD     A,A
PD_SAM_:LD      E,A
        LD      D,0
SAMPTRS:EQU     $+1
        LD      HL,2121H
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
MODADDR:EQU     $+1
        LD      HL,2121H
        ADD     HL,DE
        LD      (IY-12+CHP_SAMPTR),L
        LD      (IY-12+CHP_SAMPTR+1),H
        JR      PD_LOOP
;-------
PD_VOL: RLCA
        RLCA
        RLCA
        RLCA
        LD      (IY-12+CHP_VOLUME),A
        JR      PD_LP2
;-------
PD_EOFF:    
        LD      (IY-12+CHP_ENV_EN),A
        LD      (IY-12+CHP_PSINOR),A
        JR      PD_LP2
;-------
PD_SORE:
        DEC     A
        JR      NZ,PD_ENV
        LD      A,(BC)
        INC     BC
        LD      (IY-12+CHP_NNTSKP),A
        JR      PD_LP2
;-------
PD_ENV: CALL    SETENV
        JR      PD_LP2
;-------
PD_ORN: CALL    SETORN
        JR      PD_LOOP
;-------
PD_ESAM:
        LD      (IY-12+CHP_ENV_EN),A
        LD      (IY-12+CHP_PSINOR),A
        CALL    NZ,SETENV
        LD      A,(BC)
        INC     BC
        JR      PD_SAM_
;-------
PTDECOD:
        LD      A,(IY-12+CHP_NOTE)
        LD      (PRNOTE+1),A
        LD      L,(IY-12+CHP_CRTNSL)
        LD      H,(IY-12+CHP_CRTNSL+1)
        LD      (PRSLIDE+1),HL

PD_LOOP:LD      DE,2010H
PD_LP2: LD      A,(BC)
        INC     BC
        ADD     A,E
        JR      C,PD_ORSM
        ADD     A,D
        JR      Z,PD_FIN
        JR      C,PD_SAM
        ADD     A,E
        JR      Z,PD_REL
        JR      C,PD_VOL
        ADD     A,E
        JR      Z,PD_EOFF
        JR      C,PD_SORE
        ADD     A,96
        JR      C,PD_NOTE
        ADD     A,E
        JR      C,PD_ORN
        ADD     A,D
        JR      C,PD_NOIS
        ADD     A,E
        JR      C,PD_ESAM
        ADD     A,A
        LD      E,A
        LD      HL,SPCCOMS-20E0H;      #FF20-#2000
    ;ALL 16 ADDRESSES TO PROTECT FROM BROKEN PT3 MODULES
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        PUSH    DE
        JR      PD_LOOP
;--------
PD_NOIS:
        LD      (NS_BASE),A
        JR      PD_LP2
;--------
PD_REL: RES     0,(IY-12+CHP_FLAGS)
        JR      PD_RES
;--------
PD_NOTE:
        LD      (IY-12+CHP_NOTE),A
        SET     0,(IY-12+CHP_FLAGS)
        XOR     A
PD_RES: LD      (PDSP_+1),SP
        LD      SP,IY
        LD      H,A
        LD      L,A
        PUSH    HL
        PUSH    HL
        PUSH    HL
        PUSH    HL
        PUSH    HL
        PUSH    HL
PDSP_:  LD      SP,3131H
PD_FIN: LD      A,(IY-12+CHP_NNTSKP)
        LD      (IY-12+CHP_NTSKCN),A
        RET
;-------------------------------------------------
C_PORTM:
        RES     2,(IY-12+CHP_FLAGS)
        LD      A,(BC)
        INC     BC
;SKIP PRECALCULATED TONE DELTA (BECAUSE
;CANNOT BE RIGHT AFTER PT3 COMPILATION)
        INC     BC
        INC     BC
        LD      (IY-12+CHP_TNSLDL),A
        LD      (IY-12+CHP_TSLCNT),A
        LD      DE,NT_
        LD      A,(IY-12+CHP_NOTE)
        LD      (IY-12+CHP_SLTONT),A
        ADD     A,A
        LD      L,A
        LD      H,0
        ADD     HL,DE
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        PUSH    HL
PRNOTE:
        LD      A,3EH
        LD      (IY-12+CHP_NOTE),A
        ADD     A,A
        LD      L,A
        LD      H,0
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        POP     HL
        SBC     HL,DE
        LD      (IY-12+CHP_TNDELT),L
        LD      (IY-12+CHP_TNDELT+1),H
        LD      E,(IY-12+CHP_CRTNSL)
        LD      D,(IY-12+CHP_CRTNSL+1)
VERSION:EQU     $+1
        LD      A,3EH
        CP      6
        JR      C,OLDPRTM ;OLD 3XXX FOR PT V3.5-
PRSLIDE:LD      DE,1111H
        LD      (IY-12+CHP_CRTNSL),E
        LD      (IY-12+CHP_CRTNSL+1),D
OLDPRTM:LD      A,(BC)          ;SIGNED TONE STEP
        INC     BC
        EX      AF,AF'
        LD      A,(BC)
        INC     BC
        AND     A
        JR      Z,NOSIG
        EX      DE,HL
NOSIG:  SBC     HL,DE
        JP      P,SET_STP
        CPL
        EX      AF,AF'
        NEG
        EX      AF,AF'
SET_STP:
        LD      (IY-12+CHP_TSLSTP+1),A
        EX      AF,AF'
        LD      (IY-12+CHP_TSLSTP),A
        LD      (IY-12+CHP_CONOFF),0
        RET
;-------------------------------------------------
C_GLISS:
        SET     2,(IY-12+CHP_FLAGS)
        LD      A,(BC)
        INC     BC
        LD      (IY-12+CHP_TNSLDL),A
        AND     A
        JR      NZ,GL36
        LD      A,(VERSION) ;ALCO PT3.7+
        CP      7
        SBC     A,A
        INC     A
GL36:   LD      (IY-12+CHP_TSLCNT),A
        LD      A,(BC)
        INC     BC
        EX      AF,AF'
        LD      A,(BC)
        INC     BC
        JR      SET_STP
;-------
C_SMPOS:LD      A,(BC)
        INC     BC
        LD      (IY-12+CHP_PSINSM),A
        RET
;-------
C_ORPOS:LD      A,(BC)
        INC     BC
        LD      (IY-12+CHP_PSINOR),A
        RET
;-------
C_VIBRT:LD      A,(BC)
        INC     BC
        LD      (IY-12+CHP_ONOFFD),A
        LD      (IY-12+CHP_CONOFF),A
        LD      A,(BC)
        INC     BC
        LD      (IY-12+CHP_OFFOND),A
        XOR     A
        LD      (IY-12+CHP_TSLCNT),A
        LD      (IY-12+CHP_CRTNSL),A
        LD      (IY-12+CHP_CRTNSL+1),A
        RET
;-------
C_ENGLS:
        LD      A,(BC)
        INC     BC
        LD      (ENV_DEL),A
        LD      (CUREDEL),A
        LD      A,(BC)
        INC     BC
        LD      L,A
        LD      A,(BC)
        INC     BC
        LD      H,A
        LD      (ESLDADD),HL
        RET
C_DELAY:
        LD      A,(BC)
        INC     BC
        LD      (DELAY),A
        RET
;-------
SETENV: LD      (IY-12+CHP_ENV_EN),E
        LD      (AYREGS+13),A        ;ENVTP
        LD      A,(BC)
        INC     BC
        LD      H,A
        LD      A,(BC)
        INC     BC
        LD      L,A
        LD      (ENVBASE),HL
        XOR     A
        LD      (IY-12+CHP_PSINOR),A
        LD      (CUREDEL),A
        LD      H,A
        LD      L,A
        LD      (CURESLD),HL
C_NOP:  RET
;-------------------------------------------------
SETORN: ADD     A,A
        LD      E,A
        LD      D,0
        LD      (IY-12+CHP_PSINOR),D
ORNPTRS:EQU     $+1
        LD      HL,2121H
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
MDADDR2:EQU     $+1
        LD      HL,2121H
        ADD     HL,DE
        LD      (IY-12+CHP_ORNPTR),L
        LD      (IY-12+CHP_ORNPTR+1),H
        RET
;ALL 16 ADDRESSES TO PROTECT FROM BROKEN PT3 MODULES
;235A
SPCCOMS:
        DEFW    C_NOP
        DEFW    C_GLISS
        DEFW    C_PORTM
        DEFW    C_SMPOS
        DEFW    C_ORPOS
        DEFW    C_VIBRT
        DEFW    C_NOP
        DEFW    C_NOP
        DEFW    C_ENGLS
        DEFW    C_DELAY
        DEFW    C_NOP
        DEFW    C_NOP
        DEFW    C_NOP
        DEFW    C_NOP
        DEFW    C_NOP
        DEFW    C_NOP
;-------------------------------------------------
CHREGS: XOR     A
        LD      (AMPL),A             ;AYREGS+10 = AMPLC
        BIT     0,(IY+CHP_FLAGS)
        PUSH    HL
        JP      Z,CH_EXIT
        LD      (CSP_+1),SP
        LD      L,(IY+CHP_ORNPTR)
        LD      H,(IY+CHP_ORNPTR+1)
        LD      SP,HL
        POP     DE
        LD      H,A
        LD      A,(IY+CHP_PSINOR)
        LD      L,A
        ADD     HL,SP
        INC     A
        CP      D
        JR      C,CH_ORPS
        LD      A,E
CH_ORPS:    
        LD      (IY+CHP_PSINOR),A
        LD      A,(IY+CHP_NOTE)
        ADD     A,(HL)
        JP      P,CH_NTP
        XOR     A
CH_NTP: CP      96
        JR      C,CH_NOK
        LD      A,95
CH_NOK: ADD     A,A
        EX      AF,AF'
        LD      L,(IY+CHP_SAMPTR)
        LD      H,(IY+CHP_SAMPTR+1)
        LD      SP,HL
        POP     DE
        LD      H,0
        LD      A,(IY+CHP_PSINSM)
        LD      B,A
        ADD     A,A
        ADD     A,A
        LD      L,A
        ADD     HL,SP
        LD      SP,HL
        LD      A,B
        INC     A
        CP      D
        JR      C,CH_SMPS
        LD      A,E
CH_SMPS:
        LD      (IY+CHP_PSINSM),A
        POP     BC
        POP     HL
        LD      E,(IY+CHP_TNACC)
        LD      D,(IY+CHP_TNACC+1)
        ADD     HL,DE
        BIT     6,B
        JR      Z,CH_NOAC
        LD      (IY+CHP_TNACC),L
        LD      (IY+CHP_TNACC+1),H
CH_NOAC:
        EX      DE,HL
        EX      AF,AF'
        LD      L,A
        LD      H,0
        LD      SP,NT_
        ADD     HL,SP
        LD      SP,HL
        POP     HL
        ADD     HL,DE
        LD      E,(IY+CHP_CRTNSL)
        LD      D,(IY+CHP_CRTNSL+1)
        ADD     HL,DE
CSP_:   LD      SP,3131H
        EX      (SP),HL
        XOR     A
        OR      (IY+CHP_TSLCNT)
        JR      Z,CH_AMP
        DEC     (IY+CHP_TSLCNT)
        JR      NZ,CH_AMP
        LD      A,(IY+CHP_TNSLDL)
        LD      (IY+CHP_TSLCNT),A
        LD      L,(IY+CHP_TSLSTP)
        LD      H,(IY+CHP_TSLSTP+1)
        LD      A,H
        ADD     HL,DE
        LD      (IY+CHP_CRTNSL),L
        LD      (IY+CHP_CRTNSL+1),H
        BIT     2,(IY+CHP_FLAGS)
        JR      NZ,CH_AMP
        LD      E,(IY+CHP_TNDELT)
        LD      D,(IY+CHP_TNDELT+1)
        AND     A
        JR      Z,CH_STPP
        EX      DE,HL
CH_STPP:
        SBC     HL,DE
        JP      M,CH_AMP
        LD      A,(IY+CHP_SLTONT)
        LD      (IY+CHP_NOTE),A
        XOR     A
        LD      (IY+CHP_TSLCNT),A
        LD      (IY+CHP_CRTNSL),A
        LD      (IY+CHP_CRTNSL+1),A
CH_AMP: LD      A,(IY+CHP_CRAMSL)
        BIT     7,C
        JR      Z,CH_NOAM
        BIT     6,C
        JR      Z,CH_AMIN
        CP      15
        JR      Z,CH_NOAM
        INC     A
        JR      CH_SVAM
CH_AMIN:CP      -15
        JR      Z,CH_NOAM
        DEC     A
CH_SVAM:LD      (IY+CHP_CRAMSL),A
CH_NOAM:LD      L,A
        LD      A,B
        AND     15
        ADD     A,L
        JP      P,CH_APOS
        XOR     A
CH_APOS:CP      16
        JR      C,CH_VOL
        LD      A,15
CH_VOL: OR      (IY+CHP_VOLUME)
        LD      L,A
        LD      H,0
        LD      DE,VT_
        ADD     HL,DE
        LD      A,(HL)
CH_ENV: BIT     0,C
        JR      NZ,CH_NOEN
        OR      (IY+CHP_ENV_EN)
CH_NOEN:LD      (AMPL),A             ;AYREGS+10 = AMPLC
        BIT     7,B
        LD      A,C
        JR      Z,NO_ENSL
        RLA
        RLA
        SRA     A
        SRA     A
        SRA     A
        ADD     A,(IY+CHP_CRENSL) ;SEE COMMENT BELOW
        BIT     5,B
        JR      Z,NO_ENAC
        LD      (IY+CHP_CRENSL),A
NO_ENAC:LD      HL,ADDTOEN
        ADD     A,(HL) ;BUG IN PT3 - NEED WORD HERE.
        ;FIX IT IN NEXT VERSION?
        LD      (HL),A
        JR      CH_MIX
NO_ENSL:RRA
        ADD     A,(IY+CHP_CRNSSL)
        LD      (ADDTONS),A
        BIT     5,B
        JR      Z,CH_MIX
        LD      (IY+CHP_CRNSSL),A
CH_MIX: LD      A,B
        RRA
        AND     48H
CH_EXIT:LD      HL,AYREGS+7      ;MIXER
        OR      (HL)
        RRCA
        LD      (HL),A
        POP     HL
        XOR     A
        OR      (IY+CHP_CONOFF)
        RET     Z
        DEC     (IY+CHP_CONOFF)
        RET     NZ
        XOR     (IY+CHP_FLAGS)
        LD      (IY+CHP_FLAGS),A
        RRA
        LD      A,(IY+CHP_ONOFFD)
        JR      C,CH_ONDL
        LD      A,(IY+CHP_OFFOND)
CH_ONDL:LD      (IY+CHP_CONOFF),A
        RET
;-------------------------------------------------
;EIN SEGMENT ABSPIELEN MIT ISR
PLAY_Q: LD      HL,(PT3TIME)    ;RESTZEIT
        DEC     HL
        LD      (PT3TIME),HL
        XOR     A
        LD      (ADDTOEN),A
        LD      (AYREGS+7),A     ;MIXER
        DEC     A
        LD      (AYREGS+13),A    ;ENVTP
        LD      HL,DELYCNT
        DEC     (HL)
        JP      NZ,PL2
        LD      HL,CHANA+CHP_NTSKCN
        DEC     (HL)
        JR      NZ,PL1B
ADINPTA:EQU     $+1
        LD      BC,0101H
        LD      A,(BC)
        AND     A
        JR      NZ,PL1A
        LD      D,A
        LD      (NS_BASE),A
        LD      HL,(CRPSPTR)    ;AKT. MUSTERADRESSE
        LD      A,(POSI)
        INC     A               ;POSITIONSZÄHLER
        LD      (POSI),A

        INC     HL
        LD      A,(HL)          ;FOLGEBYTE
        INC     A               ;= FF (=ENDE MUSTERLISTE) ?
        JR      NZ,PLNLP        ;NEIN, 
        CALL    CHECKLP         ;JA, LOOP AUSFÜHREN?
        
LPOSPTR:EQU     $+1
        LD      HL,2121H        ;PATCH!
        LD      A,(HL)
        INC     A
PLNLP:  LD      (CRPSPTR),HL    ;NÄCHSTE MUSTERADRESSE
        DEC     A               ;MUSTER-NR.
        ADD     A,A             ;*2
        LD      E,A             ;MERKEN
        RL      D
PATSPTR:EQU     $+1
        LD      HL,2121H        ;PATCH!
        ADD     HL,DE
        LD      DE,(MODADDR)
        LD      (PSP_+1),SP
        LD      SP,HL
        POP     HL
        ADD     HL,DE
        LD      B,H
        LD      C,L
        POP     HL
        ADD     HL,DE
        LD      (ADINPTB),HL
        POP     HL
        ADD     HL,DE
        LD      (ADINPTC),HL
PSP_:   LD      SP,3131H
PL1A:   LD      IY,CHANA+12
        CALL    PTDECOD
        LD      (ADINPTA),BC
PL1B:   LD      HL,CHANB+CHP_NTSKCN
        DEC     (HL)
        JR      NZ,PL1C
        LD      IY,CHANB+12
ADINPTB:EQU     $+1
        LD      BC,0101H
        CALL    PTDECOD
        LD      (ADINPTB),BC
PL1C:   LD      HL,CHANC+CHP_NTSKCN
        DEC     (HL)
        JR      NZ,PL1D
        LD      IY,CHANC+12
ADINPTC:EQU     $+1
        LD      BC,0101H
        CALL    PTDECOD
        LD      (ADINPTC),BC
DELAY:  EQU     $+1
PL1D:   LD      A,3EH
        LD      (DELYCNT),A
PL2:    LD      IY,CHANA
        LD      HL,(AYREGS+0)    ;TONA
        CALL    CHREGS
        LD      (AYREGS+0),HL
        LD      A,(AMPL)                ;AYREGS+10 = AMPLC
        LD      (AYREGS+8),A ;AMPLA

        LD      IY,CHANB
        LD      HL,(AYREGS+2)    ;TONB
        CALL    CHREGS
        LD      (AYREGS+2),HL
        LD      A,(AMPL)                ;AYREGS+10 = AMPLC
        LD      (AYREGS+9),A ;AMPLB
        
        LD      IY,CHANC
        LD      HL,(AYREGS+4)    ;TONC
        CALL    CHREGS
        LD      (AYREGS+4),HL    
        LD      HL,(NS_BASE_ADDTONS)
        LD      A,H
        ADD     A,L
        LD      (AYREGS+6),A     ;NOISE
ADDTOEN:EQU     $+1
        LD      A,3EH
        LD      E,A
        ADD     A,A
        SBC     A,A
        LD      D,A
        LD      HL,(ENVBASE)
        ADD     HL,DE
        LD      DE,(CURESLD)
        ADD     HL,DE
        LD      (AYREGS+11),HL   ;ENV
        XOR     A
        LD      HL,CUREDEL
        OR      (HL)
        JR      Z,ROUT_A0
        DEC     (HL)
        JR      NZ,ROUT
ENV_DEL:EQU     $+1
        LD      A,3EH
        LD      (HL),A
ESLDADD:EQU     $+1
        LD      HL,2121H
        ADD     HL,DE
        LD      (CURESLD),HL
;AUAGABE AN AY-REGISTER---------------------------
ROUT:   XOR     A               ;AB REG 0 PROGRAMMIEREN
ROUT_A0:                        ;AB REG. IN A
        ;MIXER: PORTBITS NICHT ANTASTEN-----------
        PUSH    AF
        LD      A,7             ;MISCHER
        OUT     (AYBAS),A       ;ADRESSIEREN
        IN      A,(AYBAS)       ;UND AUSLESEN
        AND     A,0C0H          ;NUR PORTBITS
        LD      C,A             ;MERKEN
        LD      A,(AYREGS+7)    ;MISCHER-INHALT AUS PUFFER
        AND     A,3FH           ;NUR RAUSCHEN+TON-BITS
        OR      C               ;+ALTE PORTSBITS
        LD      (AYREGS+7),A    ;ALS NEUER MISCHERPUFFER       
        POP     AF
        ;-----------------------------------------
        LD      C,AYBAS         ;38H
        LD      HL,AYREGS       ;TABELLENANFANG
LOUT:   OUT     (C),A           ;REGISTER AUSWÄHLEN
        INC     C               ;REGISTER BESCHREIBEN
        OUTI                    ;(HL)-> AUSGEBEN
        DEC     C               ;REGISTER AUSWÄHLEN
        INC     A               ;NÄCHSTES REGISTER
        CP      13              ;LETZTES?
        JR      NZ,LOUT         ;NOCH NICHT!
        OUT     (C),A           ;LETZTES
        LD      A,(HL)
        AND     A               ;
        RET     M               ;WENN NEGATIV (>80H)
        INC     C
        OUT     (C),A           ;BESCHREIBEN
        RET
;-------------------------------------------------
NT_DATA:
        DEFB    (T_NEW_0-T1_)*2
        DEFB    TCNEW_0-T_
        DEFB    (T_OLD_0-T1_)*2+1
        DEFB    TCOLD_0-T_
        DEFB    (T_NEW_1-T1_)*2+1
        DEFB    TCNEW_1-T_
        DEFB    (T_OLD_1-T1_)*2+1
        DEFB    TCOLD_1-T_
        DEFB    (T_NEW_2-T1_)*2
        DEFB    TCNEW_2-T_
        DEFB    (T_OLD_2-T1_)*2
        DEFB    TCOLD_2-T_
        DEFB    (T_NEW_3-T1_)*2
        DEFB    TCNEW_3-T_
        DEFB    (T_OLD_3-T1_)*2
        DEFB    TCOLD_3-T_
;-------
T_:
TCOLD_0:
        DEFB #0,#05,#09,#0B,#0D,#0F,#13,#15,#19,#25,#3D,0
TCOLD_1:
        DEFB #5D,0
TCOLD_2:
        DEFB #31,#37,#4D,#54,#5F,#71,#82,#8C,#9C
        DEFB #9E,#A0,#A6,#A8,#AA,#AC,#AE,#AE,0
TCNEW_3:
        DEFB #57
TCOLD_3:
        DEFB #1F,#23,#25,#29,#2D,#2F,#33,#BF,0
TCNEW_0:
        DEFB #1D,#21,#23,#27,#2B,#2D,#31,#55,#BD,#BF,0
TCNEW_1:EQU TCOLD_1
TCNEW_2:
        DEFB #1B,#21,#25,#29,#2B,#3B,#4D,#5F,#BB,#BD,#BF,0

EMPTYSAMORN:    EQU $-1
        DEFB 1,0,#90 ;DELETE #90 IF YOU DON'T NEED DEFAULT SAMPLE

;FIRST 12 VALUES OF TONE TABLES (PACKED)
T_PACK: DEFB #0D, #D8
        DEFB #0755-#06EC
        DEFB #07C5-#0755
        DEFB #083B-#07C5
        DEFB #08B8-#083B
        DEFB #093D-#08B8
        DEFB #09CA-#093D
        DEFB #0A5F-#09CA
        DEFB #0AFC-#0A5F
        DEFB #0BA4-#0AFC
        DEFB #0C55-#0BA4
        DEFB #0D10-#0C55
        
        DEFB  #0C,#DA
        DEFB #06CF-#066D
        DEFB #0737-#06CF
        DEFB #07A4-#0737
        DEFB #0819-#07A4
        DEFB #0894-#0819
        DEFB #0917-#0894
        DEFB #09A1-#0917
        DEFB #0A33-#09A1
        DEFB #0ACF-#0A33
        DEFB #0B73-#0ACF
        DEFB #0C22-#0B73
        DEFB #0CDA-#0C22
        
        DEFB #0E,#08
        DEFB #076E-#0704
        DEFB #07E0-#076E
        DEFB #0858-#07E0
        DEFB #08D6-#0858
        DEFB #095C-#08D6
        DEFB #09EC-#095C
        DEFB #0A82-#09EC
        DEFB #0B22-#0A82
        DEFB #0BCC-#0B22
        DEFB #0C80-#0BCC
        DEFB #0D3E-#0C80
        
        DEFB #0F,#C0
        DEFB #0858-#07E0
        DEFB #08E0-#0858
        DEFB #0960-#08E0
        DEFB #09F0-#0960
        DEFB #0A88-#09F0
        DEFB #0B28-#0A88
        DEFB #0BD8-#0B28
        DEFB #0C80-#0BD8
        DEFB #0D60-#0C80
        DEFB #0E10-#0D60
        DEFB #0EF8-#0E10
;-------------------------------------------------
;VARS FROM HERE CAN BE STRIPPED
;YOU CAN MOVE VARS TO ANY OTHER ADDRESS
VARS:
;CHANNELSVARS-------------------------------------
CHP_PSINOR: EQU 0   ;RESB 1
CHP_PSINSM: EQU 1   ;RESB 1
CHP_CRAMSL: EQU 2   ;RESB 1
CHP_CRNSSL: EQU 3   ;RESB 1
CHP_CRENSL: EQU 4   ;RESB 1
CHP_TSLCNT: EQU 5   ;RESB 1
CHP_CRTNSL: EQU 6   ;RESW 1
CHP_TNACC:  EQU 8   ;RESW 1
CHP_CONOFF: EQU 10  ;RESB 1
CHP_ONOFFD: EQU 11  ;RESB 1

;IY FOR PTDECOD HERE (+12)
CHP_OFFOND: EQU 12  ;RESB 1
CHP_ORNPTR: EQU 13  ;RESW 1
CHP_SAMPTR: EQU 15  ;RESW 1
CHP_NNTSKP: EQU 17  ;RESB 1
CHP_NOTE:   EQU 18  ;RESB 1
CHP_SLTONT: EQU 19  ;RESB 1
CHP_ENV_EN: EQU 20  ;RESB 1
CHP_FLAGS:  EQU 21  ;RESB 1
CHP_TNSLDL: EQU 22  ;RESB 1
CHP_TSLSTP: EQU 23  ;RESW 1
CHP_TNDELT: EQU 25  ;RESW 1
CHP_NTSKCN: EQU 27  ;RESB 1
CHP_VOLUME: EQU 28  ;RESB 1
CHP_SIZE:   EQU 29  ;RESB 1

CHANA:      DEFS CHP_SIZE
CHANB:      DEFS CHP_SIZE
CHANC:      DEFS CHP_SIZE

;GLOBALVARS
DELYCNT:    DEFB 0
CURESLD:    DEFW 0
CUREDEL:    DEFB 0

NS_BASE_ADDTONS:
NS_BASE:    DEFB 0
ADDTONS:    DEFB 0

;######################################################
;LOKALER STACK 40h
SPSV2:  DEFM    0000h           ;Merker für Stackpointer
        DEFS    40h             ;lokaler Stack  
STACK2:
;######################################################

AYREGS:
VT_:        DEFS    256         ;CREATEDVOLUMETABLEADDRESS
ENVBASE:    EQU     VT_+14
T1_:        EQU     VT_+16      ;TONE TABLES DATA DEPACKED HERE

T_OLD_1:    EQU     T1_
T_OLD_2:    EQU     T_OLD_1+24
T_OLD_3:    EQU     T_OLD_2+24
T_OLD_0:    EQU     T_OLD_3+2
T_NEW_0:    EQU     T_OLD_0
T_NEW_1:    EQU     T_OLD_1
T_NEW_2:    EQU     T_NEW_0+24
T_NEW_3:    EQU     T_OLD_3

NT_:        DEFS    192         ;CREATEDNOTETABLEADDRESS

;LOCAL VAR
AMPL:       EQU     AYREGS+10   ;AMPLC
VAR0END:    EQU     VT_+16      ;INIT ZEROES FROM VARS TO VAR0END-1
