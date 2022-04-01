#pragma once

#include "vmprof.h"

int vmp_walk_and_record_stack(PY_STACK_FRAME_T * frame, void **data,
                              int max_depth, int signal, intptr_t pc);

int vmp_native_enabled(void);
int vmp_native_enable(void);
int vmp_ignore_ip(intptr_t ip);
int vmp_binary_search_ranges(intptr_t ip, intptr_t * l, int count);
int vmp_native_symbols_read(void);
void vmp_profile_lines(int);
int vmp_profiles_python_lines(void);

int vmp_ignore_symbol_count(void);
intptr_t * vmp_ignore_symbols(void);
void vmp_set_ignore_symbols(intptr_t * symbols, int count);
void vmp_native_disable(void);

#ifdef __unix__
int vmp_read_vmaps(const char * fname);
#endif
