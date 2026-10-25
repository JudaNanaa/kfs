const std = @import("std");
const vga = @import("../drivers/vga.zig");

const Cursor = struct {
    idx: usize,
    len_row: usize,
    nb_rows: usize,

    const CursorError = error{
        CantMoveRight,
        CantMoveLeft,
        CantJumpUp,
        CantJumpDown,
        CantJumpNewline,
    };

    fn init(index: usize, len_row: usize, nb_rows: usize) Cursor {
        return .{ .idx = index, .len_row = len_row, .nb_rows = nb_rows };
    }

    fn reset(self: *Cursor) void {
        self.idx = 0;
    }

    fn row(self: *const Cursor) usize {
        return self.idx / self.len_row;
    }

    fn col(self: *const Cursor) usize {
        return self.idx % self.len_row;
    }

    fn max(self: *const Cursor) usize {
        return self.len_row * self.nb_rows;
    }

    pub fn moveRight(self: *Cursor) CursorError!void {
        if (self.idx + 1 >= self.max()) return CursorError.CantMoveRight;

        self.idx += 1;
    }

    pub fn moveLeft(self: *Cursor) CursorError!void {
        if (self.idx == 0) return CursorError.CantMoveLeft;

        self.idx -= 1;
    }

    fn jumpUp(self: *Cursor) CursorError!void {
        if (self.idx < self.len_row) return CursorError.CantJumpUp;

        self.idx -= self.len_row;
    }

    fn jumpDown(self: *Cursor) CursorError!void {
        if (self.idx >= self.max() - self.len_row) return CursorError.CantJumpDown;

        self.idx += self.len_row;
    }

    fn jumpNewline(self: *Cursor) CursorError!void {
        if (self.row() + 1 >= self.nb_rows) return CursorError.CantJumpNewline;

        self.idx = (self.row() + 1) * self.len_row;
    }

    fn carriageReturn(self: *Cursor) void {
        self.idx = self.row() * self.len_row;
    }
};

pub const Terminal = struct {
    const history = 128;
    pub const text_height = vga.height - 1;
    const visible = vga.width * text_height;

    cells: [vga.width * history]vga.Entry = undefined,
    /// First visible line
    top: usize = 0,
    bottom: usize = 0,
    cursor: Cursor,
    fg: vga.Color = .white,
    bg: vga.Color = .black,

    pub fn init() Terminal {
        var self: Terminal = .{
            .cells = undefined,
            .cursor = .init(0, vga.width, text_height),
        };

        @memset(&self.cells, vga.Entry.init(' ', self.fg, self.bg));
        return self;
    }

    pub const Pos = struct { x: usize, y: usize };

    /// The rows currently on screen, for whoever draws them.
    pub fn visibleCells(self: *const Terminal) *const [visible]vga.Entry {
        return self.cells[self.top * vga.width ..][0..visible];
    }

    pub fn cursorPos(self: *const Terminal) Pos {
        return .{ .x = self.cursor.col(), .y = self.cursor.row() };
    }

    fn view(self: *Terminal) *[visible]vga.Entry {
        return self.cells[self.top * vga.width ..][0..visible];
    }

    pub fn clear(self: *Terminal) void {
        @memset(&self.cells, vga.Entry.init(' ', self.fg, self.bg));
        self.top = 0;
        self.bottom = 0;
        self.cursor.reset();
    }

    fn scrollContent(self: *Terminal) void {
        if (self.top + text_height < history) {
            self.top += 1;
        } else {
            @memmove(self.cells[0 .. vga.width * (history - 1)], self.cells[vga.width..]);
        }
        const blank = vga.Entry.init(' ', self.fg, self.bg);
        @memset(self.view()[vga.width * (text_height - 1) ..], blank);
    }

    pub fn newline(self: *Terminal) void {
        self.cursor.jumpNewline() catch {
            self.scrollContent();
            self.cursor.carriageReturn();
        };
        self.bottom = @max(self.bottom, self.top + self.cursor.row());
    }

    pub fn backspace(self: *Terminal) void {
        self.cursor.moveLeft() catch return;

        const idx = self.top * vga.width + self.cursor.row() * vga.width + self.cursor.col();
        self.cells[idx] = vga.Entry.init(' ', self.fg, self.bg);
    }

    pub fn goToBottom(self: *Terminal) void {
        if (self.bottom < text_height) {
            self.top = 0;
        } else {
            self.top = self.bottom - text_height + 1;
        }
    }

    pub fn putCharColor(self: *Terminal, c: u8, fg: vga.Color, bg: vga.Color) void {
        switch (c) {
            '\n' => self.newline(),
            '\r' => self.cursor.carriageReturn(),
            8 => self.backspace(),
            '\t' => {
                const n = 8 - (self.cursor.col() % 8);
                for (0..n) |_|
                    self.putCharColor(' ', fg, bg);
            },
            else => {
                const i = self.top * vga.width + self.cursor.row() * vga.width + self.cursor.col();
                self.cells[i] = vga.Entry.init(c, fg, bg);

                self.cursor.moveRight() catch self.newline();
            },
        }
    }

    pub const ScrollDirection = enum {
        up,
        down,
    };

    pub fn scroll(self: *Terminal, direction: ScrollDirection) void {
        switch (direction) {
            .up => {
                if (self.top == 0) return;
                self.top -= 1;
            },
            .down => {
                if (self.top + text_height - 1 >= self.bottom) return;
                self.top += 1;
            },
        }
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
        var buf: [1024]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, fmt, args) catch "<fmt overflow>";
        self.write(s);
    }

    pub fn printk(self: *Terminal, comptime fmt: []const u8, args: anytype) void {
        var buf: [1024]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, fmt, args) catch "<fmt overflow>";
        self.writeColor(s, .white, .red);
    }
};

const testing = std.testing;

test "Terminal: characters are written at the cursor" {
    var t = Terminal.init();
    t.write("hi");
    try testing.expectEqual(@as(u8, 'h'), t.cells[0].char);
    try testing.expectEqual(@as(u8, 'i'), t.cells[1].char);
    try testing.expectEqual(Terminal.Pos{ .x = 2, .y = 0 }, t.cursorPos());
}

test "Terminal: newline moves to the start of the next row" {
    var t = Terminal.init();
    t.write("abc\n");
    try testing.expectEqual(Terminal.Pos{ .x = 0, .y = 1 }, t.cursorPos());
}

test "Terminal: backspace removes the previous character" {
    var t = Terminal.init();
    t.write("ab");
    t.backspace();
    try testing.expectEqual(@as(u8, ' '), t.cells[1].char);
    try testing.expectEqual(Terminal.Pos{ .x = 1, .y = 0 }, t.cursorPos());
}

test "Terminal: the view scrolls when the screen is full" {
    var t = Terminal.init();
    for (0..Terminal.text_height) |_| t.newline();
    try testing.expectEqual(@as(usize, 1), t.top);
    try testing.expectEqual(Terminal.text_height - 1, t.cursorPos().y);
}

test "Terminal: scroll up then goToBottom returns to the latest line" {
    var t = Terminal.init();
    for (0..Terminal.text_height + 5) |_| t.newline();
    const bottom_top = t.top;
    t.scroll(.up);
    t.scroll(.up);
    try testing.expectEqual(bottom_top - 2, t.top);
    t.goToBottom();
    try testing.expectEqual(bottom_top, t.top);
}
