
; Archivo:	main.s
; Dispositivo:	PIC16F887
; Autor:	Javier Monzón 20054
; Compilador:	pic-as (v2.30), MPLABX V5.40
;
; Programa:	Contador de segundos
; Hardware:	Displays de 7 segmentos en el puerto C 
;		Transistores en el puerto D
;
; Creado:	21 febrero 2022
; Última modificación: 21 febrero 2022

PROCESSOR 16F887
#include <xc.inc>
    
; Configuration word 1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscilador interno sin salidas
  CONFIG  WDTE = OFF            ; WDT disabled (reinicio repetitivo del PIC)
  CONFIG  PWRTE = OFF           ; PWRT enabled (espera de 72ms al iniciar)
  CONFIG  MCLRE = OFF           ; El pin de MCLR se utiliza como I/O
  CONFIG  CP = OFF              ; Sin protección de código 
  CONFIG  CPD = OFF             ; Sin protección de datos
  
  CONFIG  BOREN = OFF           ; Sin reinicio cuando el voltaje de alimentación baja de 4V
  CONFIG  IESO = OFF            ; Reinicio sin cambio de reloj de interno a externo
  CONFIG  FCMEN = OFF           ; Cambio de reloj externo a interno en caso de fallo
  CONFIG  LVP = OFF             ; Programación en bajo voltaje permitida
  
; Configuration word 2
  CONFIG  BOR4V = BOR40V        ; Reinicio abajo de 4V 
  CONFIG  WRT = OFF             ; Protección de autoescritura por el programa desactivada 
    
; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr		    ; Memoria compartida
    wtemp:		DS  1
    status_temp:	DS  1
    
PSECT udata_bank0		; Variables almacenadas en el banco 0
    segundos:		DS  1
    unidades:		DS  1
    decenas:		DS  1
    banderas:		DS  1
    valor:		DS  1
    veces_u:		DS  1
    veces_d:		DS  1
    diez:		DS  1
    uno:		DS  1
    cont_1:		DS  1
    cont_2:		DS  1
    cont_3:		DS  1
    medio:		DS  1
    display:		DS  2

PSECT resVect, class = CODE, abs, delta = 2
 ;-------------- vector reset ---------------
 ORG 00h			; Posición 00h para el reset
 resVect:
    goto main

PSECT intVect, class = CODE, abs, delta = 2
ORG 004h				; posición 0004h para interrupciones
;------- VECTOR INTERRUPCIONES ----------
 
push:
    movwf   wtemp		; Se guarda W en el registro temporal
    swapf   STATUS, W		
    movwf   status_temp		; Se guarda STATUS en el registro temporal
    
isr:
    banksel INTCON
    btfsc   T0IF		; Ver si bandera de TMR0 se encendió
    call    t0
    btfsc   TMR1IF		; Ver si bandera de TMR1 se encendió
    call    t1
    btfsc   TMR2IF		; Ver si bandera de TMR2 se encendió
    call    t2
    
pop:
    swapf   status_temp, W	
    movwf   STATUS		; Se recupera el valor de STATUS
    swapf   wtemp, F
    swapf   wtemp, W		; Se recupera el valor de W
    retfie      
    
PSECT code,  delta = 2, abs
ORG 100h
 
main:
    call    config_IO		; Configuración de I/O
    call    config_clk		; Configuración de reloj
    call    config_tmr0
    call    config_tmr1
    call    config_tmr2
    call    config_int		; Configuración de interrupciones
    
loop:
    btfsc   cont_1,	1	; Verifica si contador 1 es 2
    call    complete1
    
    btfsc   cont_2,	3	; Verifica si contador 2 es 4
    call    complete2
    
    movf    segundos,	0
    sublw   0x3C
    btfsc   STATUS,	2	; Verificar si segundos = 60
    clrf    segundos
    movf    segundos,	0
    movwf   valor		; Almacenar el valor de segundos en valor
    
    ; Convertir a decimal 
    clrf    veces_u
    clrf    veces_d
    
    movf    diez,   0
    subwf   valor,  1
    incf    veces_d,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_decenas

    movf    uno,    0
    subwf   valor,  1
    incf    veces_u,	1
    btfsc   STATUS, 0
    goto    $-3
    call    check_unidades
   
    call    set_display
    goto    loop
    
;--------------- Subrutinas ------------------
config_IO:
    banksel ANSEL
    clrf    ANSEL
    clrf    ANSELH	    ; I/O digitales
    banksel TRISA
    clrf    TRISE	    ; Puerto E como salida
    clrf    TRISC	    ; Puerto C como salida
    clrf    TRISD	    ; Puerto D como salida
    banksel PORTA	    
    clrf    PORTC
    clrf    PORTD
    clrf    PORTE
    movlw   0x00
    movwf   segundos	    
    movlw   0x00    
    movwf   unidades
    movlw   0x00
    movwf   decenas
    movlw   0x00
    movwf   veces_u
    movlw   0x00
    movwf   veces_d
    movlw   0x0A
    movwf   diez
    movlw   0x01
    movwf   uno
    movlw   0x00
    movwf   banderas
    movlw   0x00
    movwf   cont_1
    movlw   0x00
    movwf   cont_2
    movlw   0x00
    movwf   cont_3
    movlw   0xFF
    movwf   PORTE
    
    config_clk:
    banksel OSCCON	    ; cambiamos a banco de OSCCON
    bsf	    OSCCON,	 0  ; SCS -> 1, Usamos reloj interno
    bsf	    OSCCON,	 6
    bsf	    OSCCON,	 5
    bcf	    OSCCON,	 4  ; IRCF<2:0> -> 110 4MHz
    return
    
config_tmr0:
    banksel OPTION_REG	    ; Cambiamos a banco de OPTION_REG
    bcf	    OPTION_REG, 5   ; T0CS = 0 --> TIMER0 como temporizador 
    bcf	    OPTION_REG, 3   ; Prescaler a TIMER0
    bcf	    OPTION_REG, 2   ; PS2
    bcf	    OPTION_REG, 1   ; PS1
    bcf	    OPTION_REG, 0   ; PS0 Prescaler de 1 : 2
    banksel TMR0	    ; Cambiamos a banco 0 de TIMER0
    movlw   6		    ; Cargamos el valor 6 a W
    movwf   TMR0	    ; Cargamos el valor de W a TIMER0 para 2mS de delay
    bcf	    T0IF	    ; Borramos la bandera de interrupcion
    return  
    
config_tmr1:
    banksel T1CON	    ; Cambiamos a banco de tmr1
    bcf	    TMR1CS	    ; Reloj interno 
    bcf	    T1OSCEN	    ; Apagamos LP
    bsf	    T1CKPS1	    ; Prescaler 1:8
    bsf	    T1CKPS0
    bcf	    TMR1GE	    ; tmr1 siempre contando 
    bsf	    TMR1ON	    ; Encender tmr1
    call    reset_tmr1
    return
    
config_tmr2:
    banksel PR2
    movlw   243		    ; Para delay de 62.5 mS
    movwf   PR2
    banksel T2CON
    bsf	    T2CKPS1	    ; Prescaler de 1:16
    bsf	    T2CKPS0
    bsf	    TOUTPS3	    ; Postscaler de 1:16
    bsf	    TOUTPS2
    bsf	    TOUTPS1
    bsf	    TOUTPS0
    bsf	    TMR2ON	    ; tmr2 encendido 
    return
    
config_int:
    banksel PIE1
    bsf	    TMR1IE	    ; Habilitamos interrupcion TMR1
    bsf	    TMR2IE	    ; Habilitamos interrupcion TMR2
    banksel INTCON
    bsf	    PEIE
    bsf	    GIE		    ; Habilitamos interrupciones
    bsf	    T0IE	    ; Habilitamos interrupcion TMR0
    bcf	    T0IF	    ; Limpiamos bandera de TMR0
    bcf	    TMR1IF	    ; Limpiamos bandera de TMR1
    bcf	    TMR2IF	    ; Limpiamos bandera de TMR2
    return
    
reset_tmr0:
    banksel TMR0	    ; cambiamos de banco
    movlw   6
    movwf   TMR0	    ; delay 2mS
    bcf	    T0IF
    return

reset_tmr1:
    banksel TMR1H
    movlw   0x0B	    ; Configuración tmr1 H
    movwf   TMR1H
    movlw   0xDC	    ; Configuración tmr1 L
    movwf   TMR1L	    ; tmr1 a 500 mS
    bcf	    TMR1IF	    ; Limpiar bandera de tmr1
    
t0:
    call    reset_tmr0
    call    mostrar_valores
    return
    
t1:
    call    reset_tmr1
    incf    cont_1
    return
    
t2:
    bcf	    TMR2IF	    ; Limpiar la bandera de tmr2
    incf    cont_2
    return
    
set_display:
    movf    unidades,	w 
    call    tabla
    movwf   display
    
    movf    decenas,	W
    call    tabla
    movwf   display+1
    return
   
mostrar_valores:
    clrf    PORTD
    btfsc   banderas,	0
    goto    display_1
    goto    display_0
    
    display_0:
	movf    display,    W
	movwf   PORTC
	bsf	PORTD,	    2
	bsf	banderas,   0
return

    display_1:
	movf    display+1,  W
	movwf   PORTC
	bsf	PORTD,	    1
	bcf	banderas,   0
return
	
check_decenas:
    decf    veces_d,	1
    movf    diez,   0
    addwf   valor,  1
    movf    veces_d,	0
    movwf   decenas
    return
    
check_unidades:
    decf    veces_u,	1
    movf    uno,    0
    addwf   valor,  1
    movf    veces_u,	0
    movwf   unidades
    return
    
complete1:
    clrf    cont_1
    incf    segundos,	1
    return
    
complete2:
    clrf    cont_2
    comf    PORTE
    return
    
    
org 200h
tabla:
    clrf    PCLATH
    bsf	    PCLATH, 1
    andlw   0x0F
    addwf   PCL, 1		; Se suma el offset al PC y se almacena en dicho registro
    retlw   0b11011101		; Valor para 0 en display de 7 segmentos
    retlw   0b01010000		; Valor para 1 en display de 7 segmentos
    retlw   0b11001110		; Valor para 2 en display de 7 segmentos
    retlw   0b11011010		; Valor para 3 en display de 7 segmentos
    retlw   0b01010011		; Valor para 4 en display de 7 segmentos
    retlw   0b10011011		; Valor para 5 en display de 7 segmentos 
    retlw   0b10011111		; Valor para 6 en display de 7 segmentos 
    retlw   0b11010000		; Valor para 7 en display de 7 segmentos 
    retlw   0b11011111		; Valor para 8 en display de 7 segmentos
    retlw   0b11010011		; Valor para 9 en display de 7 segmentos 
    retlw   0b11010111		; Valor para A en display de 7 segmentos
    retlw   0b00011111		; Valor para B en display de 7 segmentos
    retlw   0b10001101		; Valor para C en display de 7 segmentos
    retlw   0b01011110		; Valor para D en display de 7 segmentos
    retlw   0b10001111		; Valor para E en display de 7 segmentos 
    retlw   0b10000111		; Valor para F en display de 7 segmentos
    
END


