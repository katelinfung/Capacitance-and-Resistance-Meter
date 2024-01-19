; Feb 5 2021
; Katelin Fung
; 
; Video Demonstration https://youtu.be/U4vsaI4lazE
; 
; Features:
; Measures Capacitance and Resistance and displays these values on an LCD screen


$NOLIST
$MODEFM8LB1
$LIST

org 0000H
   ljmp MyProgram
   
; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5

BSEG
mf: dbit 1

$NOLIST
$include(math32.inc)
$LIST   


; These 'equ' must match the hardware wiring
; They are used by 'LCD_4bit.inc'
LCD_RS equ P2.0
LCD_RW equ P1.7
LCD_E  equ P1.6
LCD_D4 equ P1.1
LCD_D5 equ P1.0
LCD_D6 equ P0.7
LCD_D7 equ P0.6
$NOLIST
$include(LCD_4bit.inc)
$LIST

CSEG

Msg1:  db 'Cap(nF)', 0
Msg2:  db 'Re(ohm)', 0

; This 'wait' must be as precise as possible. Sadly the 24.5MHz clock in the EFM8LB1 has an accuracy of just 2%.
Wait_one_second:	
    ;For a 24.5MHz clock one machine cycle takes 1/24.5MHz=40.81633ns
    mov R2, #198 ; Calibrate using this number to account for overhead delays
X3: mov R1, #245
X2: mov R0, #167
X1: djnz R0, X1 ; 3 machine cycles -> 3*40.81633ns*167=20.44898us (see table 10.2 in reference manual)
    djnz R1, X2 ; 20.44898us*245=5.01ms
    djnz R2, X3 ; 5.01ms*198=0.991s + overhead
    ret
    
    
; Compte resitance

res:

Load_x(1890)
mov y+0, TL0
mov y+1, TH0
mov y+2, #0 ; pad high bits with zero
mov y+3, #0 ; pad high bits with zero
lcall sub32 ; This subroutine is in math32.inc
Load_y(10)
lcall mul32
mov TL0, x+0
mov TH0, x+1
ret

; Compte Capacitance

cap:

Load_X(180000)
mov y+0, TL0
mov y+1, TH0
mov y+2, #0 ; pad high bits with zero
mov y+3, #0 ; pad high bits with zero
lcall div32
Load_y(1)
lcall sub32 ; This subroutine is in math32.inc
mov TL0, x+0
mov TH0, x+1

ret


;Converts the hex number in TH0-TL0 to packed BCD in R2-R1-R0
hex2bcd16:
	clr a
    mov R0, #0  ; Set packed BCD result to 00000 
    mov R1, #0
    mov R2, #0
    mov R3, #16 ; Loop counter.
    
hex2bcd16_L0:
    mov a, TL0 ; Shift TH0-TL0 left through carry
    rlc a
    mov TL0, a
    
    mov a, TH0
    rlc a
    mov TH0, a
    
	; Perform bcd + bcd + carry
	; using BCD numbers
	mov a, R0
	addc a, R0
	da a
	mov R0, a
	
	mov a, R1
	addc a, R1
	da a
	mov R1, a
	
	mov a, R2
	addc a, R2
	da a
	mov R2, a
	
	djnz R3, hex2bcd16_L0
	ret

; Dumps the 5-digit packed BCD number in R2-R1-R0 into the LCD
DisplayBCD:
	; 5th digit:
    mov a, R2
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 4th digit:
    mov a, R1
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 3rd digit:
    mov a, R1
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 2nd digit:
    mov a, R0
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 1st digit:
    mov a, R0
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
    
    ret
    
MyProgram:
	mov sp, #0x7F ; Initialize the stack pointer
    
    ; DISABLE WDT: provide Watchdog disable keys
	mov	WDTCN,#0xDE ; First key
	mov	WDTCN,#0xAD ; Second key

    ; Enable crossbar and weak pull-ups
	mov	XBR0,#0x00
	mov	XBR1,#0x10 ; Enable T0 on P0.0.  T0 is the external clock input to Timer/Counter 0
	mov	XBR2,#0x40

	; Switch clock to 24.5 MHz
	mov	CLKSEL, #0x00 ; 
	mov	CLKSEL, #0x00 ; Second write to CLKSEL is required according to the user manual (page 77)
	
	; Wait for the 24.5 MHz oscillator to stabilze by checking bit DIVRDY in CLKSEL
waitclockstable:
	mov a, CLKSEL
	jnb acc.7, waitclockstable
	
	;Initializes timer/counter 0 as a 16-bit counter
    clr TR0 ; Stop timer 0
    mov a, TMOD
    anl a, #0b_1111_0000 ; Clear the bits of timer/counter 0
    orl a, #0b_0000_0101 ; Sets the bits of timer/counter 0 for a 16-bit counter
    mov TMOD, a

	; Configure LCD and display initial message
    lcall LCD_4BIT
	Set_Cursor(1, 1)
    Send_Constant_String(#Msg1)
    Set_Cursor(2, 1)
    Send_Constant_String(#Msg2)
    


Forever:

    ; Measure the frequency applied to pin T0 (T0 is routed to pin P0.0 using the 'crossbar')
    clr TR0 ; Stop counter 0
    mov TL0, #0
    mov TH0, #0
    setb TR0 ; Start counter 0
    lcall Wait_one_second
    clr TR0 ; Stop counter 0, TH0-TL0 has the frequency

	; Convert the result to BCD and display on LCD
	Set_Cursor(1, 10)
	lcall cap
    lcall hex2bcd16
    lcall DisplayBCD
       
    ; Measure the frequency applied to pin T0 (T0 is routed to pin P0.0 using the 'crossbar')
    clr TR0 ; Stop counter 0
    mov TL0, #0
    mov TH0, #0
    setb TR0 ; Start counter 0
    lcall Wait_one_second
    clr TR0 ; Stop counter 0, TH0-TL0 has the frequency

    Set_Cursor(2, 10)
	lcall res
    lcall hex2bcd16
    lcall DisplayBCD

	ljmp Forever ; Repeat!
	
END
