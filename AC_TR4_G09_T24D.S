    .equ INITIAL_OUTPORT, 0xFF
    .equ INITIAL_USER, 0x00
    .equ USER_MASk, 0x01
    .equ INPORT_ADDRESS, 0xFF80
    .equ OUTPORT_ADDRESS, 0xFFC0
	.equ PTC_ADDRESS,  0xFF78         

    .equ PTC_TCR, 0                   
	.equ PTC_TMR, 2                   
	.equ PTC_TC,  4                   
	.equ PTC_TIR, 6                   
	.equ PTC_CMD_START, 0             
	.equ PTC_CMD_STOP, 1              

	.equ SYSCLK_FREQ, 249             
                                                                
    .equ STACK_SIZE, 64                
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

;Send code to init which is the start of the program
main:
	b init

;Start of the program
;Activates all leds on outport and verifies if user is not set for it to progress
init:
    bl reset
    mov r0, #INITIAL_OUTPORT
    bl outport_write
    bl inport_read
    mov r1, #USER_MASk
    and r0, r0, r1
    cmp r0,r1 
    beq init 


;Checks when user is set to 1 so the program can start to count
check_USER:
    bl inport_read 
    mov r1, #USER_MASk
    and r0, r0, r1
    cmp r0, r1                   
    bne check_USER               

;reads the time the user sets in which after it the stimulus will turn off
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
    blo init
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
    mov r0, #1  ;time measure plus isr clocks divided by 50khz = 1,5
    bl ptc_init


;Starts measuring the time the user takes to turn off the switch after stimulus turns off
time_measure:
    bl inport_read
    mov r1, #0x01
    and r0, r0 , r1
    cmp r0, r1
    beq time_measure
    bl ptc_stop
    
;compares the time the user took with the limits possible to see if it was out of range
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


;if it was below 200ms and in the range represents the difference beetween the time the user took with 200ms
;Set for the current position of the outport
negative:
    sub r0, r0, r1
    lsl r0, r0, #1 
    bl outport_write
    bl ptc_stop
    bl reset
    mov r0, #SYSCLK_FREQ
    bl ptc_init
    mov r0, #5
    bl delay_after
    b init


;if it was above 200ms and in the range represents the difference beetween the time the user took with 200ms
;Set for the current position of the outport
positive:
    sub r0, r0 , r1
    lsl r0, r0, #1 
    bl outport_write
    bl ptc_stop
    bl reset
    mov r0, #SYSCLK_FREQ
    bl ptc_init
    mov r0, #5 
    bl delay_after
    b init

;If the time the user took was out of range it will set the outport to -64
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


;initial outport
outport_init:
	push	lr
	ldr	r1, outport_img_addr
	strb	r0, [r1]
	bl	outport_write
	pop	pc

outport_img_addr:
	.word	outport_img

;reads the inport
inport_read:
	ldr	r1, inport_addr
	ldrb	r0, [r1, #0]
	mov	pc, lr

;writes the outport
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


;starts the ptc
ptc_start:
    push r0
	ldr	r0, PTC_ADDR
	mov	r1, #PTC_CMD_START
	strb r1, [r0, #PTC_TCR]
    pop r0
	mov	pc, lr

;stops the ptc
ptc_stop:
    push r0
	ldr	r0, PTC_ADDR
	mov	r1, #PTC_CMD_STOP
	strb r1, [r0, #PTC_TCR]
    pop r0
	mov	pc, lr

;initializes the ptc
ptc_init:
	push lr
    push r0
    push r4
	push r5
	mov r5, r0
    bl ptc_stop
	ldr r4, PTC_ADDR
	strb r5, [r4, #PTC_TMR]
    strb     r5, [r4, #PTC_TIR] 
    bl ptc_start
	pop r5
	pop r4
    pop r0
    pop pc

;interrupt service routine
isr:
 	push    r0
    push    r1
    ldr r0, PTC_ADDR
    strb r0, [r0, #PTC_TIR]
    ldr    r0, sysclk_addr
    ldr    r1, [r0, #0]
    add    r1, r1, #1
    str    r1, [r0, #0]
    pop    r1
    pop    r0
    movs    pc, lr

;gets the ticks set
sysclk_get_ticks:
	ldr    r0, sysclk_addr
    ldr    r0, [r0, #0]
    mov    pc, lr

;delay before stimulus turns off with correct value
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

;delay for showing the result for 5 seconds
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

;checks if the user is set to 1 , if it's not returns to the start of the program
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

;resets the sysclk
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
