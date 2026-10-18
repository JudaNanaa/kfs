const input = @import("input.zig");
const terminal = @import("terminal.zig");
const shell = @import("shell.zig");
const std = @import("std");

pub const Line = struct {
    str: [256]u8 = undefined,
    len: usize = 0,
    cap: usize = 256,

    pub fn append(self: *Line, c: u8) void {
        self.str[self.len] = c;
        self.len += 1;
    }

    pub fn pop(self: *Line) ?u8 {
        if (self.len == 0)
            return null;
        self.len -= 1;
        const idx = self.len;
        return self.str[idx];
    }

    pub fn take(self: *Line) []const u8 {
        const len = self.len;
        self.len = 0;
        return self.str[0..len];
    }

    fn isEmpty(self: *Line) bool {
        return std.mem.trim(u8, self.str[0..self.len], " \t").len == 0;
    }
};

const History = struct {
    const capacity = 32;

    lines: [capacity]Line = undefined,
    head: usize = 0,
    len: usize = 0,

    fn push(self: *History, line: *const Line) void {
        self.lines[self.head] = line.*;
        self.head = (self.head + 1) % capacity;
        if (self.len < capacity) self.len += 1;
    }

    fn get(self: *const History, back: usize) ?*const Line {
        if (back == 0 or back > self.len) return null;
        return &self.lines[(self.head + capacity - back) % capacity];
    }
};

pub const TTY = struct {
    term: terminal.Terminal,
    history: History = .{},
    line: Line = .{},
    draft: Line = .{},
    browsing: usize = 0,
    shell: shell.Shell,

    pub fn init(self: *TTY) void {
        self.term = .init();
        self.history = .{};
        self.line = .{};
        self.draft = .{};
        self.browsing = 0;
        self.shell = .init(self);
        self.prompt();
    }

    pub fn receveKey(self: *TTY, key: input.Key) void {
        switch (key) {
            .char => |c| {
                self.browsing = 0;
                self.line.append(c);
                self.term.putChar(c);
            },
            .backspace => {
                self.browsing = 0;
                if (self.line.pop() != null) {
                    self.term.backspace();
                }
            },
            .enter => {
                self.term.newline();
                if (!self.line.isEmpty())
                    self.history.push(&self.line);
                const cmd = self.line.take();
                self.browsing = 0;
                self.shell.execute(cmd);
                self.prompt();
            },
            else => {},
        }
    }

    pub fn scroll(self: *TTY, direction: terminal.Terminal.ScrollDirection) void {
        self.term.scroll(direction);
    }

    pub fn prompt(self: *TTY) void {
        return self.write("> ");
    }

    pub fn flush(self: *TTY) void {
        self.term.flush();
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
