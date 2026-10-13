const std = @import("std");
const vga = @import("drivers/vga.zig");

pub const count = 4;
var terms: [count]Terminal = undefined;
var current: usize = 0;

/// init all terminals
pub fn initAll() void {
    for (&terms) |*t|
        t.init();
    terms[current].flush();
}

/// get the active terminal
pub fn active() *Terminal {
    return &terms[current];
}

/// switch to the terminal ```i```
pub fn switchTo(i: usize) void {
    if (i >= count or i == current) return;
    current = i;
    terms[current].flush();
}

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

const Cursor = struct {
    row: usize = 0,
    col: usize = 0,

    fn init() Cursor {
        return .{ .row = 0, .col = 0 };
    }

    fn reset(self: *Cursor) void {
        self.col = 0;
        self.row = 0;
    }

    fn sync(self: *Cursor) void {
        vga.setCursor(self.col, self.row);
    }
};

pub const Terminal = struct {
    const history = 1000;
    const visible = vga.width * vga.height;

    cells: [vga.width * history]vga.Entry = undefined,
    line: Line = .{},
    /// First visible line
    top: usize = 0,
    cursor: Cursor = .{},
    fg: vga.Color = .white,
    bg: vga.Color = .black,

    pub fn init(self: *Terminal) void {
        self.top = 0;
        self.line = .{};
        self.cursor = .{};
        self.fg = .white;
        self.bg = .black;
        @memset(&self.cells, vga.Entry.init(' ', self.fg, self.bg));
    }

    fn isActive(self: *const Terminal) bool {
        return self == &terms[current];
    }

    fn view(self: *Terminal) *[visible]vga.Entry {
        return self.cells[self.top * vga.width ..][0..visible];
    }

    fn writeToVGA(self: *Terminal, entry: vga.Entry) void {
        vga.write(self.cursor.col, self.cursor.row, entry);
        self.cursor.sync();
    }

    pub fn clear(self: *Terminal) void {
        @memset(&self.cells, vga.Entry.init(' ', self.fg, self.bg));
        self.top = 0;
        self.cursor = .{};
        if (self.isActive())
            self.flush();
    }

    fn newline(self: *Terminal) void {
        self.cursor.col = 0;
        if (self.cursor.row + 1 < vga.height) {
            self.cursor.row += 1;
            return;
        }
        if (self.top + vga.height < history) {
            self.top += 1;
        } else {
            @memmove(self.cells[0 .. vga.width * (history - 1)], self.cells[vga.width..]);
        }
        const blank = vga.Entry.init(' ', self.fg, self.bg);
        @memset(self.view()[vga.width * (vga.height - 1) ..], blank);
        if (self.isActive()) self.flush();
    }

    pub fn backspace(self: *Terminal) void {
        if (self.cursor.col > 0) {
            self.cursor.col -= 1;
        } else if (self.cursor.row > 0) {
            self.cursor.row -= 1;
            self.cursor.col = vga.width - 1;
        } else return;
        const entry = vga.Entry.init(' ', self.fg, self.bg);
        self.view()[self.cursor.row * vga.width + self.cursor.col] = entry;
        if (self.isActive())
            self.writeToVGA(entry);
    }

    pub fn putCharColor(self: *Terminal, c: u8, fg: vga.Color, bg: vga.Color) void {
        switch (c) {
            '\n' => self.newline(),
            '\r' => self.cursor.col = 0,
            8 => self.backspace(),
            '\t' => {
                const n = 8 - (self.cursor.col % 8);
                for (0..n) |_|
                    self.putCharColor(' ', fg, bg);
            },
            else => {
                const i = self.cursor.row * vga.width + self.cursor.col;
                const entry = vga.Entry.init(c, fg, bg);
                self.view()[i] = entry;
                if (self.isActive())
                    self.writeToVGA(entry);

                self.cursor.col += 1;
                if (self.cursor.col == vga.width)
                    self.newline();
            },
        }
        self.cursor.sync();
    }

    pub fn putChar(self: *Terminal, c: u8) void {
        self.putCharColor(c, self.fg, self.bg);
    }

    pub fn write(self: *Terminal, s: []const u8) void {
        for (s) |c| self.putChar(c);
    }

    pub fn writeColor(self: *Terminal, s: []const u8, fg: vga.Color, bg: vga.Color) void {
        for (s) |c| self.putCharColor(c, fg, bg);
    }

    pub fn print(self: *Terminal, comptime fmt: []const u8, args: anytype) void {
        var buf: [256]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, fmt, args) catch "<fmt overflow>";
        self.write(s);
    }

    pub fn printk(self: *Terminal, comptime fmt: []const u8, args: anytype) void {
        var buf: [1024]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, fmt, args) catch "<fmt overflow>";
        self.writeColor(s, .white, .red);
    }

    pub fn flush(self: *Terminal) void {
        vga.blit(self.view());
        self.cursor.sync();
    }
};
