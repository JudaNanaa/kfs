const vga = @import("drivers/vga.zig");
const pic = @import("arch/x86/pic.zig");
const debug = @import("debug.zig");

const keyboard = @import("drivers/keyboard.zig");

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

var irq_handlers: [16]?*const fn () void = @splat(null);

pub fn registerIrq(irq: u8, handler: *const fn () void) void {
    irq_handlers[irq] = handler;
}

export fn interrupt_handler(frame: *const Frame) callconv(.c) void {
    if (frame.vector >= 32 and frame.vector < 48) {
        const irq: u8 = @intCast(frame.vector - 32);
        if (irq_handlers[irq]) |handler| {
            handler();
        }
        pic.sendEOI(irq);
    } else {
        exception(frame);
    }
}

pub fn initIRQ() void {
    pic.disable();
    registerIrq(1, keyboard.handler);
    pic.clearMask(1);
}

fn exception(frame: *const Frame) noreturn {
    debug.putStr(0, 0, "EXCEPTION ");
    putHex(10, 0, frame.vector);
    debug.putStr(0, 1, "ERR ");
    putHex(4, 1, frame.error_code);
    debug.putStr(0, 2, "EIP ");
    putHex(4, 2, frame.eip);
    while (true) asm volatile ("cli; hlt");
}

fn putHex(x: usize, y: usize, v: u32) void {
    const digits = "0123456789ABCDEF";
    for (0..8) |i| {
        const shift: u5 = @intCast((7 - i) * 4);
        const nibble: usize = (v >> shift) & 0xF;
        vga.write(x + i, y, vga.Entry.init(digits[nibble], .white, .red));
    }
}
