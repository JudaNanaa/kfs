const std = @import("std");
const testing = std.testing;
const privilege = @import("privilege.zig");

const Access = packed struct(u8) {
    /// Accessed bit. The CPU will set it when the segment is accessed unless set to 1 in advance.
    accessed: bool = true,

    /// Readable bit/Writable bit.
    /// - For code segments: Readable bit. If clear (0), read access for this segment is not allowed. If set (1) read access is allowed. Write access is never allowed for code segments.
    /// - For data segments: Writeable bit. If clear (0), write access for this segment is not allowed. If set (1) write access is allowed. Read access is always allowed for data segments.
    rw: bool,

    /// Direction bit/Conforming bit.
    /// For data selectors: Direction bit. If clear (0) the segment grows up. If set (1) the segment grows down, ie. the Offset has to be greater than the Limit.
    /// For code selectors: Conforming bit.
    /// - If clear (0) code in this segment can only be executed from the ring set in DPL.
    /// - If set (1) code in this segment can be executed from an equal or lower privilege level. For example, code in ring 3 can far-jump to conforming code in a ring 2 segment. The DPL field represent the highest privilege level that is allowed to execute the segment. For example, code in ring 0 cannot far-jump to a conforming code segment where DPL is 2, while code in ring 2 and 3 can. Note that the privilege level remains the same, ie. a far-jump from ring 3 to a segment with a DPL of 2 remains in ring 3 after the jump.
    dc: bool = false,

    /// Executable bit. If clear (0) the descriptor defines a data segment. If set (1) it defines a code segment which can be executed from.
    executable: bool = false,

    /// Descriptor type bit. If clear (0) the descriptor defines a system segment (eg. a Task State Segment). If set (1) it defines a code or data segment.
    s: bool = true,

    /// Descriptor privilege level field. Contains the CPU Privilege level of the segment. 0 = highest privilege (kernel), 3 = lowest privilege (user applications).
    dpl: privilege.DPL,

    /// Present bit. Allows an entry to refer to a valid segment. Must be set (1) for any valid segment.
    /// This means that in case the GDT descriptor is stored in read only pages and this bit is set to 0, the CPU trying to set this bit will trigger a page fault.
    /// Best left set to 1 unless otherwise needed.
    present: bool = true,
};

const Flags = packed struct(u4) {
    /// Reserved, need to be 0
    avl: bool = false,

    /// Long-mode code flag. If set (1), the descriptor defines a 64-bit code segment.
    /// When set, DB should always be clear. For any other type of segment (other code types or any data segment), it should be clear (0).
    long: bool = false, // 64 bits (laisse false en 32 bits)

    /// Size flag. If clear (0), the descriptor defines a 16-bit protected mode segment.
    /// If set (1) it defines a 32-bit protected mode segment.
    /// A GDT can have both 16-bit and 32-bit selectors at once.
    db: bool = true,

    /// Granularity flag, indicates the size the Limit value is scaled by.
    /// If clear (0), the Limit is in 1 Byte blocks (byte granularity).
    /// If set (1), the Limit is in 4 KiB blocks (page granularity).
    granularity: bool = true,
};

const Entry = packed struct(u64) {
    limit_low: u16,
    base_low: u24,
    access: Access,
    limit_high: u4,
    flags: Flags,
    base_high: u8,

    const nil: Entry = @bitCast(@as(u64, 0));

    fn init(base: u32, limit: u20, access: Access, flags: Flags) Entry {
        return .{
            .limit_low = @truncate(limit),
            .base_low = @truncate(base),
            .access = access,
            .limit_high = @truncate(limit >> 16),
            .flags = flags,
            .base_high = @truncate(base >> 24),
        };
    }
};

const Gdtr = packed struct(u48) {
    limit: u16,
    base: u32,
};

const GDT_ADDR = 0x800;

var gdt: [7]Entry = .{
    Entry.nil, // 0x00
    Entry.init(0, 0xFFFFF, .{ .rw = true, .executable = true, .dpl = .kernel_mode }, .{}), // 0x08 kernel code
    Entry.init(0, 0xFFFFF, .{ .rw = true, .dpl = .kernel_mode }, .{}), // 0x10 kernel data
    Entry.init(0, 0xFFFFF, .{ .rw = true, .dpl = .kernel_mode }, .{}), // 0x18 kernel stack
    Entry.init(0, 0xFFFFF, .{ .rw = true, .executable = true, .dpl = .user_mode }, .{}), // 0x20 user code
    Entry.init(0, 0xFFFFF, .{ .rw = true, .dpl = .user_mode }, .{}), // 0x28 user data
    Entry.init(0, 0xFFFFF, .{ .rw = true, .dpl = .user_mode }, .{}), // 0x30 user stack
};

extern fn gdt_flush(gdtr: *const Gdtr) callconv(.c) void;

pub fn init() void {
    const dest: [*]volatile Entry = @ptrFromInt(GDT_ADDR);
    @memmove(dest, gdt[0..]);

    const gdtr = Gdtr{
        .limit = @sizeOf(@TypeOf(gdt)) - 1,
        .base = GDT_ADDR,
    };
    gdt_flush(&gdtr);
}

fn expectRaw(expected: u64, e: Entry) !void {
    try testing.expectEqual(expected, @as(u64, @bitCast(e)));
}

test "Access : octets d'accès classiques" {
    const code_k: Access = .{ .rw = true, .executable = true, .dpl = .kernel_mode };
    const data_k: Access = .{ .rw = true, .dpl = .kernel_mode };
    const code_u: Access = .{ .rw = true, .executable = true, .dpl = .user_mode };
    const data_u: Access = .{ .rw = true, .dpl = .user_mode };

    try testing.expectEqual(@as(u8, 0x9B), @as(u8, @bitCast(code_k)));
    try testing.expectEqual(@as(u8, 0x93), @as(u8, @bitCast(data_k)));
    try testing.expectEqual(@as(u8, 0xFB), @as(u8, @bitCast(code_u)));
    try testing.expectEqual(@as(u8, 0xF3), @as(u8, @bitCast(data_u)));
}

test "Flags : 32 bits + granularité 4 Ko" {
    try testing.expectEqual(@as(u4, 0xC), @as(u4, @bitCast(Flags{})));
}

test "Entry : segments flat" {
    const code_k: Access = .{ .rw = true, .executable = true, .dpl = .kernel_mode };
    const data_k: Access = .{ .rw = true, .dpl = .kernel_mode };
    const code_u: Access = .{ .rw = true, .executable = true, .dpl = .user_mode };
    const data_u: Access = .{ .rw = true, .dpl = .user_mode };

    try expectRaw(0x00CF9B000000FFFF, Entry.init(0, 0xFFFFF, code_k, .{}));
    try expectRaw(0x00CF93000000FFFF, Entry.init(0, 0xFFFFF, data_k, .{}));
    try expectRaw(0x00CFFB000000FFFF, Entry.init(0, 0xFFFFF, code_u, .{}));
    try expectRaw(0x00CFF3000000FFFF, Entry.init(0, 0xFFFFF, data_u, .{}));
}

test "Entry : découpage de la base" {
    // base 0x12345678 : 0x345678 dans base_low, 0x12 dans base_high
    const code_k: Access = .{ .rw = true, .executable = true, .dpl = .kernel_mode };
    try expectRaw(0x12CF9B345678FFFF, Entry.init(0x12345678, 0xFFFFF, code_k, .{}));
}

test "Entry : entrée nulle et tailles" {
    try expectRaw(0, Entry.nil);
    try testing.expectEqual(@as(usize, 64), @bitSizeOf(Entry));
    try testing.expectEqual(@as(usize, 48), @bitSizeOf(Gdtr));
}

test "GDT du kernel : 7 entrées, la première est nulle" {
    try testing.expectEqual(@as(usize, 7), gdt.len);
    try expectRaw(0, gdt[0]);
    try expectRaw(0x00CF9B000000FFFF, gdt[1]); // kernel code
    try expectRaw(0x00CF93000000FFFF, gdt[2]); // kernel data
}
