const pic = @import("pic.zig");
const idt = @import("idt.zig");
const cpu = @import("cpu.zig");

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

    const IRQ_LEN = 0x10;

    fn isIrq(self: *const Frame) bool {
        return self.vector >= idt.IRQ_BASE and self.vector < idt.IRQ_BASE + IRQ_LEN;
    }
};

pub const IrqHandler = *const fn () void;
pub const ExceptionHandler = *const fn (frame: *const Frame) noreturn;

var irq_handlers: [16]?IrqHandler = @splat(null);
var exception_handler: ExceptionHandler = haltForever;

/// Default handler until the kernel installs its own: stop the CPU.
fn haltForever(_: *const Frame) noreturn {
    cpu.disableInterrupts();
    while (true) cpu.halt();
}

/// Install `handler` for `irq` and unmask that line on the PIC.
pub fn registerIrq(irq: u4, handler: IrqHandler) void {
    irq_handlers[irq] = handler;
    pic.clearMask(irq);
}

pub fn setExceptionHandler(handler: ExceptionHandler) void {
    exception_handler = handler;
}

export fn interrupt_handler(frame: *const Frame) callconv(.c) void {
    if (!frame.isIrq()) exception_handler(frame);

    const irq: u4 = @intCast(frame.vector - idt.IRQ_BASE);
    if (irq_handlers[irq]) |handler| handler();
    pic.sendEOI(irq);
}

const testing = @import("std").testing;

// The layout must match exactly what interrupts.s pushes:
// pushad (8 registers), then vector and error code, then eip/cs/eflags from the CPU.
test "Frame: layout matches the assembly stub" {
    try testing.expectEqual(@as(usize, 13 * 4), @sizeOf(Frame));
    try testing.expectEqual(@as(usize, 0), @offsetOf(Frame, "edi"));
    try testing.expectEqual(@as(usize, 7 * 4), @offsetOf(Frame, "eax"));
    try testing.expectEqual(@as(usize, 8 * 4), @offsetOf(Frame, "vector"));
    try testing.expectEqual(@as(usize, 9 * 4), @offsetOf(Frame, "error_code"));
    try testing.expectEqual(@as(usize, 10 * 4), @offsetOf(Frame, "eip"));
    try testing.expectEqual(@as(usize, 12 * 4), @offsetOf(Frame, "eflags"));
}

test "Frame: isIrq covers vectors 0x20 to 0x2F only" {
    var f = @as(Frame, @bitCast(@as([13]u32, @splat(0))));
    for ([_]u32{ 0x00, 0x0E, 0x1F, 0x30, 0x80 }) |v| {
        f.vector = v;
        try testing.expect(!f.isIrq());
    }
    for ([_]u32{ 0x20, 0x21, 0x2F }) |v| {
        f.vector = v;
        try testing.expect(f.isIrq());
    }
}
