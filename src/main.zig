const std = @import("std");
const Io = std.Io;
const Terminal = @import("termianl.zig").Terminal;
const gdt = @import("arch/x86/gdt.zig");

export fn kernel_main() callconv(.c) void {
    gdt.init();
    var terms: [4]Terminal = @splat(.{});

    terms[0].init();
    terms[0].write("42\n");

    for (0..100) |i| {
        terms[0].print("kfs version {d}\n", .{i});
        terms[0].flush();
    }
}
