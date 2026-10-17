const std = @import("std");
const input = @import("input.zig");
const terminal = @import("terminal.zig");
const tty = @import("tty.zig");

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

            for (&self.ttys) |*_tty| {
                _tty.init();
            }
            self.currentTTY().flush();
        }

        fn handle(self: *Self, key: input.Key) void {
            switch (self.mode) {
                .normal => self.normalHandler(key),
                .select => self.selectHandler(key),
            }
        }

        fn normalHandler(self: *Self, key: input.Key) void {
            switch (key) {
                .escape => self.mode.change(),
                else => {
                    self.currentTTY().receveKey(key);
                    self.currentTTY().flush();
                },
            }
        }

        fn selectHandler(self: *Self, key: input.Key) void {
            switch (key) {
                .escape => self.mode.change(),
                .fkey => |n| self.switchTTY(n),
                .char, .backspace, .enter => {},
            }
        }

        fn switchTTY(self: *Self, to: u8) void {
            self.current_tty = to;
            self.currentTTY().flush();
        }

        fn currentTTY(self: *Self) *tty.TTY {
            return &self.ttys[self.current_tty];
        }

        pub fn run(self: *Self) noreturn {
            while (true) {
                if (input.pop()) |key| {
                    self.handle(key);
                } else {
                    asm volatile ("hlt");
                }
            }
        }

        pub fn printAll(self: *Self, comptime fmt: []const u8, args: anytype) void {
            for (&self.ttys) |*_tty| {
                _tty.print(fmt, args);
            }
        }

        pub fn printkAll(self: *Self, comptime fmt: []const u8, args: anytype) void {
            for (&self.ttys) |*_tty| {
                _tty.printk(fmt, args);
            }
        }
    };
}
