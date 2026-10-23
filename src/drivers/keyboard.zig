const io = @import("../arch/x86/io.zig");
const vga = @import("vga.zig");

const terminal = @import("../console/terminal.zig");
const input = @import("../input.zig");

pub const IRQ = 1;

const KBD_DATA: u16 = 0x60;

const SC_LSHIFT = 0x2A;
const SC_RSHIFT = 0x36;
const SC_CAPS = 0x3A;

const keymap = [_]u8{
    0,    27,  '1', '2', '3', '4', '5', '6', '7', '8', '9',  '0', '-', '=',  8,
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p',  '[', ']', '\n', 0,
    'a',  's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 0,   '\\', 'z',
    'x',  'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,   '*',  0,   ' ',
};
const keymap_shift = [_]u8{
    0,    27,  '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+',  8,
    '\t', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n', 0,
    'A',  'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0,   '|',  'Z',
    'X',  'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0,   '*', 0,   ' ',
};

comptime {
    if (keymap.len != keymap_shift.len)
        @compileError("keymap and keymap_shift must have the same length");
}

var lshift: bool = false;
var rshift: bool = false;
var caps_lock: bool = false;
var extended: bool = false;

fn translate(scancode: u8) u8 {
    if (scancode >= keymap.len) return 0;

    const base = keymap[scancode];
    const shifted = lshift or rshift;
    const is_letter = base >= 'a' and base <= 'z';

    const upper = if (is_letter) shifted != caps_lock else shifted;
    return if (upper) keymap_shift[scancode] else base;
}

const SC_F1 = 0x3B;
const SC_F10 = 0x44;
const SC_LALT = 0x38;
const SC_ESC = 0x01;
const SC_UP: u8 = 0x48;
const SC_DOWN: u8 = 0x50;
const SC_LEFT: u8 = 0x4B;
const SC_RIGHT: u8 = 0x4D;

pub fn handler() void {
    const data = io.inb(KBD_DATA);

    if (data == 0xE0) {
        extended = true;
        return;
    }
    if (extended) {
        extended = false;

        const ext_break = data & 0x80 != 0;
        const ext_code = data & 0x7F;
        if (ext_break) return;

        switch (ext_code) {
            SC_UP => input.push(.up),
            SC_DOWN => input.push(.down),
            SC_LEFT => input.push(.left),
            SC_RIGHT => input.push(.right),
            else => {},
        }
        return;
    }

    const is_break = data & 0x80 != 0;
    const scancode = data & 0x7F;

    switch (scancode) {
        SC_LSHIFT => lshift = !is_break,
        SC_RSHIFT => rshift = !is_break,
        SC_CAPS => if (!is_break) {
            caps_lock = !caps_lock;
        },
        SC_F1...SC_F10 => if (!is_break) {
            input.push(.{ .fkey = scancode - SC_F1 });
        },
        SC_ESC => if (!is_break) {
            input.push(.escape);
        },
        else => if (!is_break) {
            const c = translate(scancode);
            if (c != 0) {
                const key = input.charToKey(c);
                input.push(key);
            }
        },
    }
}

const testing = @import("std").testing;

fn resetModifiers() void {
    lshift = false;
    rshift = false;
    caps_lock = false;
}

const SC_A = 0x1E;
const SC_1 = 0x02;

test "keyboard: plain keys" {
    resetModifiers();
    try testing.expectEqual(@as(u8, 'a'), translate(SC_A));
    try testing.expectEqual(@as(u8, '1'), translate(SC_1));
    try testing.expectEqual(@as(u8, ' '), translate(0x39));
}

test "keyboard: either shift gives the shifted character" {
    resetModifiers();
    lshift = true;
    try testing.expectEqual(@as(u8, 'A'), translate(SC_A));
    try testing.expectEqual(@as(u8, '!'), translate(SC_1));
    lshift = false;
    rshift = true;
    try testing.expectEqual(@as(u8, 'A'), translate(SC_A));
}

test "keyboard: caps lock only affects letters" {
    resetModifiers();
    caps_lock = true;
    try testing.expectEqual(@as(u8, 'A'), translate(SC_A));
    try testing.expectEqual(@as(u8, '1'), translate(SC_1));
}

test "keyboard: shift cancels caps lock on letters" {
    resetModifiers();
    caps_lock = true;
    lshift = true;
    try testing.expectEqual(@as(u8, 'a'), translate(SC_A));
    try testing.expectEqual(@as(u8, '!'), translate(SC_1));
}

test "keyboard: unknown scancodes translate to 0" {
    resetModifiers();
    try testing.expectEqual(@as(u8, 0), translate(keymap.len));
    try testing.expectEqual(@as(u8, 0), translate(0x7F));
    try testing.expectEqual(@as(u8, 0), translate(SC_LSHIFT));
}
