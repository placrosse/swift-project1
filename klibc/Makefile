TOPDIR := ..
include $(TOPDIR)/Makedefs

OBJS := misc.o string.o math.o io.o kprintf.o printf.o pthread.o \
	libcpp.o x86_string.o x86_misc.o

OBJS += std_cxx11_string.o
# used if compiled against older libcstd++
# FAKELIB_OBJS += std_string.o


all: klibc.o

klibc.o: $(OBJS)
	echo klibc OBJS = $(OBJS)
	ld -r -no_eh_labels -o $@ $^

clean:
	rm -f *.o *.s
