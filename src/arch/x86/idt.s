.intel_syntax noprefix

.global idt_flush
idt_flush:
	mov eax, [esp + 0x4]	# load the parameter into eax
	lidt [eax]				# load the idt
	sti						# set the iterrupts
	ret
