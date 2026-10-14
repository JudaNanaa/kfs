const input = @import("input.zig");
const tty = @import("tty.zig");
const terminal = @import("terminal.zig");
const std = @import("std");

pub const Line = struct {
    str: [256]u8 = undefined,
    len: usize = 0,
    cap: usize = 256,

    pub fn append(self: *Line, c: u8) void {
        self.str[self.len] = c;
        self.len += 1;
    }

    pub fn pop(self: *Line) u8 {
        const idx = self.len;
        self.len -= 1;
        return self.str[idx];
    }

    pub fn take(self: *Line) []const u8 {
        const len = self.len;
        self.len = 0;
        return self.str[0..len];
    }
};

const History = struct {
    const nb_history = 1000;

    history: [nb_history]Line = @splat(.{}),
    head: usize = 0,

    // fn add(self: *History, line: Line) void {
    //     const next = (self.head + 1) % nb_history;
    //
    //     self.history[self.head] = line;
    //     self.head = next;
    // }

    fn currLine(self: *History) *Line {
        return &self.history[self.head];
    }
};

const Command = struct {
    name: []const u8,
    help: []const u8,
    run: *const fn (args: []const u8, term: *terminal.Terminal) void,
};

const commands = [_]Command{
    .{ .name = "clear", .help = "clear the screen", .run = cmdClear },
    .{ .name = "echo", .help = "display a line of text", .run = cmdEcho },
    .{ .name = "help", .help = "show all commands", .run = cmdHelp },
};

fn cmdEcho(args: []const u8, term: *terminal.Terminal) void {
    term.print("{s}\n", .{args});
}

fn cmdClear(_: []const u8, term: *terminal.Terminal) void {
    term.clear();
}

fn cmdHelp(_: []const u8, term: *terminal.Terminal) void {
    for (commands) |c|
        term.print("{s}\t{s}\n", .{ c.name, c.help });
}

pub const Shell = struct {
    history: History = undefined,
    term: *terminal.Terminal = undefined,

    pub fn init(term: *terminal.Terminal) Shell {
        // il faut faire en sorte que quand j'init tous les shell ca print pas partout.
        // je pense que ya que le multiplexer qui flush et personne d'autre

        const self: Shell = .{ .history = .{}, .term = term };
        self.prompt();

        return self;
    }

    pub fn receveKey(self: *Shell, key: input.Key) void {
        const curr_line = self.history.currLine();
        switch (key) {
            .char => |c| curr_line.append(c),
            .backspace => _ = curr_line.pop(),
            .enter => {
                const cmd_line = curr_line.take();
                self.execute(cmd_line);
                // self.history.add(curr_line);
                self.prompt();
            },
            else => {},
        }
    }

    fn prompt(self: *const Shell) void {
        self.term.write("> ");
    }

    fn execute(self: *Shell, line: []const u8) void {
        const trimmed = std.mem.trim(u8, line, " ");
        if (trimmed.len == 0) return;

        // sépare le nom de la commande et ses arguments
        var it = std.mem.tokenizeScalar(u8, trimmed, ' ');
        const name = it.next().?;
        const args = std.mem.trim(u8, trimmed[name.len..], " ");

        for (commands) |c| {
            if (std.mem.eql(u8, c.name, name)) {
                c.run(args, self.term);
                return;
            }
        }
        self.term.print("command not found: {s}\n", .{name});
    }
};
