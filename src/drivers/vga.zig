const io = @import("../arch/x86/io.zig");

pub const width = 80;
pub const height = 25;

pub const Color = enum(u4) {
    black,
    blue,
    green,
    cyan,
    red,
    magenta,
    brown,
    light_grey,
    dark_grey,
    light_blue,
    light_green,
    light_cyan,
    light_red,
    light_magenta,
    yellow,
    white,
};

pub const Entry = packed struct(u16) {
    char: u8,
    fg: Color,
    bg: Color,

    pub fn init(char: u8, fg: Color, bg: Color) Entry {
        return .{ .char = char, .fg = fg, .bg = bg };
    }
};

const mmio: [*]volatile Entry = @ptrFromInt(0xB8000);

pub fn write(x: usize, y: usize, entry: Entry) void {
    mmio[y * width + x] = entry;
}

pub fn blit(cells: *const [width * height]Entry) void {
    for (cells, 0..) |e, i| mmio[i] = e;
}

pub fn setCursor(x: usize, y: usize) void {
    const pos: u16 = @intCast(y * width + x);
    io.outb(0x3D4, 0x0F);
    io.outb(0x3D5, @truncate(pos));
    io.outb(0x3D4, 0x0E);
    io.outb(0x3D5, @truncate(pos >> 8));
}
