const vga = @import("drivers/vga.zig");

const row = vga.height - 1;

const Style = struct { fg: vga.Color, bg: vga.Color };

const base: Style = .{ .fg = .black, .bg = .light_grey };

const active: Style = .{ .fg = .white, .bg = .blue };

const mode_st: Style = .{ .fg = .white, .bg = .red };

fn put(buf: *[vga.width]vga.Entry, x: *usize, text: []const u8, s: Style) void {
    for (text) |c| {
        if (x.* >= vga.width) return;
        buf[x.*] = vga.Entry.init(c, s.fg, s.bg);
        x.* += 1;
    }
}

pub fn draw(current: usize, count: usize, mode: []const u8, hints: []const u8) void {
    var buf = @as([vga.width]vga.Entry, @splat(vga.Entry.init(' ', base.fg, base.bg)));
    var x: usize = 0;

    // bloc mode, façon vim : "-- INSERT --"
    put(&buf, &x, mode, mode_st);

    // onglets TTY façon tmux : [1] 2 3 4
    for (0..count) |i| {
        const s = if (i == current) active else base;
        put(&buf, &x, " ", s);
        put(&buf, &x, &.{'1' + @as(u8, @intCast(i))}, s);
        put(&buf, &x, " ", s);
    }

    // hints alignés à droite
    var hx = vga.width -| hints.len;
    for (hints) |c| {
        buf[hx] = vga.Entry.init(c, base.fg, base.bg);
        hx += 1;
    }

    vga.blitRow(row, &buf);
}

pub fn clear() void {
    const blank = vga.Entry.init(' ', .black, .black);
    vga.blitRow(row, &@as([vga.width]vga.Entry, @splat(blank)));
}
