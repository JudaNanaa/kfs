pub const Key = union(enum) {
    char: u8,
    backspace,
    enter,
    escape,
    up,
    down,
    left,
    right,
    /// F1..F12, ou Alt+n
    fkey: u8,
};

var buf: [128]Key = undefined;
var head: usize = 0;
var tail: usize = 0;

pub fn push(k: Key) void {
    const next = (head + 1) % buf.len;
    if (next == tail) return;
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

const testing = @import("std").testing;

fn reset() void {
    head = 0;
    tail = 0;
}

test "input: pop on an empty queue returns null" {
    reset();
    try testing.expectEqual(@as(?Key, null), pop());
}

test "input: keys come out in the order they went in" {
    reset();
    push(.{ .char = 'a' });
    push(.enter);
    push(.{ .fkey = 3 });
    try testing.expectEqual(Key{ .char = 'a' }, pop().?);
    try testing.expectEqual(Key.enter, pop().?);
    try testing.expectEqual(Key{ .fkey = 3 }, pop().?);
    try testing.expectEqual(@as(?Key, null), pop());
}

test "input: a full queue drops new keys and keeps the old ones" {
    reset();
    // one slot always stays free to tell "full" from "empty"
    for (0..buf.len - 1) |i| push(.{ .char = @intCast(i) });
    push(.escape);
    for (0..buf.len - 1) |i| {
        try testing.expectEqual(Key{ .char = @intCast(i) }, pop().?);
    }
    try testing.expectEqual(@as(?Key, null), pop());
}

test "input: indices wrap around the buffer" {
    reset();
    for (0..buf.len * 3) |i| {
        push(.{ .char = @truncate(i) });
        try testing.expectEqual(Key{ .char = @truncate(i) }, pop().?);
    }
}

test "input: charToKey maps control codes" {
    try testing.expectEqual(Key.backspace, charToKey(8));
    try testing.expectEqual(Key.enter, charToKey('\n'));
    try testing.expectEqual(Key{ .char = 'x' }, charToKey('x'));
}
