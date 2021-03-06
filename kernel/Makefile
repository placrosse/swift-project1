TOPDIR := ..
include $(TOPDIR)/Makedefs

SWIFT_MODULE := SwiftKernel
SWIFT_OBJS := SwiftKernel.o
SWIFT_SRCS :=	init/startup.swift		\
		init/bootparams.swift		\
		init/smbios.swift		\
		init/GDT.swift			\
		klib/Extensions.swift		\
		klib/MemoryBufferReader.swift	\
		mm/init.swift			\
		mm/page.swift			\
		devices/acpi.swift		\
		devices/acpi/facp.swift		\
		devices/acpi/mcfg.swift		\
		devices/cpu.swift		\
		devices/PCI.swift		\
		devices/tty.swift		\
		devices/kbd8042.swift		\
		devices/pit8254.swift		\
		devices/pic8259.swift		\
		traps/exceptions.swift		\
		traps/interrupt.swift		\
		traps/IDT.swift			\
		tasks/tasks.swift

KERNEL_OBJS := init/init.o mm/mm.o traps/traps.o SwiftKernel.o

SUBDIRS := devices mm traps init
HEADERS = $(TOPDIR)/include/*.h

all: kernel.o

.PHONY: kernel.o

kernel.o: SwiftKernel.o
	for dir in $(SUBDIRS); do $(MAKE) -C $$dir || exit; done
	ld -r -no_eh_labels -o $@ $(KERNEL_OBJS)

$(SWIFT_OBJS): $(SWIFT_SRCS) $(HEADERS)
	$(SWIFTC) $(SWIFTC_FLAGS) -whole-module-optimization -module-name $(SWIFT_MODULE) -emit-object -o $@ $(SWIFT_SRCS)

SwiftKernel.sil: $(SWIFT_SRCS) $(HEADERS)
	$(SWIFTC) $(SWIFTC_FLAGS) -whole-module-optimization -module-name $(SWIFT_MODULE) -emit-sil -o $@ $(SWIFT_SRCS)

SwiftKernel.silgen: $(SWIFT_SRCS) $(HEADERS)
	$(SWIFTC) $(SWIFTC_FLAGS) -whole-module-optimization -module-name $(SWIFT_MODULE) -emit-silgen -o $@ $(SWIFT_SRCS)


sil: SwiftKernel.sil

clean:
	rm -f *.bin *.o *.s *.sil
	set -e; for dir in $(SUBDIRS); do $(MAKE) -C $$dir clean; done
