const input = @import("input.zig");
const tty = @import("tty.zig");
const terminal = @import("terminal.zig");
const stdx = @import("stdx.zig");

fn prompt() void {
    const current_ter = terminal.active();

    current_ter.write("> ");
}

const Command = struct {
    name: []const u8,
    help: []const u8,
    run: *const fn () void,
};

const commands = [_]Command{
    .{ .name = "clear", .help = "clear the screen", .run = cmdClear },
    .{ .name = "help", .help = "list all commands", .run = cmdHelp },
};

fn cmdClear() void {
    terminal.active().clear();
}

fn cmdHelp() void {
    const t = terminal.active();
    for (commands) |c|
        t.print("{s}:\t{s}\n", .{ c.name, c.help });
}

fn execute(line: []const u8) void {
    const t = terminal.active();
    const trimmed = stdx.trim(line);
    if (trimmed.len == 0) return;

    for (commands) |c| {
        if (stdx.eql(c.name, trimmed)) {
            c.run();
            return;
        }
    }
    t.print("command not found: {s}\n", .{trimmed});
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
            asm volatile ("hlt"); // attend la prochaine IRQ
        }
    }
}
