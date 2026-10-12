.intel_syntax noprefix

.macro ISR n, has_err
isr\n:
.if \has_err == 0
    push 0
.endif
    push \n
    jmp isr_wrapper
.endm

.macro IRQ n, vector
irq\n:
	push 0
    push \vector
    jmp isr_wrapper
.endm


# vectors with no error code
.irp n, 0,1,2,3,4,5,6,7,9,15,16,18,19,20,22,23,24,25,26,27,28,31
    ISR \n, 0
.endr

# vectors where CPU push an error code
.irp n, 8,10,11,12,13,14,17,21,29,30
    ISR \n, 1
.endr

isr_wrapper:
    pushad
    cld						# C code following the sysV ABI requires DF to be clear on function entry 
    push esp                # argument : pointer to Frame
    call interrupt_handler
    add esp, 4
    popad
    add esp, 8              # retire vecteur + code d'erreur
    iretd

.global isr_table
isr_table:
.irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    .long isr\n
.endr

.irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    IRQ \n, 32+\n
.endr

.global irq_table
irq_table:
.irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    .long irq\n
.endr


