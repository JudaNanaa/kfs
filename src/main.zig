const std = @import("std");
const terminal = @import("terminal.zig");
const multiplexer = @import("multiplexer.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");
const pic = @import("arch/x86/pic.zig");
const cpu = @import("arch/x86/cpu.zig");

const int = @import("interrupts.zig");

const shell = @import("shell.zig");

const serial = @import("drivers/serial.zig");

export fn kernel_main() callconv(.c) void {
    serial.init();
    gdt.init();
    serial.print("la gdt est init\n", .{});
    idt.init();
    pic.remap(idt.IRQ_BASE, idt.IRQ_BASE + 8);
    int.initIRQ();
    serial.print("les interrupts sont set\n", .{});

    var mux = &multiplexer.mux;
    mux.init();
    cpu.enableInterrupts();
    serial.print("le multi plexer est init\n", .{});
    mux.run();
}
