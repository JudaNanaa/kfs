const input = @import("input.zig");
const terminal = @import("terminal.zig");

pub fn handle(key: input.Key) ?[]const u8 {
    const current_term = terminal.active();
    switch (key) {
        .fkey => |n| terminal.switchTo(n),
        .char => |c| if (current_term.line.len < current_term.line.cap) {
            current_term.line.append(c);
            current_term.putChar(c);
        },
        .backspace => if (current_term.line.len > 0) {
            _ = current_term.line.pop();
            current_term.backspace();
        },
        .enter => {
            current_term.putChar('\n');
            return current_term.line.take();
        },
    }
    return null;
}
