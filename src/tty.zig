const input = @import("input.zig");
const terminal = @import("terminal.zig");

const Line = struct {
    str: [256]u8 = undefined,
    len: usize = 0,
    cap: usize = 256,

    fn append(self: *Line, c: u8) void {
        self.str[self.len] = c;
        self.len += 1;
    }

    fn pop(self: *Line) u8 {
        const idx = self.len;
        self.len -= 1;
        return self.str[idx];
    }

    fn take(self: *Line) []const u8 {
        const len = self.len;
        self.len = 0;
        return self.str[0..len];
    }
};

var line: Line = .{};

pub fn handle(key: input.Key) ?[]const u8 {
    const t = terminal.active();
    switch (key) {
        .fkey => |n| terminal.switchTo(n),
        .char => |c| if (line.len < line.cap) {
            line.append(c);
            t.putChar(c);
        },
        .backspace => if (line.len > 0) {
            _ = line.pop();
            t.backspace();
        },
        .enter => {
            t.putChar('\n');
            return line.take();
        },
    }
    return null;
}
