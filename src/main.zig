const std = @import("std");
const Terminal = @import("terminal.zig").Terminal;
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");

comptime {
    _ = @import("interrupts.zig"); // force l'export de interrupt_dispatch
}

export fn kernel_main() callconv(.c) void {
    gdt.init();
    idt.init();

    asm volatile ("ud2");
    // var terms: [4]Terminal = @splat(.{});
    //
    // terms[0].init();
    // terms[0].write("42\n");
    //
    // for (0..100) |i| {
    //     terms[0].print("kfs version {d}\n", .{i});
    //     terms[0].flush();
    // }
}
