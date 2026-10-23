pub inline fn enableInterrupts() void {
    asm volatile ("sti");
}

pub inline fn enableInterruptsAndHalt() void {
    asm volatile ("sti; hlt" ::: .{ .memory = true });
}

pub inline fn disableInterrupts() void {
    asm volatile ("cli");
}

pub inline fn halt() void {
    asm volatile ("hlt");
}
