const input = @import("input.zig");
const tty = @import("tty.zig");
const terminal = @import("terminal.zig");
const std = @import("std");

const Command = struct {
    name: []const u8,
    help: []const u8,
    run: *const fn (args: []const u8, sh: *Shell) void,
};

const commands = [_]Command{
    .{ .name = "clear", .help = "clear the screen", .run = cmdClear },
    .{ .name = "echo", .help = "display a line of text", .run = cmdEcho },
    .{ .name = "help", .help = "show all commands", .run = cmdHelp },
};

fn cmdEcho(args: []const u8, sh: *Shell) void {
    sh.tty.print("{s}\n", .{args});
}

fn cmdClear(_: []const u8, sh: *Shell) void {
    sh.tty.clear();
}

fn cmdHelp(_: []const u8, sh: *Shell) void {
    for (commands) |c|
        sh.tty.print("{s}\t{s}\n", .{ c.name, c.help });
}

pub const Shell = struct {
    tty: *tty.TTY,

    pub fn init(_tty: *tty.TTY) Shell {
        return .{ .tty = _tty };
    }

    pub fn prompt(self: *Shell) void {
        return self.tty.write("> ");
    }

    pub fn execute(self: *Shell, line: []const u8) void {
        const trimmed = std.mem.trim(u8, line, " ");
        if (trimmed.len == 0) return;

        // sépare le nom de la commande et ses arguments
        var it = std.mem.tokenizeScalar(u8, trimmed, ' ');
        const name = it.next().?;
        const args = std.mem.trim(u8, trimmed[name.len..], " ");

        for (commands) |c| {
            if (std.mem.eql(u8, c.name, name)) {
                c.run(args, self);
                return;
            }
        }
        self.tty.print("command not found: {s}\n", .{name});
    }
};
