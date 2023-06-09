    .equ INITIAL_OUTPORT, 0xFF
    .equ INITIAL_USER, 0x00
    .equ USER_MASk, 0x01
    .equ INPORT_ADDRESS, 0xFF80
    .equ OUTPORT_ADDRESS, 0xFFC0
	.equ PTC_ADDRESS,  0xFF78          ; Endereco do circuito pTC

    .equ PTC_TCR, 0                    ; Deslocamento do registo TCR do pTC
	.equ PTC_TMR, 2                    ; Deslocamento do registo TMR do pTC
	.equ PTC_TC,  4                    ; Deslocamento do registo TC do pTC
	.equ PTC_TIR, 6                    ; Deslocamento do registo TIR do pTC
	.equ PTC_CMD_START, 0              ; Comando para iniciar a contagem no pTC
	.equ PTC_CMD_STOP, 1               ; Comando para parar a contagem no pTC

	.equ SYSCLK_FREQ, 249             ; Intervalo de contagem do circuito pTC
                                       ; que suporta a implementação do sysclk                          
    .equ STACK_SIZE, 64                ; Dimensao do stack - 64 B
    .equ	CPSR_BIT_I, 0b010000         
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
	b init

;r1 temp
init:
    bl reset
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
    bne check_USER;transiçao para o terceiro

;r2 Delay Time
delay_time:
    mov r0, #0x01
    bl outport_write
    bl inport_read 
    lsr r0 , r0 , #4 
    mov r1 , #0x01
    cmp r0 , r1
    blo init 
    mov r1 , #0x0A
    cmp r1, r0
    blo init;3 bloco
    bl reset
    push r0
    mov r0, #SYSCLK_FREQ
    bl ptc_init
    mrs	r0, cpsr
	mov	r1, #CPSR_BIT_I
	orr	r0, r0, r1
	msr	cpsr, r0
    pop r0
    bl delay_before
    mov r0, #0x00
    bl outport_write
    bl ptc_stop
    bl reset
    mov r0, #1  ;tempo de execuçao do p16 das funçoes "time_measure" + "isr"
    bl ptc_init

time_measure:
   ; bl reset
    bl inport_read
    mov r1, #0x01
    and r0, r0 , r1
    cmp r0, r1
    beq time_measure
    bl ptc_stop
    

fix_result:
    bl sysclk_get_ticks
    mov r1, #0x89 ; 137 ms
    cmp r1, r0
    bge out_of_range
    mov r1, #0x07 
    movt r1, #0x01; 263 ms
    cmp r0, r1
    bge out_of_range
    mov r1, #0xC8 ; 200 ms
    cmp r0, r1
    bge positive

negative:
    sub r0, r0, r1
    lsl r0, r0, #1 ;para colocar o1..o7
    bl outport_write
    bl ptc_stop
    bl reset
    mov r0, #SYSCLK_FREQ
    bl ptc_init
    mov r0, #5
    bl delay_after
    b init

positive:
    sub r0, r0 , r1
    lsl r0, r0, #1 ;para colocar o1..o7
    bl outport_write
    bl ptc_stop
    bl reset
    mov r0, #SYSCLK_FREQ
    bl ptc_init
    mov r0, #5 
    bl delay_after
    b init

out_of_range:
    mov r0, #0x80
    bl outport_write
    bl ptc_stop
    bl reset
    mov r0, #SYSCLK_FREQ
    bl ptc_init
    mov r0, #5
    bl delay_after
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
	ldrb	r0, [r1, #0]
	mov	pc, lr

    
outport_write:
	ldr	r1, outport_addr
	strb	r0, [r1, #0]
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

delay_before:
    push lr
    lsl r1, r0, #2
delay_loop_before:
    bl user_break
   bl sysclk_get_ticks
   cmp r1, r0
   bne delay_loop_before
delay_end_before:
    pop pc

delay_after:
    push lr
    lsl r1, r0, #2
delay_loop_after:
   bl sysclk_get_ticks
   cmp r1, r0
   bne delay_loop_after
delay_end_after:
    pop pc

PTC_ADDR:
    .word    PTC_ADDRESS

user_break:
    push lr
    push r1
    push r0
    bl inport_read
    mov r1, #USER_MASk
    and r0, r0, r1
    cmp r0,r1
    bne init
    pop r0
    pop r1
    pop pc

reset:
    ldr r1, sysclk_addr
    mov r2, #0
    str r2,[r1]
    mov pc, lr

sysclk_addr:
    .word sysclk



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
