const std = @import("std");
const vga = @import("drivers/vga.zig");
const shell = @import("shell.zig");
const input = @import("input.zig");

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

    fn sync(self: *Cursor) void {
        vga.setCursor(self.col(), self.row());
    }

    fn hide(_: *Cursor) void {
        vga.unsetCursor();
    }

    fn show(self: *Cursor) void {
        vga.enableCursor();
        self.sync();
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
    dirty_rows: u32 = 0xFFFFFFFF,

    pub fn init() Terminal {
        var self: Terminal = .{
            .cells = undefined,
            .cursor = .init(0, vga.width, text_height),
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
        self.bottom = 0;
        self.cursor.reset();
        self.markAllDirty();
        self.flush();
    }

    pub fn updateCursor(self: *Terminal) void {
        self.cursor.sync();
    }

    pub fn showCursor(self: *Terminal) void {
        self.cursor.show();
    }

    pub fn hideCursor(self: *Terminal) void {
        self.cursor.hide();
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
        self.markAllDirty();
        self.flush();
    }

    pub fn backspace(self: *Terminal) void {
        self.cursor.moveLeft() catch return;

        const idx = self.top * vga.width + self.cursor.row() * vga.width + self.cursor.col();
        @memmove(self.cells[idx .. vga.width * history - 1], self.cells[idx + 1 ..]);

        self.cells[vga.width * history - 1] = vga.Entry.init(' ', self.fg, self.bg);

        self.markAllDirty();
    }

    pub fn goToBottom(self: *Terminal) void {
        if (self.bottom < text_height) {
            self.top = 0;
        } else {
            self.top = self.bottom - text_height + 1;
        }

        self.markAllDirty();
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

                @memmove(self.cells[i + 1 .. vga.width * history], self.cells[i .. vga.width * history - 1]);
                self.cells[i] = vga.Entry.init(c, fg, bg);

                self.cursor.moveRight() catch self.newline();
                self.markAllDirty();
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
        self.markAllDirty();
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

    pub fn forceFlush(self: *Terminal) void {
        vga.blit(self.view());
        self.dirty_rows = 0;
    }

    pub fn flush(self: *Terminal) void {
        const _view = self.view();
        for (0..text_height) |row| {
            const mask = @as(u32, 1) << @intCast(row);
            if (self.dirty_rows & mask != 0) {
                // tranche de 80 entrées à partir de l'offset de la ligne
                vga.blitRow(row, _view[row * vga.width ..][0..vga.width]);
            }
        }
        self.dirty_rows = 0;
        // self.cursor.sync();
    }
};
