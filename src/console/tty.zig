const input = @import("../input.zig");
const terminal = @import("terminal.zig");
const shell = @import("../shell.zig");
const std = @import("std");
const History = @import("history.zig").History;
const Line = @import("line.zig").Line;

pub const TTY = struct {
    const PROMPT = "> ";

    term: terminal.Terminal,
    history: History = .{},
    line: Line = .{},
    draft: Line = .{},
    line_index: usize = 0,
    browsing: usize = 0,
    shell: shell.Shell,

    pub fn init(self: *TTY) void {
        self.term = .init();
        self.history = .{};
        self.line = .{};
        self.draft = .{};
        self.browsing = 0;
        self.line_index = 0;
        self.shell = .init(self);
        self.prompt();
    }

    pub fn receveKey(self: *TTY, key: input.Key) void {
        switch (key) {
            .char => |c| {
                self.browsing = 0;
                if (!self.line.insert(self.line_index, c)) return;
                self.line_index += 1;
                self.term.putChar(c);
            },
            .backspace => {
                self.browsing = 0;
                if (self.line.remove(self.line_index) != null) {
                    self.line_index -= 1;
                    self.term.backspace();
                }
            },
            .enter => {
                self.term.newline();
                if (!self.line.isEmpty()) {
                    self.history.push(self.line.get());
                    self.shell.execute(self.line.get());
                }
                self.line.len = 0;
                self.line_index = 0;
                self.browsing = 0;
                self.prompt();
            },
            .left => {
                if (self.line_index == 0) return;

                self.line_index -= 1;
                self.term.cursor.moveLeft() catch unreachable;
            },
            .right => {
                if (self.line_index >= self.line.len) return;

                self.line_index += 1;
                self.term.cursor.moveRight() catch unreachable;
            },
            .up => {
                const entry = self.history.get(self.browsing + 1) orelse return;
                if (self.browsing == 0) self.draft.change(self.line.get());
                self.browsing += 1;
                self.replaceLine(entry);
            },
            .down => {
                if (self.browsing == 0) return;
                self.browsing -= 1;
                const entry = if (self.browsing == 0) self.draft.get() else self.history.get(self.browsing).?;
                self.replaceLine(entry);
            },
            else => {},
        }
    }

    fn replaceLine(self: *TTY, new: []const u8) void {
        while (self.line_index < self.line.len) : (self.line_index += 1)
            self.term.cursor.moveRight() catch unreachable;
        while (self.line_index > 0) : (self.line_index -= 1)
            self.term.backspace();
        self.line.change(new);
        self.term.write(new);
        self.line_index = self.line.len;
    }

    pub fn scroll(self: *TTY, direction: terminal.Terminal.ScrollDirection) void {
        self.term.scroll(direction);
    }

    pub fn goToBottom(self: *TTY) void {
        self.term.goToBottom();
    }

    pub fn prompt(self: *TTY) void {
        return self.write(PROMPT);
    }

    pub fn write(self: *TTY, s: []const u8) void {
        self.term.write(s);
    }

    pub fn print(self: *TTY, comptime fnt: []const u8, args: anytype) void {
        self.term.print(fnt, args);
    }

    pub fn printk(self: *TTY, comptime fnt: []const u8, args: anytype) void {
        self.term.printk(fnt, args);
    }

    pub fn clear(self: *TTY) void {
        self.term.clear();
    }
};
