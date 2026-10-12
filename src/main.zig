const std = @import("std");
const terminal = @import("terminal.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");

const int = @import("interrupts.zig");

const shell = @import("shell.zig");
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

    shell.run();

    while (true) {
        asm volatile ("hlt");
    }
}
