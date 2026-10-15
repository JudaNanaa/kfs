const std = @import("std");
const terminal = @import("terminal.zig");
const multiplexer = @import("multiplexer.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");

const int = @import("interrupts.zig");

const shell = @import("shell.zig");

export fn kernel_main() callconv(.c) void {
    gdt.init();
    idt.init();
    int.initIRQ();

    var mux = multiplexer.mux;
    mux.init();
    // @panic("je suis ici");
    mux.run();
}
