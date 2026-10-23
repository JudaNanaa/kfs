//! Last-resort error screen: writes straight to VGA and serial,
//! without relying on the multiplexer or any other kernel state.

const std = @import("std");
const vga = @import("drivers/vga.zig");
const serial = @import("drivers/serial.zig");
const cpu = @import("arch/x86/cpu.zig");
const interrupts = @import("arch/x86/interrupts.zig");

const fg: vga.Color = .white;
const bg: vga.Color = .red;

var row: usize = 0;

fn clearScreen() void {
    const blank: [vga.width]vga.Entry = @splat(vga.Entry.init(' ', fg, bg));
    for (0..vga.height) |r| vga.blitRow(r, &blank);
    row = 0;
}

fn line(comptime fmt: []const u8, args: anytype) void {
    var buf: [vga.width]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, fmt, args) catch buf[0..];
    serial.print("{s}\n", .{s});

    if (row >= vga.height) return;
    var cells: [vga.width]vga.Entry = @splat(vga.Entry.init(' ', fg, bg));
    for (s, 0..) |c, i| cells[i] = vga.Entry.init(c, fg, bg);
    vga.blitRow(row, &cells);
    row += 1;
}

fn halt() noreturn {
    cpu.disableInterrupts();
    while (true) cpu.halt();
}

pub fn exception(f: *const interrupts.Frame) noreturn {
    cpu.disableInterrupts();
    vga.unsetCursor();
    clearScreen();
    line("KERNEL PANIC: CPU exception 0x{x:0>2}", .{f.vector});
    line("error code 0x{x:0>8}", .{f.error_code});
    line("", .{});
    line("eip 0x{x:0>8}  cs  0x{x:0>4}  eflags 0x{x:0>8}", .{ f.eip, f.cs, f.eflags });
    line("eax 0x{x:0>8}  ebx 0x{x:0>8}  ecx 0x{x:0>8}  edx 0x{x:0>8}", .{ f.eax, f.ebx, f.ecx, f.edx });
    line("esi 0x{x:0>8}  edi 0x{x:0>8}  ebp 0x{x:0>8}  esp 0x{x:0>8}", .{ f.esi, f.edi, f.ebp, f.esp });
    halt();
}

pub fn zigPanic(msg: []const u8, _: ?usize) noreturn {
    cpu.disableInterrupts();
    clearScreen();
    line("KERNEL PANIC: {s}", .{msg});
    halt();
}
