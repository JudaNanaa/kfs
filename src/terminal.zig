const std = @import("std");
const vga = @import("drivers/vga.zig");
const shell = @import("shell.zig");
const input = @import("input.zig");

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
    shell: shell.Shell = .{},
    /// First visible line
    top: usize = 0,
    cursor: Cursor = .{},
    fg: vga.Color = .white,
    bg: vga.Color = .black,

    pub fn init() Terminal {
        var self: Terminal = .{};
        @memset(&self.cells, vga.Entry.init(' ', self.fg, self.bg));
        self.shell = .init(&self);
        return self;
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
        self.flush();
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

    pub fn receveKey(self: *Terminal, key: input.Key) void {
        self.shell.receveKey(key);
    }
};
