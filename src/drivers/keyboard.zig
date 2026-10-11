const io = @import("../arch/x86/io.zig");
const vga = @import("vga.zig");

const debug = @import("../debug.zig");
const terminal = @import("../terminal.zig");

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

// var ok: u32 = 0;

pub fn handler() void {
    _ = io.inb(KBD_DATA);
    // debug.putStr(0, ok, "je suis dans keyboard.handler\n");
    // ok += 1;
    const t = terminal.active();
    t.putChar('A');
    return;

    // const data = io.inb(KBD_DATA);
    //
    // if (data == 0xE0) {
    //     extended = true;
    //     return;
    // }
    // if (extended) {
    //     extended = false;
    //     return;
    // }
    //
    // const is_break = data & 0x80 != 0;
    // const scancode = data & 0x7F;
    //
    // switch (scancode) {
    //     SC_LSHIFT => lshift = !is_break,
    //     SC_RSHIFT => rshift = !is_break,
    //     SC_CAPS => if (!is_break) {
    //         caps_lock = !caps_lock;
    //     },
    //     else => if (!is_break) {
    //         const c = translate(scancode);
    //         if (c != 0) {
    //             const t = terminal.active();
    //             t.putChar(c);
    //             t.flush();
    //         }
    //     },
    // }
}

fn putStr(x: usize, y: usize, s: []const u8) void {
    for (s, 0..) |c, i| vga.write(x + i, y, vga.Entry.init(c, .white, .red));
}
