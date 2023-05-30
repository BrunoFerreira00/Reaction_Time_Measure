
.equ INITIAL_OUTPORT, 0xFF
.equ INITIAL_USER, 0x00
.equ USER_MASk, 0x01
.equ INPORT_ADDRESS, 0xFF80
.equ OUTPORT_ADDRESS, 0xFFC0

;r1 temp
init:
    mov r1, #INITIAL_OUTPORT
    mov r2, #outport_addr
    str r1, [r2]
    mov r2 , #inport_addr
    ldr r0, [r2]
    mov r1, #INITIAL_USER
    cmp r0,r1 
    bne init ;1 bloco

check_USER:
    mov r1, #USER_MASk
    cmp r0, r1 ;2 bloco
    bne check_USER;transiçao para o terceiro

;r2 Delay Time
delay_time:
    mov r1, #0x01
    mov r2 , #outport_addr
    str r1, [r2]
    mov r2 , r0
    lsr r2 , r2 , #4
    mov r1 , #0x01
    cmp r1 , r2
    bhs delay_time 
    mov r1 , #0x0A
    cmp r2, r1
    bhs delay_time;3 bloco

    ;subtrair r2 até 0
    ;mov r1, #0x00
    ;and r0, r0 , r1                DELAY TIME
    ;cmp r0, r1
    ;beq init
    ;4 bloco

time_measure:
    mov r1, #0x00
    mov r2 , #outport_addr
    str r1, [r2]
    ;ptc a adicionar o tempo -> r3
    ;mov r1, #0x01
    ;and r0, r0 , r1
    ;cmp r0, r1
    ;beq ptc

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
    mov r2, #outport_addr
    str r3, [r2]
    ;delay 5 segundos
    ;b init

positive:
    sub r3, r3 , r1
    lsl r3, r3, #1 ;para colocar o1..o7
    str r3, [r2]
    ;delay 5 segundos
    ;b init

out_of_range:
    mov r1, #0x80
    str r1, [r2]
    ;delay 5 segundos
    ;b init

    


inport_addr:
    .word INPORT_ADDRESS

outport_addr:
    .word OUTPORT_ADDRESS
