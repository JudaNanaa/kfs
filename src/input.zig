pub const Key = union(enum) {
    char: u8,
    backspace,
    enter,
    fkey: u8, // F1..F12, ou Alt+n
};

var buf: [128]Key = undefined;
var head: usize = 0;
var tail: usize = 0;

pub fn push(k: Key) void {
    const next = (head + 1) % buf.len;
    if (next == tail) return; // plein : on jette
    buf[head] = k;
    head = next;
}

pub fn pop() ?Key {
    if (tail == head) return null;
    const k = buf[tail];
    tail = (tail + 1) % buf.len;
    return k;
}

const BACKSPACE_CODE = 8;
const ENTER_CODE = 10;

/// TODO: mettre les fkey en place
pub fn charToKey(c: u8) Key {
    return switch (c) {
        BACKSPACE_CODE => Key.backspace,
        ENTER_CODE => Key.enter,
        else => .{ .char = c },
    };
}
