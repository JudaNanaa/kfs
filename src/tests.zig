//! Entry point for `zig build test`: pulls in every file that has tests.
//! Tests run on the host, so only code that does not touch the hardware is tested.

test {
    _ = @import("arch/x86/gdt.zig");
    _ = @import("arch/x86/idt.zig");
    _ = @import("arch/x86/pic.zig");
    _ = @import("arch/x86/interrupts.zig");
    _ = @import("drivers/keyboard.zig");
    _ = @import("input.zig");
    _ = @import("console/tty.zig");
    _ = @import("console/terminal.zig");
    _ = @import("console/line.zig");
    _ = @import("console/history.zig");
}
