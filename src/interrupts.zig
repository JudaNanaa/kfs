const vga = @import("drivers/vga.zig");
const pic = @import("arch/x86/pic.zig");
const terminal = @import("terminal.zig");
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
    const t = terminal.active();
    t.printk("EXCEPTION 0x{x:0>2}\n", .{frame.vector});
    t.printk("ERR 0x{x:0>8}\n", .{frame.error_code});
    t.printk("EIP 0x{x:0>8}\n", .{frame.eip});
    while (true) asm volatile ("cli; hlt");
}
