.intel_syntax noprefix
.code32

.macro ISR n, has_err
isr\n:
.if \has_err == 0
    push 0
.endif
    push \n
    jmp isr_common
.endm

.section .text

# vecteurs sans code d'erreur
.irp n, 0,1,2,3,4,5,6,7,9,15,16,18,19,20,22,23,24,25,26,27,28,31
    ISR \n, 0
.endr
# vecteurs où le CPU pousse un code d'erreur
.irp n, 8,10,11,12,13,14,17,21,29,30
    ISR \n, 1
.endr

isr_common:
    pushad
    cld                     # l'ABI System V exige DF = 0
    push esp                # argument : pointeur vers la Frame
    call interrupt_dispatch
    add esp, 4
    popad
    add esp, 8              # retire vecteur + code d'erreur
    iretd

.section .rodata.isr_table, "a"
.global isr_table
isr_table:
.irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    .long isr\n
.endr
