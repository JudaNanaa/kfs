const input = @import("input.zig");
const tty = @import("tty.zig");
const terminal = @import("terminal.zig");
const std = @import("std");

fn prompt() void {
    const current_ter = terminal.active();

    current_ter.write("> ");
}

const Command = struct {
    name: []const u8,
    help: []const u8,
    run: *const fn (args: []const u8) void,
};

const commands = [_]Command{
    .{ .name = "clear", .help = "clear the screen", .run = cmdClear },
    .{ .name = "echo", .help = "display a line of text", .run = cmdEcho },
    .{ .name = "help", .help = "show all commands", .run = cmdHelp },
};

fn cmdEcho(args: []const u8) void {
    terminal.active().print("{s}\n", .{args});
}

fn cmdClear(_: []const u8) void {
    terminal.active().clear();
}

fn cmdHelp(_: []const u8) void {
    const t = terminal.active();
    for (commands) |c|
        t.print("{s}\t{s}\n", .{ c.name, c.help });
}

fn execute(line: []const u8) void {
    const t = terminal.active();
    const trimmed = std.mem.trim(u8, line, " ");
    if (trimmed.len == 0) return;

    // sépare le nom de la commande et ses arguments
    var it = std.mem.tokenizeScalar(u8, trimmed, ' ');
    const name = it.next().?;
    const args = std.mem.trim(u8, trimmed[name.len..], " ");

    for (commands) |c| {
        if (std.mem.eql(u8, c.name, name)) {
            c.run(args);
            return;
        }
    }
    t.print("command not found: {s}\n", .{name});
}

pub fn run() noreturn {
    prompt();
    while (true) {
        if (input.pop()) |key| {
            if (tty.handle(key)) |cmd| {
                execute(cmd);
                prompt();
            }
        } else {
            asm volatile ("hlt");
        }
    }
}
