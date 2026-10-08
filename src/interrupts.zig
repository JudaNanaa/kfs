const vga = @import("drivers/vga.zig");

/// Ce que isr_common a empilé, en adresses croissantes.
pub const Frame = extern struct {
    // pushad (ordre dans la mémoire)
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,
    // poussés par le stub
    vector: u32,
    error_code: u32,
    // poussés par le CPU
    eip: u32,
    cs: u32,
    eflags: u32,
};

export fn interrupt_dispatch(frame: *const Frame) callconv(.c) void {
    exception(frame);
}

fn exception(frame: *const Frame) noreturn {
    putStr(0, 0, "EXCEPTION ");
    putHex(10, 0, frame.vector);
    putStr(0, 1, "ERR ");
    putHex(4, 1, frame.error_code);
    putStr(0, 2, "EIP ");
    putHex(4, 2, frame.eip);
    while (true) asm volatile ("cli; hlt");
}

fn putStr(x: usize, y: usize, s: []const u8) void {
    for (s, 0..) |c, i| vga.write(x + i, y, vga.Entry.init(c, .white, .red));
}

fn putHex(x: usize, y: usize, v: u32) void {
    const digits = "0123456789ABCDEF";
    for (0..8) |i| {
        const shift: u5 = @intCast((7 - i) * 4);
        const nibble: usize = (v >> shift) & 0xF;
        vga.write(x + i, y, vga.Entry.init(digits[nibble], .white, .red));
    }
}
