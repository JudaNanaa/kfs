const std = @import("std");

pub const Line = struct {
    str: [256]u8 = undefined,
    len: usize = 0,
    cap: usize = 256,

    pub fn insert(self: *Line, idx: usize, c: u8) bool {
        if (self.len >= self.cap or idx > self.len) return false;

        @memmove(self.str[idx + 1 .. self.len + 1], self.str[idx..self.len]);
        self.str[idx] = c;
        self.len += 1;
        return true;
    }

    pub fn remove(self: *Line, idx: usize) ?u8 {
        if (idx == 0 or idx > self.len) return null;

        const c = self.str[idx - 1];
        @memmove(self.str[idx - 1 .. self.len - 1], self.str[idx..self.len]);
        self.len -= 1;
        return c;
    }

    pub fn change(self: *Line, str: []const u8) void {
        const n = @min(str.len, self.cap);
        @memcpy(self.str[0..n], str[0..n]);
        self.len = n;
    }

    pub fn get(self: *Line) []const u8 {
        const len = self.len;
        return self.str[0..len];
    }

    pub fn isEmpty(self: *Line) bool {
        return std.mem.trim(u8, self.str[0..self.len], " \t").len == 0;
    }
};

const testing = std.testing;

fn lineFrom(s: []const u8) Line {
    var l: Line = .{};
    l.change(s);
    return l;
}

test "Line: insert at the end, in the middle and at the start" {
    var l: Line = .{};
    try testing.expect(l.insert(0, 'b'));
    try testing.expect(l.insert(1, 'd'));
    try testing.expect(l.insert(1, 'c'));
    try testing.expect(l.insert(0, 'a'));
    try testing.expectEqualStrings("abcd", l.get());
}

test "Line: insert past the end is rejected" {
    var l = lineFrom("ab");
    try testing.expect(!l.insert(3, 'x'));
    try testing.expectEqualStrings("ab", l.get());
}

test "Line: insert into a full line is rejected" {
    var l: Line = .{};
    for (0..l.cap) |_| try testing.expect(l.insert(l.len, 'x'));
    try testing.expect(!l.insert(l.len, 'y'));
    try testing.expect(!l.insert(10, 'y'));
    try testing.expectEqual(l.cap, l.len);
}

test "Line: remove deletes the character left of the index" {
    var l = lineFrom("abc");
    try testing.expectEqual(@as(?u8, 'b'), l.remove(2));
    try testing.expectEqualStrings("ac", l.get());
    try testing.expectEqual(@as(?u8, 'c'), l.remove(2));
    try testing.expectEqual(@as(?u8, 'a'), l.remove(1));
    try testing.expectEqualStrings("", l.get());
}

test "Line: remove at index 0 or past the end does nothing" {
    var l = lineFrom("ab");
    try testing.expectEqual(@as(?u8, null), l.remove(0));
    try testing.expectEqual(@as(?u8, null), l.remove(3));
    try testing.expectEqualStrings("ab", l.get());
}

test "Line: remove works on a full line" {
    var l: Line = .{};
    for (0..l.cap) |_| _ = l.insert(l.len, 'x');
    try testing.expectEqual(@as(?u8, 'x'), l.remove(l.len));
    try testing.expectEqual(l.cap - 1, l.len);
}

test "Line: change truncates input longer than the capacity" {
    var l: Line = .{};
    l.change(&(@as([300]u8, @splat('z'))));
    try testing.expectEqual(l.cap, l.len);
}

test "Line: isEmpty ignores spaces and tabs" {
    var blank = lineFrom(" \t  ");
    var text = lineFrom("  ls ");
    try testing.expect(blank.isEmpty());
    try testing.expect(!text.isEmpty());
}
