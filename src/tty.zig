const input = @import("input.zig");
const terminal = @import("terminal.zig");
const shell = @import("shell.zig");
const std = @import("std");

const serial = @import("drivers/serial.zig");

pub const Line = struct {
    str: [256]u8 = undefined,
    len: usize = 0,
    cap: usize = 256,

    pub fn insert(self: *Line, idx: usize, c: u8) void {
        serial.print("je suis dans insert\n", .{});
        serial.print("idx == {}", .{idx});
        serial.print("self.cap == {}", .{self.cap});
        serial.print("self.len == {}", .{self.len});
        if (idx >= self.cap or idx > self.len) return;

        if (idx == self.len) {
            self.append(c);
        } else {
            @memmove(self.str[idx + 1 .. self.cap], self.str[idx .. self.cap - 1]);
            self.str[idx] = c;
            self.len += 1;
        }

        serial.print("str == {s}\n", .{self.str[0..self.len]});
    }

    pub fn remove(self: *Line, idx: usize) ?u8 {
        if (idx == 0) return null;
        if (idx >= self.cap or idx > self.len) return null;

        if (idx == self.len) {
            return self.pop();
        }

        const c = self.str[idx];
        @memmove(self.str[idx - 1 .. self.cap - 1], self.str[idx..self.cap]);

        self.len -= 1;

        return c;
    }

    pub fn change(self: *Line, str: []const u8) void {
        @memcpy(self.str[0..], str);
        self.len = str.len;
    }

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

    pub fn get(self: *Line) []const u8 {
        const len = self.len;
        return self.str[0..len];
    }

    fn isEmpty(self: *Line) bool {
        return std.mem.trim(u8, self.str[0..self.len], " \t").len == 0;
    }
};

const History = struct {
    const capacity = 32;

    lines: [capacity]Line = @splat(.{}),
    head: usize = 0,
    len: usize = 0,

    fn addHistory(self: *History) void {
        self.head = (self.head + 1) % capacity;
        self.len += 1;
    }

    fn get(self: *const History, back: usize) ?*const Line {
        serial.print("back == {}", .{back});
        if (back == 0 or back > self.len) return null;
        return &self.lines[(self.head - back) % self.len];
    }

    fn currentLine(self: *History) *Line {
        return &self.lines[self.head];
    }
};

pub const TTY = struct {
    const PROMPT = "> ";

    term: terminal.Terminal,
    history: History = .{},
    line: *Line = undefined,
    line_index: usize = 0,
    browsing: usize = 0,
    shell: shell.Shell,

    pub fn init(self: *TTY) void {
        self.term = .init();
        self.history = .{};
        self.line = self.history.currentLine();
        self.browsing = 0;
        self.line_index = 0;
        self.shell = .init(self);
        self.prompt();
    }

    pub fn receveKey(self: *TTY, key: input.Key) void {
        switch (key) {
            .char => |c| {
                self.browsing = 0;
                self.line.insert(self.line_index, c);
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
                    serial.print("je vais faire addHistory\n", .{});
                    const cmd = self.line.get();
                    self.shell.execute(cmd);
                    self.history.addHistory();
                    self.line = self.history.currentLine();
                }
                self.browsing = 0;
                self.line_index = 0;
                self.prompt();
            },
            .left => {
                if (self.line_index == 0) return;

                self.line_index -= 1;
                self.term.cursor.col -= 1;
                self.updateCursor();
            },
            .right => {
                if (self.line_index >= self.line.len) return;

                self.line_index += 1;
                self.term.cursor.col += 1;
                self.updateCursor();
            },
            .up => {
                serial.print("je suis dans le up0\n", .{});
                if (self.history.get(self.browsing + 1)) |line| {
                    serial.print("je suis dans le up1\n", .{});
                    self.browsing += 1;
                    self.line.change(&line.str);
                }
            },
            else => {},
        }
    }

    pub fn scroll(self: *TTY, direction: terminal.Terminal.ScrollDirection) void {
        self.term.scroll(direction);
    }

    pub fn goToBottom(self: *TTY) void {
        self.term.goToBottom();
    }

    pub fn updateCursor(self: *TTY) void {
        self.term.updateCursor();
    }

    pub fn showCursor(self: *TTY) void {
        self.term.showCursor();
    }

    pub fn hideCursor(self: *TTY) void {
        self.term.hideCursor();
    }

    pub fn prompt(self: *TTY) void {
        return self.write(PROMPT);
    }

    pub fn forceFlush(self: *TTY) void {
        self.term.forceFlush();
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
