const std = @import("std");
const vga = @import("drivers/vga.zig");

pub const Terminal = struct {
    cells: [vga.width * vga.height]vga.Entry = undefined,
    row: usize = 0,
    col: usize = 0,
    fg: vga.Color = .light_grey,
    bg: vga.Color = .black,

    pub fn init(self: *Terminal) void {
        self.row = 0;
        self.col = 0;
        self.clear();
    }

    pub fn clear(self: *Terminal) void {
        const blank = vga.Entry.init(' ', self.fg, self.bg);
        for (&self.cells) |*c| c.* = blank;
        self.row = 0;
        self.col = 0;
    }

    pub fn putChar(self: *Terminal, c: u8) void {
        switch (c) {
            '\n' => self.newline(),
            '\r' => self.col = 0,
            else => {
                self.cells[self.row * vga.width + self.col] =
                    vga.Entry.init(c, self.fg, self.bg);
                self.col += 1;
                if (self.col == vga.width) self.newline();
            },
        }
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
        for (self.cells[w * (vga.height - 1) ..]) |*c| c.* = blank;
    }

    pub fn write(self: *Terminal, s: []const u8) void {
        for (s) |c| self.putChar(c);
    }

    pub fn print(self: *Terminal, comptime fmt: []const u8, args: anytype) void {
        var buf: [256]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, fmt, args) catch "<fmt overflow>";
        self.write(s);
    }

    pub fn flush(self: *const Terminal) void {
        vga.blit(&self.cells);
        vga.setCursor(self.col, self.row);
    }
};
