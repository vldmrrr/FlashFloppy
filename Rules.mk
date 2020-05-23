TOOL_PREFIX = arm-none-eabi-
CC = $(TOOL_PREFIX)gcc
OBJCOPY = $(TOOL_PREFIX)objcopy
LD = $(TOOL_PREFIX)ld

PYTHON = python

ifneq ($(VERBOSE),1)
TOOL_PREFIX := @$(TOOL_PREFIX)
endif

FLAGS  = -g -Os -nostdlib -std=gnu99 -iquote $(ROOT)/inc
FLAGS += -Wall -Werror -Wno-format -Wdeclaration-after-statement
FLAGS += -Wstrict-prototypes -Wredundant-decls -Wnested-externs
FLAGS += -fno-common -fno-exceptions -fno-strict-aliasing
FLAGS += -mlittle-endian -mthumb -mcpu=cortex-m3 -mfloat-abi=soft
FLAGS += -Wno-unused-value

ifneq ($(debug),y)
FLAGS += -DNDEBUG
endif

# Following options are mutually exclusive
ifeq ($(bootloader),y)
FLAGS += -DBOOTLOADER=1
else ifeq ($(logfile),y)
FLAGS += -DLOGFILE=1
endif

ifeq ($(quickdisk),y)
FLAGS += -DQUICKDISK=1
floppy=n
else
floppy=y
endif

FLAGS += -MMD -MF .$(@F).d
DEPS = .*.d

FLAGS += $(FLAGS-y)

CFLAGS += $(CFLAGS-y) $(FLAGS) -include decls.h
AFLAGS += $(AFLAGS-y) $(FLAGS) -D__ASSEMBLY__
LDFLAGS += $(LDFLAGS-y) $(FLAGS) -Wl,--gc-sections

RULES_MK := y

include Makefile

SUBDIRS += $(SUBDIRS-y)
OBJS += $(OBJS-y) $(patsubst %,%/build.o,$(SUBDIRS))

SRCDIR := $(shell python -c "import os.path; print os.path.relpath('$(CURDIR)','$(ROOT)')")

# Force execution of pattern rules (for which PHONY cannot be directly used).
.PHONY: FORCE
FORCE:

.PHONY: clean

.SECONDARY:

build.o: $(OBJS)
	$(LD) -r -o $@ $^

%/build.o: FORCE
	$(MAKE) -f $(ROOT)/Rules.mk -C $* build.o

.ONESHELL:
%.o: %.c Makefile
	@echo $(CC) $(CFLAGS) -c $(SRCDIR)/$< -o $(SRCDIR)/$@
	cd $(ROOT)
	$(CC) $(CFLAGS) -c $(SRCDIR)/$< -o $(SRCDIR)/$@

%.o: %.S Makefile
	@echo AS $@
	$(CC) $(AFLAGS) -c $< -o $@

%.ld: %.ld.S Makefile
	@echo CPP $@
	$(CC) -P -E $(AFLAGS) $< -o $@

%.elf: $(OBJS) %.ld Makefile
	@echo LD $@
	$(CC) $(LDFLAGS) -T$(*F).ld $(OBJS) -o $@
	chmod a-x $@

%.hex: %.elf
	@echo OBJCOPY $@
	$(OBJCOPY) -O ihex $< $@
	chmod a-x $@

%.bin: %.elf
	@echo OBJCOPY $@
	$(OBJCOPY) -O binary $< $@
	chmod a-x $@

%.o: $(RPATH)/%.c Makefile
	@echo CC $@
	$(CC) $(CFLAGS) -c $< -o $@

%.o: $(RPATH)/%.S Makefile
	@echo AS $@
	$(CC) $(AFLAGS) -c $< -o $@

clean:: $(addprefix _clean_,$(SUBDIRS) $(SUBDIRS-n) $(SUBDIRS-))
	rm -f *.orig *.rej *~ *.o *.elf *.hex *.bin *.ld $(DEPS)
_clean_%: FORCE
	$(MAKE) -f $(ROOT)/Rules.mk -C $* clean

-include $(DEPS)
