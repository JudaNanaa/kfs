.intel_syntax noprefix

.section .text
.global gdt_flush
.type gdt_flush, @function
gdt_flush:
    mov eax, [esp + 4]      # argument : pointeur vers le Gdtr
    lgdt [eax]

    mov ax, 0x10            # kernel data
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ax, 0x18            # kernel stack
    mov ss, ax

    mov eax, offset gdt_reload
    push 0x08
    push eax
    retf

gdt_reload:
    ret
