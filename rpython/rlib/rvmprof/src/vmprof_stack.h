#pragma once

#ifdef _WIN32
#define intptr_t long // XXX windows VC++ 2008 lacks stdint.h
#else
#include <unistd.h>
#endif

#define VMPROF_CODE_TAG 1        /* <- also in cintf.py */
#define VMPROF_BLACKHOLE_TAG 2
#define VMPROF_JITTED_TAG 3
#define VMPROF_JITTING_TAG 4
#define VMPROF_GC_TAG 5
#define VMPROF_ASSEMBLER_TAG 6
#define VMPROF_NATIVE_TAG 7
// whatever we want here

typedef struct vmprof_stack_s {
    struct vmprof_stack_s* next;
    intptr_t value;
    intptr_t kind;
} vmprof_stack_t;

// the kind is WORD so we consume exactly 3 WORDs and we don't have
// to worry too much. There is a potential for squeezing it with bit
// patterns into one WORD, but I don't want to care RIGHT NOW, potential
// for future optimization potential
