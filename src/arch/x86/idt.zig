const std = @import("std");
const testing = std.testing;

const DPL = enum(u2) {
    kernel_mode = 0,
    ring_1 = 1,
    ring_2 = 2,
    user_mode = 3,
};

const GateType = enum(u4) {
    interrupt_gate = 0xE,
    trap_gate = 0xF,
    _,
};

const Flags = packed struct(u8) {
    gate_type: GateType,
    storage: bool = false,
    dpl: DPL,
    present: bool = true,
};

const Entry = packed struct(u64) {
    offset_low: u16,
    segment_selector: u16,
    reserved: u8 = 0,
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

test "Flags : interrupt gate ring 0 = 0x8E" {
    const f: Flags = .{ .gate_type = .interrupt_gate, .dpl = .kernel_mode };
    try testing.expectEqual(@as(u8, 0x8E), @as(u8, @bitCast(f)));
}

test "Entry : découpage de l'adresse du handler" {
    const f: Flags = .{ .gate_type = .interrupt_gate, .dpl = .kernel_mode };
    const e = Entry.init(0x12345678, 0x08, f);
    try testing.expectEqual(@as(u64, 0x12348E0000085678), @as(u64, @bitCast(e)));
}

test "Entry : tailles" {
    try testing.expectEqual(@as(u64, 0), @as(u64, @bitCast(Entry.nil)));
    try testing.expectEqual(@as(usize, 64), @bitSizeOf(Entry));
    try testing.expectEqual(@as(usize, 48), @bitSizeOf(Descriptor));
    try testing.expectEqual(@as(usize, 256 * 8), @sizeOf(@TypeOf(idt)));
}
