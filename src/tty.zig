const input = @import("input.zig");
const terminal = @import("terminal.zig");
const shell = @import("shell.zig");
const std = @import("std");

pub const Line = struct {
    str: [256]u8 = undefined,
    len: usize = 0,
    cap: usize = 256,

    pub fn insert(self: *Line, idx: usize, c: u8) bool {
        if (self.len >= self.cap or idx > self.len) return false;

        @memmove(self.str[idx + 1 .. self.len + 1], self.str[idx..self.len]);
        self.str[idx] = c;
        self.len += 1;
        return true;
    }

    pub fn remove(self: *Line, idx: usize) ?u8 {
        if (idx == 0 or idx > self.len) return null;

        const c = self.str[idx - 1];
        @memmove(self.str[idx - 1 .. self.len - 1], self.str[idx..self.len]);
        self.len -= 1;
        return c;
    }

    pub fn change(self: *Line, str: []const u8) void {
        const n = @min(str.len, self.cap);
        @memcpy(self.str[0..n], str[0..n]);
        self.len = n;
    }

    pub fn append(self: *Line, c: u8) void {
        self.str[self.len] = c;
        self.len += 1;
    }

    fn pop(self: *Line) ?u8 {
        if (self.len == 0)
            return null;
        self.len -= 1;
        const idx = self.len;
        return self.str[idx];
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

    fn push(self: *History, s: []const u8) void {
        self.lines[self.head].change(s);
        self.head = (self.head + 1) % capacity;
        if (self.len < capacity) self.len += 1;
    }

    fn get(self: *const History, back: usize) ?[]const u8 {
        if (back == 0 or back > self.len) return null;
        const l = &self.lines[(self.head + capacity - back) % capacity];
        return l.str[0..l.len];
    }
};

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
                self.updateCursor();
            },
            .right => {
                if (self.line_index >= self.line.len) return;

                self.line_index += 1;
                self.term.cursor.moveRight() catch unreachable;
                self.updateCursor();
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

const testing = std.testing;

fn lineFrom(s: []const u8) Line {
    var l: Line = .{};
    l.change(s);
    return l;
}

test "Line: insert at the end, in the middle and at the start" {
    var l: Line = .{};
    try testing.expect(l.insert(0, 'b'));
    try testing.expect(l.insert(1, 'd'));
    try testing.expect(l.insert(1, 'c'));
    try testing.expect(l.insert(0, 'a'));
    try testing.expectEqualStrings("abcd", l.get());
}

test "Line: insert past the end is rejected" {
    var l = lineFrom("ab");
    try testing.expect(!l.insert(3, 'x'));
    try testing.expectEqualStrings("ab", l.get());
}

test "Line: insert into a full line is rejected" {
    var l: Line = .{};
    for (0..l.cap) |_| try testing.expect(l.insert(l.len, 'x'));
    try testing.expect(!l.insert(l.len, 'y'));
    try testing.expect(!l.insert(10, 'y'));
    try testing.expectEqual(l.cap, l.len);
}

test "Line: remove deletes the character left of the index" {
    var l = lineFrom("abc");
    try testing.expectEqual(@as(?u8, 'b'), l.remove(2));
    try testing.expectEqualStrings("ac", l.get());
    try testing.expectEqual(@as(?u8, 'c'), l.remove(2));
    try testing.expectEqual(@as(?u8, 'a'), l.remove(1));
    try testing.expectEqualStrings("", l.get());
}

test "Line: remove at index 0 or past the end does nothing" {
    var l = lineFrom("ab");
    try testing.expectEqual(@as(?u8, null), l.remove(0));
    try testing.expectEqual(@as(?u8, null), l.remove(3));
    try testing.expectEqualStrings("ab", l.get());
}

test "Line: remove works on a full line" {
    var l: Line = .{};
    for (0..l.cap) |_| _ = l.insert(l.len, 'x');
    try testing.expectEqual(@as(?u8, 'x'), l.remove(l.len));
    try testing.expectEqual(l.cap - 1, l.len);
}

test "Line: change truncates input longer than the capacity" {
    var l: Line = .{};
    l.change(&(@as([300]u8, @splat('z'))));
    try testing.expectEqual(l.cap, l.len);
}

test "Line: isEmpty ignores spaces and tabs" {
    var blank = lineFrom(" \t  ");
    var text = lineFrom("  ls ");
    try testing.expect(blank.isEmpty());
    try testing.expect(!text.isEmpty());
}

test "History: empty history returns nothing" {
    const h: History = .{};
    try testing.expectEqual(@as(?[]const u8, null), h.get(0));
    try testing.expectEqual(@as(?[]const u8, null), h.get(1));
}

test "History: get(1) is the most recent command" {
    var h: History = .{};
    h.push("first");
    h.push("second");
    try testing.expectEqualStrings("second", h.get(1).?);
    try testing.expectEqualStrings("first", h.get(2).?);
    try testing.expectEqual(@as(?[]const u8, null), h.get(3));
}

test "History: oldest entries are overwritten once full" {
    var h: History = .{};
    var buf: [8]u8 = undefined;
    for (0..History.capacity + 1) |i| {
        h.push(try std.fmt.bufPrint(&buf, "cmd{}", .{i}));
    }
    try testing.expectEqual(History.capacity, h.len);
    try testing.expectEqualStrings("cmd32", h.get(1).?);
    try testing.expectEqualStrings("cmd1", h.get(History.capacity).?);
    try testing.expectEqual(@as(?[]const u8, null), h.get(History.capacity + 1));
}

test "History: a reused slot does not keep its old content" {
    var h: History = .{};
    h.push("a very long command");
    for (0..History.capacity) |_| h.push("ls");
    try testing.expectEqualStrings("ls", h.get(History.capacity).?);
}
