const vga = @import("drivers/vga.zig");

pub fn putStr(x: usize, y: usize, s: []const u8) void {
    for (s, 0..) |c, i| vga.write(x + i, y, vga.Entry.init(c, .white, .red));
}
