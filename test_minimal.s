.intel_syntax noprefix
.section .multiboot
.align 4
.long 0x1BADB002
.long 0x00000003
.long -(0x1BADB002+0x00000003)

.section .bss
.align 16
stack_bottom:
.skip 16384
stack_top:

.section .text
.global _start
_start:
    lea esp, [stack_top]
    mov edi, 0xB8000
    mov ax, 0x0F48  # 'H' blanc sur noir
    mov word ptr [edi], ax
    mov ax, 0x0F65  # 'e'
    mov word ptr [edi+2], ax
    mov ax, 0x0F6C  # 'l'
    mov word ptr [edi+4], ax
    mov ax, 0x0F6C  # 'l'
    mov word ptr [edi+6], ax
    mov ax, 0x0F6F  # 'o'
    mov word ptr [edi+8], ax
    cli
1: hlt
    jmp 1b
.size _start, . - _start
