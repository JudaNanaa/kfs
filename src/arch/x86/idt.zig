const std = @import("std");
const testing = std.testing;
const privilege = @import("privilege.zig");
const pic = @import("pic.zig");

const GateType = enum(u4) {
    task_gate_32 = 0x5,
    interrupt_gate_16 = 0x6,
    trap_gate_16 = 0x7,
    interrupt_gate_32 = 0xE,
    trap_gate_32 = 0xF,
    _,
};

const Flags = packed struct(u8) {
    gate_type: GateType,
    /// Need to stay false
    s: bool = false,
    dpl: privilege.DPL,
    present: bool = true,
};

const Entry = packed struct(u64) {
    offset_low: u16,
    segment_selector: u16,
    zero: u8 = 0,
    flags: Flags,
    offset_high: u16,

    const nil: Entry = @bitCast(@as(u64, 0));

    fn init(handler: u32, selector: u16, flags: Flags) Entry {
        return .{
            .offset_low = @truncate(handler),
            .segment_selector = selector,
            .flags = flags,
            .offset_high = @truncate(handler >> 16),
        };
    }
};

const Descriptor = packed struct(u48) {
    limit: u16,
    base: u32,
};

var idt: [256]Entry = @splat(Entry.nil);

extern const isr_table: [32]u32;
extern const irq_table: [16]u32;

extern fn idt_flush(idtr: *const Descriptor) callconv(.c) void;

pub fn init() void {
    const flags: Flags = .{ .gate_type = .interrupt_gate_32, .dpl = .kernel_mode };

    const IRQ_BASE = 0x20;

    pic.remap(IRQ_BASE, IRQ_BASE + 8);

    for (isr_table, 0..) |handler, i| {
        idt[i] = Entry.init(handler, privilege.KERNEL_CS, flags);
    }
    for (irq_table, 0..) |handler, i| {
        idt[IRQ_BASE + i] = Entry.init(handler, privilege.KERNEL_CS, flags);
    }

    const idtr = Descriptor{
        .limit = @sizeOf(@TypeOf(idt)) - 1,
        .base = @intFromPtr(&idt),
    };

    idt_flush(&idtr);
}

test "Flags : interrupt gate ring 0 = 0x8E" {
    const f: Flags = .{ .gate_type = .interrupt_gate_32, .dpl = .kernel_mode };
    try testing.expectEqual(@as(u8, 0x8E), @as(u8, @bitCast(f)));
}

test "Flags : autres combinaisons" {
    const trap: Flags = .{ .gate_type = .trap_gate_32, .dpl = .kernel_mode };
    const user: Flags = .{ .gate_type = .interrupt_gate_32, .dpl = .user_mode };
    try testing.expectEqual(@as(u8, 0x8F), @as(u8, @bitCast(trap)));
    try testing.expectEqual(@as(u8, 0xEE), @as(u8, @bitCast(user)));
}

test "Entry : découpage de l'adresse du handler" {
    const f: Flags = .{ .gate_type = .interrupt_gate_32, .dpl = .kernel_mode };
    const e = Entry.init(0x12345678, 0x08, f);
    try testing.expectEqual(@as(u64, 0x12348E0000085678), @as(u64, @bitCast(e)));
}

test "Entry : tailles" {
    try testing.expectEqual(@as(u64, 0), @as(u64, @bitCast(Entry.nil)));
    try testing.expectEqual(@as(usize, 64), @bitSizeOf(Entry));
    try testing.expectEqual(@as(usize, 48), @bitSizeOf(Descriptor));
    try testing.expectEqual(@as(usize, 256 * 8), @sizeOf(@TypeOf(idt)));
}
