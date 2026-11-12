# KFS

A small x86 (32-bit) kernel written in [Zig](https://ziglang.org/), booted by GRUB (Multiboot) and run under QEMU. This is a learning project in the spirit of the 42 "Kernel From Scratch" series.

## Features

- Multiboot boot via GRUB, with a minimal assembly entry point
- GDT, IDT, PIC remapping, exception and IRQ handling
- VGA text-mode driver and serial (COM1) output for debugging
- PS/2 keyboard driver
- Several virtual terminals (TTYs) handled by a multiplexer, with scrollback, a shadow buffer and command history
- A tiny shell: `help`, `echo`, `clear`, `halt`, `reboot`
- A panic screen for kernel panics and CPU exceptions

## Controls

- `Esc` toggles between **normal** mode (typing in the shell) and **insert** mode (terminal navigation)
- In insert mode: `F1`–`F4` or left/right arrows switch terminal, up/down arrows scroll

## Requirements

- [Zig](https://ziglang.org/download/)
- `qemu-system-i386`
- `grub-mkrescue` (`grub-pc-bin`, `xorriso`, `mtools` on Debian/Ubuntu)

## Usage

```
make            # build the kernel ELF
make run        # build the ISO and boot it in QEMU through GRUB
make run-kernel # boot the ELF directly in QEMU, without GRUB (faster)
make test       # run the unit tests
make clean      # remove the build cache
make fclean     # remove all build output, including the ISO
```

## Layout

```
src/arch/x86/   boot code, GDT, IDT, PIC, interrupts, port I/O, power
src/drivers/    VGA, keyboard, serial
src/console/    terminal buffer, TTY, line editing, history, multiplexer
src/shell.zig   command interpreter
src/panic.zig   panic screen
grub/           GRUB configuration
linker.ld       kernel linker script
```

## Next step: memory paging

The next milestone is memory management, starting with **paging**:

- Read the memory map provided by the Multiboot info structure
- Build a page directory and page tables, then enable paging (`CR0.PG`)
- Add a physical page frame allocator
- Add a page-fault handler
- Build a kernel heap on top of it (`kmalloc` / `kfree`)
