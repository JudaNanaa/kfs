pub fn eql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len)
        return false;

    for (a, b) |x, y| {
        if (x != y)
            return false;
    }
    return true;
}

pub fn trim(s: []const u8) []const u8 {
    var start: usize = 0;
    var end: usize = s.len;
    while (start < end and s[start] == ' ')
        start += 1;
    while (end > start and s[end - 1] == ' ')
        end -= 1;
    return s[start..end];
}
