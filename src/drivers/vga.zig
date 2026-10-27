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
var shadow: [width * height]Entry = undefined;

fn put(idx: usize, entry: Entry) void {
    if (@as(u16, @bitCast(shadow[idx])) == @as(u16, @bitCast(entry))) return;
    shadow[idx] = entry;
    mmio[idx] = entry;
}

pub fn init() void {
    const blank = Entry.init(' ', .white, .black);
    for (0..width * height) |i| {
        shadow[i] = blank;
        mmio[i] = blank;
    }
}

pub fn write(x: usize, y: usize, entry: Entry) void {
    put(y * width + x, entry);
}

pub fn blitRow(row: usize, cells: *const [width]Entry) void {
    const base = row * width;
    for (cells, 0..) |e, i| put(base + i, e);
}

pub fn blit(cells: *const [width * (height - 1)]Entry) void {
    for (cells, 0..) |e, i| put(i, e);
}

const CRTC_INDEX: u16 = 0x3D4;
const CRTC_DATA: u16 = 0x3D5;

const REG_CURSOR_START = 0x0A;
const REG_CURSOR_END = 0x0B;
const REG_CURSOR_HIGH = 0x0E;
const REG_CURSOR_LOW = 0x0F;

fn writeReg(reg: u8, value: u8) void {
    io.outb(CRTC_INDEX, reg);
    io.outb(CRTC_DATA, value);
}

fn readReg(reg: u8) u8 {
    io.outb(CRTC_INDEX, reg);
    return io.inb(CRTC_DATA);
}

pub fn setCursor(x: usize, y: usize) void {
    const pos: u16 = @intCast(y * width + x);
    writeReg(REG_CURSOR_LOW, @truncate(pos));
    writeReg(REG_CURSOR_HIGH, @truncate(pos >> 8));
}

pub fn unsetCursor() void {
    writeReg(REG_CURSOR_START, 0x20);
}

pub fn enableCursor() void {
    writeReg(REG_CURSOR_START, (readReg(REG_CURSOR_START) & 0xC0) | 14);
    writeReg(REG_CURSOR_END, (readReg(REG_CURSOR_END) & 0xE0) | 15);
}
