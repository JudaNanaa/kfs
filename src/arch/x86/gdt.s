.intel_syntax noprefix

.global gdt_flush
gdt_flush:
    mov eax, [esp + 4]      # take the argument from the stack: Gdtr address
    lgdt [eax]				# load the gdt 

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
