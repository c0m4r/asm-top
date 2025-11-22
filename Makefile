AS = nasm
LD = ld
ASFLAGS = -f elf64
LDFLAGS =

TARGET = asm-top
TARGET = asm-top
OBJECTS = main.o cpu.o memory.o syscalls.o utils.o display.o input.o sysinfo.o terminal.o format.o

# Include configuration if it exists
-include config.mk

# Default installation directories (if config.mk doesn't exist)
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man

.PHONY: all clean install uninstall

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $^

%.o: %.asm
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f $(OBJECTS) $(TARGET)

run: $(TARGET)
	./$(TARGET)

install: $(TARGET)
	@echo "Installing $(TARGET) to $(BINDIR)..."
	@install -d $(BINDIR)
	@install -m 755 $(TARGET) $(BINDIR)/$(TARGET)
	@echo "Installation complete!"
	@echo "Run '$(TARGET)' to start the program"

uninstall:
	@echo "Uninstalling $(TARGET) from $(BINDIR)..."
	@rm -f $(BINDIR)/$(TARGET)
	@echo "Uninstall complete!"
