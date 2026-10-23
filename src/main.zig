const std = @import("std");
const multiplexer = @import("console/multiplexer.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");
const pic = @import("arch/x86/pic.zig");
const cpu = @import("arch/x86/cpu.zig");
const panic_screen = @import("panic.zig");
const interrupts = @import("arch/x86/interrupts.zig");
const serial = @import("drivers/serial.zig");
const keyboard = @import("drivers/keyboard.zig");
pub const panic = std.debug.FullPanic(panic_screen.zigPanic);

export fn kernel_main() callconv(.c) void {
    interrupts.setExceptionHandler(panic_screen.exception);
    serial.init();
    gdt.init();
    serial.print("la gdt est init\n", .{});
    idt.init();
    pic.remap(idt.IRQ_BASE, idt.IRQ_BASE + 8);
    interrupts.registerIrq(keyboard.IRQ, keyboard.handler);
    serial.print("les interrupts sont set\n", .{});

    var mux = &multiplexer.mux;
    mux.init();
    cpu.enableInterrupts();
    serial.print("le multi plexer est init\n", .{});
    mux.run();
}
