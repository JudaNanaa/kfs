NAME = kfs
ELF  = zig-out/bin/kfs
ISO  = $(NAME).iso

ISO_DIR  = zig-out/iso
GRUB_CFG = grub/grub.cfg

# Debian/Ubuntu ship grub-mkrescue, Fedora/Arch ship grub2-mkrescue
GRUB_MKRESCUE := $(shell command -v grub-mkrescue 2>/dev/null || command -v grub2-mkrescue 2>/dev/null)
# Only the BIOS platform: keeps the image small
GRUB_PLATFORM = /usr/lib/grub/i386-pc

all: $(NAME)

$(NAME):
	zig build

iso: $(ISO)

$(ISO): $(NAME) $(GRUB_CFG)
	@test -n "$(GRUB_MKRESCUE)" || { echo "grub-mkrescue not found (install grub-pc-bin, xorriso and mtools)"; exit 1; }
	mkdir -p $(ISO_DIR)/boot/grub
	cp $(ELF) $(ISO_DIR)/boot/$(NAME)
	cp $(GRUB_CFG) $(ISO_DIR)/boot/grub/grub.cfg
	$(GRUB_MKRESCUE) -d $(GRUB_PLATFORM) -o $@ $(ISO_DIR) \
		--locales="" --fonts="" --themes="" --compress=xz

run: iso
	qemu-system-i386 -boot d -cdrom $(ISO) -serial stdio

# Boots the ELF directly, skipping GRUB: faster while developing
run-kernel: all
	qemu-system-i386 -kernel $(ELF) -serial stdio

debug: all
	qemu-system-i386 -kernel $(ELF) -accel tcg -d int,cpu_reset -no-reboot

test:
	zig build test --summary all

clean:
	rm -rf .zig-cache

fclean: clean
	rm -rf zig-out $(ISO)

re: fclean all

.PHONY: all iso run run-kernel debug test clean fclean re $(NAME) $(ISO)
