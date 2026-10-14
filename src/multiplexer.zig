const std = @import("std");
const input = @import("input.zig");
const terminal = @import("terminal.zig");

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
        current_terminal: usize,
        show_status: bool,
        terminals: [nb_terms]terminal.Terminal,

        pub fn init(self: *Self) void {
            self.mode = .normal;
            self.current_terminal = 0;
            self.show_status = true;
            for (&self.terminals) |*ter| ter.* = .init();
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
                else => self.current_term().receveKey(key),
            }
        }

        fn selectHandler(self: *Self, key: input.Key) void {
            switch (key) {
                .escape => self.mode.change(),
                .fkey => |n| self.switchTerm(n),
                .char, .backspace, .enter => {},
            }
        }

        fn switchTerm(self: *Self, to: u8) void {
            self.current_terminal = to;
        }

        fn current_term(self: *Self) *terminal.Terminal {
            return &self.terminals[self.current_terminal];
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
            for (&self.terminals) |*term| {
                term.print(fmt, args);
            }
        }

        pub fn printkAll(self: *Self, comptime fmt: []const u8, args: anytype) void {
            for (&self.terminals) |*term| {
                term.printk(fmt, args);
            }
        }
    };
}
