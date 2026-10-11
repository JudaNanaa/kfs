const std = @import("std");
const terminal = @import("terminal.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");

const int = @import("interrupts.zig"); // force l'export de interrupt_dispatch

export fn kernel_main() callconv(.c) void {
    terminal.initAll();
    const t = terminal.active();
    t.printk("Terminal init success\n", .{});
    gdt.init();
    t.printk("GDT init success\n", .{});
    idt.init();
    t.printk("IDT init success\n", .{});
    int.initIRQ();
    t.printk("IRQ init success\n", .{});
    // asm volatile ("ud2");

    // const t = terminal.active();
    // t.print("pas mal\n", .{});
    // t.flush();
    while (true) {
        asm volatile ("hlt");
    }
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
