const Line = @import("line.zig").Line;
const std = @import("std");

pub const History = struct {
    const capacity = 32;

    lines: [capacity]Line = @splat(.{}),
    head: usize = 0,
    len: usize = 0,

    pub fn push(self: *History, s: []const u8) void {
        self.lines[self.head].change(s);
        self.head = (self.head + 1) % capacity;
        if (self.len < capacity) self.len += 1;
    }

    pub fn get(self: *const History, back: usize) ?[]const u8 {
        if (back == 0 or back > self.len) return null;
        const l = &self.lines[(self.head + capacity - back) % capacity];
        return l.str[0..l.len];
    }
};

const testing = std.testing;

test "History: empty history returns nothing" {
    const h: History = .{};
    try testing.expectEqual(@as(?[]const u8, null), h.get(0));
    try testing.expectEqual(@as(?[]const u8, null), h.get(1));
}

test "History: get(1) is the most recent command" {
    var h: History = .{};
    h.push("first");
    h.push("second");
    try testing.expectEqualStrings("second", h.get(1).?);
    try testing.expectEqualStrings("first", h.get(2).?);
    try testing.expectEqual(@as(?[]const u8, null), h.get(3));
}

test "History: oldest entries are overwritten once full" {
    var h: History = .{};
    var buf: [8]u8 = undefined;
    for (0..History.capacity + 1) |i| {
        h.push(try std.fmt.bufPrint(&buf, "cmd{}", .{i}));
    }
    try testing.expectEqual(History.capacity, h.len);
    try testing.expectEqualStrings("cmd32", h.get(1).?);
    try testing.expectEqualStrings("cmd1", h.get(History.capacity).?);
    try testing.expectEqual(@as(?[]const u8, null), h.get(History.capacity + 1));
}

test "History: a reused slot does not keep its old content" {
    var h: History = .{};
    h.push("a very long command");
    for (0..History.capacity) |_| h.push("ls");
    try testing.expectEqualStrings("ls", h.get(History.capacity).?);
}
