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
    const history = 128;
    const visible = vga.width * vga.height;

    cells: [vga.width * history]vga.Entry = undefined,
    /// First visible line
    top: usize = 0,
    cursor: Cursor = .{},
    fg: vga.Color = .white,
    bg: vga.Color = .black,
    dirty_rows: u32 = 0xFFFFFFFF,

    pub fn init() Terminal {
        var self: Terminal = .{
            .cells = undefined,
        };
        @memset(&self.cells, vga.Entry.init(' ', self.fg, self.bg));
        return self;
    }

    fn view(self: *Terminal) *[visible]vga.Entry {
        return self.cells[self.top * vga.width ..][0..visible];
    }

    pub fn clear(self: *Terminal) void {
        @memset(&self.cells, vga.Entry.init(' ', self.fg, self.bg));
        self.top = 0;
        self.cursor = .{};
        self.markAllDirty();
        self.flush();
    }

    pub fn newline(self: *Terminal) void {
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
        self.markAllDirty();
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
        self.markDirty(self.cursor.row);
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
                self.view()[i] = vga.Entry.init(c, fg, bg);
                self.cursor.col += 1;
                if (self.cursor.col == vga.width)
                    self.newline();
                self.markDirty(self.cursor.row);
            },
        }
    }

    fn markDirty(self: *Terminal, row: usize) void {
        self.dirty_rows |= @as(u32, 1) << @intCast(row);
    }

    fn markAllDirty(self: *Terminal) void {
        self.dirty_rows = std.math.maxInt(u32);
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
        const _view = self.view();
        for (0..vga.height) |row| {
            const mask = @as(u32, 1) << @intCast(row);
            if (self.dirty_rows & mask != 0) {
                // tranche de 80 entrées à partir de l'offset de la ligne
                vga.blitRow(row, _view[row * vga.width ..][0..vga.width]);
            }
        }
        self.dirty_rows = 0;
        self.cursor.sync();
    }
};
