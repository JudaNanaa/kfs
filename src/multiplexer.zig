const std = @import("std");
const input = @import("input.zig");
const terminal = @import("terminal.zig");
const tty = @import("tty.zig");
const cpu = @import("arch/x86/cpu.zig");
const vga = @import("drivers/vga.zig");

const Mode = enum {
    normal,
    select,

    fn change(self: *Mode) void {
        self.* = switch (self.*) {
            .normal => .select,
            .select => .normal,
        };
    }
};

const Mux = Multiplexer(4);
pub var mux: Mux = undefined;

const status = @import("status.zig");

fn modeLabel(m: Mode) []const u8 {
    return switch (m) {
        .normal => "-- INSERT --",
        .select => "-- NORMAL --",
    };
}

pub fn Multiplexer(comptime nb_terms: usize) type {
    return struct {
        const Self = @This();

        mode: Mode,
        current_tty: usize,
        show_status: bool,
        ttys: [nb_terms]tty.TTY,

        pub fn init(self: *Self) void {
            self.mode = .normal;
            self.current_tty = 0;
            self.show_status = true;

            for (&self.ttys) |*t| t.init();

            vga.enableCursor();
            self.render();
        }

        fn handle(self: *Self, key: input.Key) void {
            switch (self.mode) {
                .normal => self.normalHandler(key),
                .select => self.selectHandler(key),
            }
            self.render();
        }

        fn normalHandler(self: *Self, key: input.Key) void {
            switch (key) {
                .escape => {
                    vga.unsetCursor();
                    self.mode.change();
                },
                else => self.currentTTY().receveKey(key),
            }
        }

        fn selectHandler(self: *Self, key: input.Key) void {
            switch (key) {
                .escape => {
                    self.currentTTY().goToBottom();
                    vga.enableCursor();
                    self.mode.change();
                },
                .fkey => |n| self.switchTTY(n),
                .right => self.switchTTYToRight(),
                .left => self.switchTTYToLeft(),
                .down => self.currentTTY().scroll(.down),
                .up => self.currentTTY().scroll(.up),
                .char, .backspace, .enter => {},
            }
        }

        fn render(self: *Self) void {
            const term = &self.currentTTY().term;
            vga.blit(term.visibleCells());
            if (self.mode == .normal) {
                const pos = term.cursorPos();
                vga.setCursor(pos.x, pos.y);
            }
            self.drawStatus();
        }

        fn switchTTYToRight(self: *Self) void {
            if (self.current_tty + 1 >= self.ttys.len) return;

            self.current_tty += 1;
        }

        fn switchTTYToLeft(self: *Self) void {
            if (self.current_tty == 0) return;

            self.current_tty -= 1;
        }

        fn switchTTY(self: *Self, index: u8) void {
            if (index >= self.ttys.len or index == self.current_tty) return;

            self.current_tty = index;
        }

        fn currentTTY(self: *Self) *tty.TTY {
            return &self.ttys[self.current_tty];
        }

        fn drawStatus(self: *Self) void {
            if (self.show_status) {
                status.draw(self.current_tty, self.ttys.len, modeLabel(self.mode), "esc:mode F1-F4:tty F10:bar");
            } else {
                status.clear();
            }
        }

        pub fn run(self: *Self) noreturn {
            while (true) {
                if (input.pop()) |key| {
                    self.handle(key);
                } else {
                    cpu.halt();
                }
            }
        }
    };
}
