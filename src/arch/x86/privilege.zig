pub const DPL = enum(u2) {
    kernel_mode = 0,
    ring_1 = 1,
    ring_2 = 2,
    user_mode = 3,
};

/// Offset of the kernel code segment in the GDT
pub const KERNEL_CS: u16 = 0x08;
