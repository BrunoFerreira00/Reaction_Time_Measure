    .equ INITIAL_OUTPORT, 0xFF
    .equ USER_MASk, 0x01
    .equ INPORT_ADDRESS, 0xFF80
    .equ OUTPORT_ADDRESS, 0xFFC0
	.equ PTC_ADDRESS,  0xFF78        ; Endereco do circuito pTC

    .equ PTC_TCR, 0                    ; Deslocamento do registo TCR do pTC
	.equ PTC_TMR, 2                    ; Deslocamento do registo TMR do pTC
	.equ PTC_TC,  4                    ; Deslocamento do registo TC do pTC
	.equ PTC_TIR, 6                    ; Deslocamento do registo TIR do pTC
	.equ PTC_CMD_START, 0              ; Comando para iniciar a contagem no pTC
	.equ PTC_CMD_STOP, 1               ; Comando para parar a contagem no pTC

	.equ SYSCLK_FREQ, 0xFA             ; Intervalo de contagem do circuito pTC
                                          ; que suporta a implementação do sysclk                          
    .equ STACK_SIZE, 64                ; Dimensao do stack - 64 B
    .equ CPSR_BIT_I, 0b010000          ; Mascara para o bit I do registo CPSR
;----------------------------------------------------------------------------

	.section startup
	b	_start
	ldr	pc, isr_addr
_start:
	ldr	sp, tos_addr
	ldr	pc, main_addr

tos_addr:
	.word	tos
main_addr:
	.word	main
isr_addr:
	.word	isr

;---------------------------------------------------------------------------
	.text

main:
	mov	r0, #INITIAL_OUTPORT
	bl	outport_init
	mov	r0, #SYSCLK_FREQ
	bl	ptc_init
	mrs	r0, cpsr
	mov	r1, #CPSR_BIT_I
	orr	r0, r0, r1
	msr	cpsr, r0


;r1 temp
init:
    mov r0, #INITIAL_OUTPORT
    bl outport_write
    bl inport_read
    mov r1, #USER_MASk
    and r0, r0, r1
    cmp r0,r1 
    beq init ;1 bloco

check_USER:
    bl inport_read
    mov r1, #USER_MASk
    and r0, r0, r1
    cmp r0, r1 ;2 bloco
    bne check_USER ;transiçao para o terceiro


;r2 Delay Time
delay_time:
    mov r0, #0x01
    bl outport_write
    bl inport_read
    mov r2 , r0
    lsr r2 , r2 , #4
    mov r1 , #0x00
    cmp r1 , r2
    bhs init
    mov r1 , #0x0B
    cmp r2, r1
    bhs init;3 bloco
    mov r3, #0

multiplication:
    add r3, r3, #4
    sub r2, r2, #1
    mov r1, #0
    cmp r2, r1
    bne multiplication
    mov r0, #SYSCLK_FREQ
    bl delay
    mov r3, #0
    mov r0, #0x00
    bl outport_write

time_measure:
    bl inport_read 
    add r3, r3, #1
    mov r1, #0x01
    and r0, r0 , r1
    cmp r0, r1
    beq time_measure

fix_result:
    mov r1, #0x89 ; 137 ms
    cmp r1, r3
    bhs out_of_range
    mov r1, #0x07 
    movt r1, #0x01; 263 ms
    cmp r3, r1
    bhs out_of_range
    mov r1, #0xC8 ; 200 ms
    cmp r3, r1
    bge positive

negative:
    sub r3, r3, r1
    lsl r3, r3, #1 ;para colocar o1..o7
    mov r0, r3
    bl outport_write
    mov r3, #20
    mov r0, #SYSCLK_FREQ
    bl delay
    b init

positive:
    sub r3, r3 , r1
    lsl r3, r3, #1 ;para colocar o1..o7
    mov r0, r3
    bl outport_write
    mov r3, #20
    mov r0, #SYSCLK_FREQ
    bl delay
    b init

out_of_range:
    mov r0, #0x80
    bl outport_write
    mov r3, #20
    mov r0, #SYSCLK_FREQ
    bl delay
    b init



outport_init:
	push	lr
	ldr	r1, outport_img_addr
	strb	r0, [r1]
	bl	outport_write
	pop	pc

outport_img_addr:
	.word	outport_img

inport_read:
	ldr	r1, inport_addr
	ldrb r0, [r1, #0]
	mov	pc, lr

    
outport_write:
	ldr	r1, outport_addr
	strb r0, [r1, #0]
	mov	pc, lr

outport_addr:
    .word OUTPORT_ADDRESS


inport_addr:
    .word INPORT_ADDRESS

ptc_addr_addr:
    .word PTC_ADDR



ptc_start:
    push r0
	ldr	r0, PTC_ADDR
	mov	r1, #PTC_CMD_START
	strb r1, [r0, #PTC_TCR]
    pop r0
	mov	pc, lr

ptc_stop:
    push r0
	ldr	r0, PTC_ADDR
	mov	r1, #PTC_CMD_STOP
	strb r1, [r0, #PTC_TCR]
    pop r0
	mov	pc, lr

ptc_init:
	push lr
    push r0
    push r4
	push r5
	mov r5, r0
    bl ptc_stop
	ldr r4, PTC_ADDR
	strb r5, [r4, #PTC_TMR]
    strb     r5, [r4, #PTC_TIR] ; limpar PTC TIR
    bl ptc_start
	pop r5
	pop r4
    pop r0
    pop pc

isr:
 	push    r0
    push    r1
    ; limpar PTC TIR
    ldr r0, PTC_ADDR
    strb r0, [r0, #PTC_TIR]
    ldr    r0, sysclk_addr
    ldr    r1, [r0, #0]
    add    r1, r1, #1
    str    r1, [r0, #0]
    pop    r1
    pop    r0
    movs    pc, lr

sysclk_get_ticks:
	ldr    r0, sysclk_addr
    ldr    r0, [r0, #0]
    mov    pc, lr

sysclk_addr:
    .word sysclk

delay:
    mov r2 , #0
    and r0, r0, r0
    cmp r0, r2
    beq delay_end
delay_loop:
    sub r0, r0, #1
    cmp r0, r2
    bne delay_loop
    sub r3, r3, #1
    cmp r3, r2
    bne restart
delay_end:
    mov pc, lr

restart:
    mov r0 , #SYSCLK_FREQ
    b delay


PTC_ADDR:
    .word    PTC_ADDRESS





;----------------------------------------------------------------------------

    .data

;----------------------------------------------------------------------------    

    .bss
sysclk:
	.space	2
outport_img:
	.space	1
	.align
;----------------------------------------------------------------------------

    .stack
    .space STACK_SIZE
tos:
