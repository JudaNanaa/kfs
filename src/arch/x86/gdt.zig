const std = @import("std");
const testing = std.testing;

const Access = packed struct(u8) {
    accessed: bool = true,
    rw: bool = false, // code : lisible / data : modifiable
    dc: bool = false, // code : conforming / data : direction (expand-down)
    executable: bool = false,
    s: bool = true, // 1 = code/data, 0 = système (TSS…)
    dpl: u2 = 0, // ring 0 à 3
    present: bool = true,
};

const Flags = packed struct(u4) {
    avl: bool = false,
    long: bool = false, // 64 bits (laisse false en 32 bits)
    db: bool = true, // 1 = segment 32 bits
    granularity: bool = true, // 1 = limite en pages de 4 Ko
};

const Entry = packed struct(u64) {
    limit_low: u16,
    base_low: u24,
    access: Access,
    limit_high: u4,
    flags: Flags,
    base_high: u8,

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

const null_entry: Entry = @bitCast(@as(u64, 0));

var gdt: [7]Entry linksection(".gdt") = .{
    null_entry, // 0x00
    Entry.init(0, 0xFFFFF, .{ .rw = true, .executable = true }, .{}), // 0x08 kernel code
    Entry.init(0, 0xFFFFF, .{ .rw = true }, .{}), // 0x10 kernel data
    Entry.init(0, 0xFFFFF, .{ .rw = true }, .{}), // 0x18 kernel stack
    Entry.init(0, 0xFFFFF, .{ .rw = true, .executable = true, .dpl = 3 }, .{}), // 0x20 user code
    Entry.init(0, 0xFFFFF, .{ .rw = true, .dpl = 3 }, .{}), // 0x28 user data
    Entry.init(0, 0xFFFFF, .{ .rw = true, .dpl = 3 }, .{}), // 0x30 user stack
};

extern fn gdt_flush(gdtr: *const Gdtr) callconv(.c) void;

pub fn init() void {
    const gdtr = Gdtr{
        .limit = @sizeOf(@TypeOf(gdt)) - 1,
        .base = @intFromPtr(&gdt),
    };
    gdt_flush(&gdtr);
}

// fn raw(e: Entry) u64 {
//     return @bitCast(e);
// }
//
// test "Access : octets d'accès classiques" {
//     try testing.expectEqual(@as(u8, 0x9B), @as(u8, @bitCast(Access{ .rw = true, .executable = true })));
//     try testing.expectEqual(@as(u8, 0x93), @as(u8, @bitCast(Access{ .rw = true })));
//     try testing.expectEqual(@as(u8, 0xFB), @as(u8, @bitCast(Access{ .rw = true, .executable = true, .dpl = 3 })));
//     try testing.expectEqual(@as(u8, 0xF3), @as(u8, @bitCast(Access{ .rw = true, .dpl = 3 })));
// }
//
// test "Flags : 32 bits + granularité 4 Ko" {
//     try testing.expectEqual(@as(u4, 0xC), @as(u4, @bitCast(Flags{})));
// }
//
// test "Entry : segments flat" {
//     try testing.expectEqual(0x00CF9B000000FFFF, raw(Entry.init(0, 0xFFFFF, .{ .rw = true, .executable = true }, .{})));
//     try testing.expectEqual(0x00CF93000000FFFF, raw(Entry.init(0, 0xFFFFF, .{ .rw = true }, .{})));
//     try testing.expectEqual(0x00CFFB000000FFFF, raw(Entry.init(0, 0xFFFFF, .{ .rw = true, .executable = true, .dpl = 3 }, .{})));
//     try testing.expectEqual(0x00CFF3000000FFFF, raw(Entry.init(0, 0xFFFFF, .{ .rw = true, .dpl = 3 }, .{})));
// }
//
// test "Entry : découpage de la base" {
//     // base 0x12345678 : 0x345678 dans base_low, 0x12 dans base_high
//     try testing.expectEqual(0x12CF9B345678FFFF, raw(Entry.init(0x12345678, 0xFFFFF, .{ .rw = true, .executable = true }, .{})));
// }
//
// test "Entry : entrée nulle et tailles" {
//     try testing.expectEqual(@as(u64, 0), raw(null_entry));
//     try testing.expectEqual(@as(usize, 64), @bitSizeOf(Entry));
//     try testing.expectEqual(@as(usize, 48), @bitSizeOf(Gdtr));
// }
