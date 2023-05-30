.equ INITIAL_OUTPORT 0xFF
.equ INITIAL_USER 0x00
.equ USER_MASk 0x01

;r1 temp
init:
mov r1, INITIAL_OUTPORT
str r1, [OUPORT_ADDR]
ldr r0, [INPORT_ADDR]
mov r1, INITIAL_USER
cmp r0,r1 
bne init ;1 bloco

check_USER:
    mov r1, USER_MASk
    cmp r0, r1 ;2 bloco
    bne check_USER;transiçao para o terceiro

;r2 Delay Time
delay_time:
    mov r1, #0x01
    str r1, [OUPORT_ADDR]
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
    str r1, [OUPORT_ADDR]
    ;ptc a adicionar o tempo -> r3
    ;mov r1, #0x01
    ;and r0, r0 , r1
    ;cmp r0, r1
    ;beq ptc

fix_result:
    mov r1, #0xC8
    cmp r1, r3
    bhs positive

negative:
    str r3, [OUPORT_ADDR]
    ;delay 5 segundos
    ;b init

positive:
     sub r3 ,r3 ,#0x40
    str r3, [OUPORT_ADDR]
    ;delay 5 segundos
    ;b init


    


INPORT_ADDR:
    .word 0xFF80

OUPORT_ADDR:
    .word 0xFFC0
