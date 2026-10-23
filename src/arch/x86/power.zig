const io = @import("io.zig");
const cpu = @import("cpu.zig");

/// 8042 PS/2 controller: status register (read) and command register (write).
const PS2_STATUS: u16 = 0x64;
const PS2_COMMAND: u16 = 0x64;
/// Status bit 1: the controller has not read the last command yet.
const PS2_INPUT_FULL: u8 = 1 << 1;
/// Pulses the CPU reset line.
const PS2_CMD_RESET: u8 = 0xFE;

/// Stops the CPU for good. Only a hardware reset gets it out of this.
pub fn halt() noreturn {
    cpu.disableInterrupts();
    while (true) cpu.halt();
}

/// Resets the machine through the keyboard controller,
/// falls back on a triple fault if that did not work.
pub fn reboot() noreturn {
    cpu.disableInterrupts();

    // the controller ignores commands until it has read the previous one
    for (0..100_000) |_| {
        if (io.inb(PS2_STATUS) & PS2_INPUT_FULL == 0) break;
    }
    io.outb(PS2_COMMAND, PS2_CMD_RESET);

    tripleFault();
}

/// With an empty IDT, any interrupt cannot be handled, neither can the resulting
/// double fault: the CPU gives up and resets.
fn tripleFault() noreturn {
    const empty: packed struct(u48) { limit: u16, base: u32 } = .{ .limit = 0, .base = 0 };
    asm volatile (
        \\lidt (%[idtr])
        \\int3
        :
        : [idtr] "r" (&empty),
    );
    halt();
}
