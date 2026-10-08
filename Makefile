NAME = kfs
ELF  = zig-out/bin/kfs

all: $(NAME)

$(NAME):
	zig build

run: all
	qemu-system-i386 -kernel $(ELF)

clean:
	rm -rf .zig-cache

fclean: clean
	rm -rf zig-out

re: fclean all

.PHONY: all run clean fclean re $(NAME)
