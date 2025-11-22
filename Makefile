AS = nasm
LD = ld
ASFLAGS = -f elf64
LDFLAGS =

TARGET = asm-top
OBJECTS = main.o cpu.o memory.o syscalls.o utils.o display.o input.o sysinfo.o terminal.o

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $^

%.o: %.asm
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f $(OBJECTS) $(TARGET)

run: $(TARGET)
	./$(TARGET)
