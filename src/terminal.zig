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
    if (i >= count)
        return;
    current = i;
    terms[current].flush();
}

pub const Terminal = struct {
    cells: [vga.width * vga.height]vga.Entry = undefined,
    row: usize = 0,
    col: usize = 0,
    fg: vga.Color = .white,
    bg: vga.Color = .black,

    fn init(self: *Terminal) void {
        self.row = 0;
        self.col = 0;
        self.clear();
    }

    pub fn clear(self: *Terminal) void {
        const blank = vga.Entry.init(' ', self.fg, self.bg);
        @memset(&self.cells, blank);
        self.row = 0;
        self.col = 0;
    }

    pub fn putChar(self: *Terminal, c: u8) void {
        switch (c) {
            '\n' => self.newline(),
            '\r' => self.col = 0,
            8 => self.backspace(),
            '\t' => {
                const next = (self.col + 8) & ~@as(usize, 7);
                while (self.col < next and self.col < vga.width) self.putChar(' ');
            },
            else => {
                self.cells[self.row * vga.width + self.col] =
                    vga.Entry.init(c, self.fg, self.bg);
                self.col += 1;
                if (self.col == vga.width) self.newline();
            },
        }
        self.printk("je suis dans putchar\n", .{});
    }

    pub fn putCharColor(self: *Terminal, c: u8, fg: vga.Color, bg: vga.Color) void {
        switch (c) {
            '\n' => self.newline(),
            '\r' => self.col = 0,
            8 => self.backspace(),
            '\t' => {
                const next = (self.col + 8) & ~@as(usize, 7);
                while (self.col < next and self.col < vga.width) self.putChar(' ');
            },
            else => {
                self.cells[self.row * vga.width + self.col] =
                    vga.Entry.init(c, fg, bg);
                self.col += 1;
                if (self.col == vga.width) self.newline();
            },
        }
    }

    pub fn backspace(self: *Terminal) void {
        if (self.col > 0) {
            self.col -= 1;
        } else if (self.row > 0) {
            self.row -= 1;
            self.col = vga.width - 1;
        } else return;
        self.cells[self.row * vga.width + self.col] =
            vga.Entry.init(' ', self.fg, self.bg);
    }

    fn newline(self: *Terminal) void {
        self.col = 0;
        if (self.row + 1 < vga.height) {
            self.row += 1;
            return;
        }
        const w = vga.width;
        @memmove(self.cells[0 .. w * (vga.height - 1)], self.cells[w..]);
        const blank = vga.Entry.init(' ', self.fg, self.bg);
        @memset(self.cells[w * (vga.height - 1) ..], blank);
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
        self.flush();
    }

    pub fn flush(self: *const Terminal) void {
        vga.blit(&self.cells);
        vga.setCursor(self.col, self.row);
    }
};
