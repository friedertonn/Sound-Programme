;INCULDE FÜR SPIELDAUERBERECHNUNG PT3-SONGS
;-------------------------------------------------
;QUELLE:
;PT3 DURATION CALCULATOR
;AUTHOR SERGEY BULBA <VOROBEY@MAIL.KHSTU.RU>
;SUPPORT PAGE HTTP://BULBA.AT.KZ/
;(C)2005 S.V.BULBA
;-------------------------------------------------
;MODS WERO 01/2018:
; * IX-> IY
; * DIV16_8 ERGÄNZT FÜR UMRECHNUNG
;-------------------------------------------------
;BEZÜGE: 
;(MODADR)       ;ADRESSE SONGANFANG
;CALL CALC:     ;BERECHNUNG, RÜCKGABE:
;               ;H=MINUTEN, L=SEKUNDEN
;(PT3TIME)		;ZEIT ALS ANZAHL INTERRUPTS
;-------------------------------------------------
CALC:   DI                      
        ;SP IS USED, ANY INTERRUPTS ARE NOT ALLOWED
        LD      HL,(MODADR)     ;MODUL-LADEADRESSE
        LD      (PT3TMDAD),HL
        PUSH    HL
        PUSH    HL
        LD      DE,100
        ADD     HL,DE
        LD      A,(HL)          ;TEMPO-EINTRAG HOLEN
        LD      (PT3T_DL),A
        LD      E,3
        ADD     HL,DE
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        LD      H,D
        LD      L,D
        LD      (PT3TIME),HL
        POP     HL
        ADD     HL,BC
        LD      (PT3TPTPTR),HL
        POP     HL
        LD      E,201
        ADD     HL,DE
        PUSH    HL

PT3TLP: POP     HL
        LD      A,(HL)
        INC     HL
        INC     A
        JP      Z,PT3T_EXIT
        PUSH    HL
        DEC     A
        ADD     A,A
        LD      E,A
        LD      D,0
        RL      D
PT3TPTPTR: EQU $+1
        LD      HL,#2121
        ADD     HL,DE
PT3TMDAD: EQU $+1
        LD      DE,#1111
        LD      (PT3TSP_+1),SP
        LD      SP,HL
        POP     HL
        ADD     HL,DE
        LD      (PT3TADINPTA),HL
        POP     HL
        ADD     HL,DE
        LD      (PT3TADINPTB),HL
        POP     HL
        ADD     HL,DE
        LD      (PT3TADINPTC),HL
PT3TSP_:LD      SP,#3131
        LD      A,1
        LD      (PT3TSKACNT),A
        LD      (PT3TSKBCNT),A
        LD      (PT3TSKCCNT),A
PT3TLP2:LD      HL,PT3TSKACNT
        DEC     (HL)
        JR      NZ,PT3TCHB
PT3TADINPTA:    EQU $+1
        LD      BC,#0101
        LD      A,(BC)
        AND     A
        JR      Z,PT3TLP
PT3TSKPA:       EQU $+2
        LD      IYL,#2E
        CALL    PT3TPD
        LD      A,IYL
        LD      (PT3TSKPA),A
        LD      (PT3TSKACNT),A
        LD      (PT3TADINPTA),BC
PT3TCHB:
        LD      HL,PT3TSKBCNT
        DEC     (HL)
        JR      NZ,PT3TCHC
PT3TSKPB:       EQU $+2
        LD      IYL,#2E
PT3TADINPTB:    EQU $+1
        LD      BC,#0101
        CALL    PT3TPD
        LD      A,IYL
        LD      (PT3TSKPB),A
        LD      (PT3TSKBCNT),A
        LD      (PT3TADINPTB),BC
PT3TCHC:
        LD      HL,PT3TSKCCNT
        DEC     (HL)
        JR      NZ,EXTMP
PT3TSKPC:       EQU $+2
        LD      IYL,#2E
PT3TADINPTC:    EQU $+1
        LD      BC,#0101
        CALL    PT3TPD
        LD      A,IYL
        LD      (PT3TSKPC),A
        LD      (PT3TSKCCNT),A
        LD      (PT3TADINPTC),BC
EXTMP:  
PT3T_DL:        EQU $+1
        LD      DE,#11
PT3TIME:        EQU $+1
        LD      HL,#2121
        ADD     HL,DE
        LD      (PT3TIME),HL
        JP      PT3TLP2
PT3TSETSK:
        LD      A,(BC)
        LD      IYL,A
        JR      PT3TPD2
PT3TPD4:
        INC     BC
PT3TPD3:
        INC     BC
PT3TPD2:
        INC     BC
PT3TPD1:
        LD      A,(BC)
        INC     BC
        ADD     A,D
        JR      C,PT3TPD2
        ADD     A,E
        RET     Z
        JR      C,PT3TPD1
        ADD     A,D
        RET     Z
        JR      C,PT3TPD1
        ADD     A,14
        JR      C,PT3TPD3
        INC     A
        JR      Z,PT3TSETSK
        INC     A
        JR      Z,PT3TPD1
        ADD     A,96
        RET     C
        ADD     A,48
        JR      C,PT3TPD1
        ADD     A,15
        JR      C,PT3TPD4
        INC     A
        JR      Z,PT3TPD2
        ADD     A,A
        LD      E,A
        ;LD HL,PT3TSPCCOMS+#FF20-#1000
        ;                  -E0H
        LD      HL,PT3TSPCCOMS-10E0H
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        PUSH    DE
PT3TPD: LD      DE,#1020
        JR      PT3TPD1
PT3TC_DELAY:
        LD      A,(BC)
        INC     BC
        LD      (PT3T_DL),A
        RET
PT3TC_PORTM:
        INC     BC
        INC     BC
PT3TC_GLISS:
PT3TC_ENGLS:
        INC     BC
PT3TC_VIBRT:
        INC     BC
PT3TC_SMPOS:
PT3TC_ORPOS:
        INC     BC
PT3TC_NOP:
        RET
;ALL 16 ADDRESSES TO PROTECT FROM BROKEN PT3 MODULES
PT3TSPCCOMS:
        DEFW    PT3TC_NOP
        DEFW    PT3TC_GLISS
        DEFW    PT3TC_PORTM
        DEFW    PT3TC_SMPOS
        DEFW    PT3TC_ORPOS
        DEFW    PT3TC_VIBRT
        DEFW    PT3TC_NOP
        DEFW    PT3TC_NOP
        DEFW    PT3TC_ENGLS
        DEFW    PT3TC_DELAY
        DEFW    PT3TC_NOP
        DEFW    PT3TC_NOP
        DEFW    PT3TC_NOP
        DEFW    PT3TC_NOP
        DEFW    PT3TC_NOP
        DEFW    PT3TC_NOP
PT3T_EXIT:
        LD      HL,(PT3TIME)    ;LÄNGE IN INTERRUPTS
        ;DIVISION: ./. 50 HZ => SEKUNDEN
        LD      C,50
        CALL    DIV16_8 ;HL:=HL/C, A=REST
        ;./. 60 => MINUTEN
        LD      C,60
        CALL    DIV16_8 ;HL:=HL/C, A=REST
        LD      H,L     ;MINUTEN
        LD      L,A     ;SEKUNDEN
        EI 
        RET
;-------------------------------------------------
DIV16_8:
        XOR     A
        LD      B, 16
LOOPDIV:
        ADD     HL, HL
        RLA
        CP      C
        JR      C, $+4
        SUB     C
        INC     L
        DJNZ    LOOPDIV
        RET 
PT3TSKACNT: DEFB    0 
PT3TSKBCNT: DEFB    0 
PT3TSKCCNT: DEFB    0 
