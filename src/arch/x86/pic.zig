const std = @import("std");
const io = @import("io.zig");

const Pic = struct {
    command: u16,
    data: u16,
};

const master: Pic = .{ .command = 0x20, .data = 0x21 };
const slave: Pic = .{ .command = 0xA0, .data = 0xA1 };

/// End-of-interrupt command code
const EOI = 0x20;

/// send End-of-interrupt to the PIC chip
pub fn sendEOI(irq: u8) void {
    if (irq >= 8) {
        io.outb(slave.command, EOI);
    }
    io.outb(master.command, EOI);
}

/// ICW1: first initialization command word, sent to the command port of each PIC.
const ICW1 = packed struct(u8) {
    /// Bit 0: ICW4 will be present in the init sequence.
    icw4: bool = false,
    /// Bit 1: single mode (when false, cascade mode).
    single: bool = false,
    /// Bit 2: call address interval 4 (when false, interval 8).
    interval4: bool = false,
    /// Bit 3: level triggered mode (when false, edge triggered).
    level: bool = false,
    /// Bit 4: initialization bit, required to start the init sequence.
    init: bool = false,
    /// Bits 5-7: unused, must be zero.
    _pad: u3 = 0,
};

/// Buffered mode field of ICW4 (bits 2-3).
const BufMode = enum(u2) {
    /// Non-buffered mode.
    none = 0b00,
    /// Buffered mode, slave (0x08).
    slave = 0b10,
    /// Buffered mode, master (0x0C).
    master = 0b11,
};

/// ICW4: fourth initialization command word, sent to the data port of each PIC.
const ICW4 = packed struct(u8) {
    /// Bit 0: 8086/88 mode (when false, MCS-80/85 mode).
    mode_8086: bool = false,
    /// Bit 1: auto EOI (when false, normal EOI).
    auto_eoi: bool = false,
    /// Bits 2-3: buffered mode.
    buf: BufMode = .none,
    /// Bit 4: special fully nested mode.
    sfnm: bool = false,
    /// Bits 5-7: unused, must be zero.
    _pad: u3 = 0,
};

/// IRQ line used by the master PIC to cascade to the slave PIC.
const CASCADE_IRQ: u3 = 2;
const master_cascade_mask: u8 = 1 << CASCADE_IRQ; // slave on IRQ2
const slave_cascade_id: u8 = CASCADE_IRQ;

/// Remaps the PIC vector offsets so IRQs don't collide with CPU exceptions.
///
/// `offset1`: vector offset for the master PIC (vectors become offset1..offset1+7).
/// `offset2`: vector offset for the slave PIC (vectors become offset2..offset2+7).
pub fn remap(offset1: u8, offset2: u8) void {
    const icw1: ICW1 = .{ .init = true, .icw4 = true };
    const icw4: ICW4 = .{ .mode_8086 = true };

    // ICW1: start the initialization sequence (in cascade mode).
    io.outb(master.command, @bitCast(icw1));
    io.wait();
    io.outb(slave.command, @bitCast(icw1));
    io.wait();

    // ICW2: set the vector offsets.
    io.outb(master.data, offset1);
    io.wait();
    io.outb(slave.data, offset2);
    io.wait();

    // ICW3: tell the master PIC there is a slave PIC at IRQ2,
    // and tell the slave PIC its cascade identity.
    io.outb(master.data, master_cascade_mask);
    io.wait();
    io.outb(slave.data, slave_cascade_id);
    io.wait();

    // ICW4: use 8086 mode (and not 8080 mode).
    io.outb(master.data, @bitCast(icw4));
    io.wait();
    io.outb(slave.data, @bitCast(icw4));
    io.wait();

    // Unmask both PICs
    io.outb(master.data, 0);
    io.outb(slave.data, 0);
}

pub fn disable() void {
    io.outb(master.data, 0xff);
    io.outb(slave.data, 0xff);
}

fn changeMask(irq: u4, masked: bool) void {
    const pic = if (irq < 8) master else slave;
    const line: u3 = @truncate(irq);
    var mask = io.inb(pic.data);
    if (masked) mask |= @as(u8, 1) << line else mask &= ~(@as(u8, 1) << line);
    io.outb(pic.data, mask);
}

pub fn setMask(irq: u4) void {
    changeMask(irq, true);
}

pub fn clearMask(irq: u4) void {
    changeMask(irq, false);
}
