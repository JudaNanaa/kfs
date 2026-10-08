NAME = kfs
ELF  = zig-out/bin/kfs

all: $(NAME)

$(NAME):
	zig build

run: all
	qemu-system-i386 -kernel $(ELF) -accel tcg -d int,cpu_reset -no-reboot

test:
	zig build test --summary all

clean:
	rm -rf .zig-cache

fclean: clean
	rm -rf zig-out

re: fclean all

.PHONY: all run test clean fclean re $(NAME)
