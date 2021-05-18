#
# musl config.mak template (original in dist/config.mak)
#

# Target CPU architecture. Supported values: i386, x86_64
ARCH = i386

# Installation prefix. DO NOT use /, /usr, or /usr/local !
prefix = /usr/local/musl

# Installation prefix for musl-gcc compiler wrapper.
exec_prefix = /usr/local

# Location for the dynamic linker ld-musl-$(ARCH).so.1
syslibdir = /lib

# Uncomment if you want to build i386 musl on a 64-bit host
#CFLAGS += -m32

# Uncomment to fix broken distro-patched toolchains where hash-style=gnu(only)
#LDFLAGS += -Wl,--hash-style,both

# Uncomment to fix broken distro-patched toolchains where stack-protector=on
#CFLAGS += -fno-stack-protector

# Uncomment for smaller code size.
#CFLAGS += -fomit-frame-pointer -mno-accumulate-outgoing-args

# Uncomment to omit massive GCC4 DWARF2 bloat (only useful for debugging)
#CFLAGS += -fno-asynchronous-unwind-tables

# Uncomment for warnings (as errors). Might need tuning to your gcc version.
#CFLAGS += -Werror -Wall -Wpointer-arith -Wcast-align -Wno-parentheses -Wno-char-subscripts -Wno-uninitialized -Wno-sequence-point -Wno-missing-braces -Wno-unused-value -Wno-overflow -Wno-int-to-pointer-cast

# Uncomment if you want to disable building the shared library.
#SHARED_LIBS = 
