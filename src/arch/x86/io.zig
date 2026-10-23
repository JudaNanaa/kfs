/// Sends a 8/16/32-bit value on a I/O location.
pub inline fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[v], %[p]"
        :
        : [v] "{al}" (value),
          [p] "{dx}" (port),
    );
}

/// Receives a 8-bit value from an I/O location.
pub inline fn inb(port: u16) u8 {
    return asm volatile ("inb %[p], %[r]"
        : [r] "={al}" (-> u8),
        : [p] "{dx}" (port),
    );
}

/// Wait a very small amount of time (1 to 4 microseconds, generally).
pub inline fn wait() void {
    outb(0x80, 0);
}
