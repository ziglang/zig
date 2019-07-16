/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <process.h>
#include <stdlib.h>

#define _EXIT_LOCK1 8

void __cdecl _lock (int _File);
void __cdecl _unlock (int _File);

int __cdecl _initialize_onexit_table(_onexit_table_t *table)
{
    if (!table) return -1;
    table->_first = table->_last = table->_end = NULL;
    return 0;
}

int __cdecl _register_onexit_function(_onexit_table_t *table, _onexit_t func)
{
    if (!table) return -1;

    _lock(_EXIT_LOCK1);

    if (!table->_first) {
        table->_first = calloc(32, sizeof(void*));
        if (!table->_first) {
            _unlock(_EXIT_LOCK1);
            return -1;
        }
        table->_last = table->_first;
        table->_end = table->_first + 32;
    }

    if (table->_last == table->_end) {
        size_t len = table->_end - table->_first;
        _PVFV *new_buf = realloc(table->_first, len * sizeof(void*) * 2);
        if (!new_buf) {
            _unlock(_EXIT_LOCK1);
            return -1;
        }
        table->_first = new_buf;
        table->_last = new_buf + len;
        table->_end = new_buf + len * 2;
    }

    *table->_last++ = (_PVFV)func;
    _unlock(_EXIT_LOCK1);
    return 0;
}

int __cdecl _execute_onexit_table(_onexit_table_t *table)
{
    _PVFV *first, *last;

    _lock(_EXIT_LOCK1);
    first = table->_first;
    last = table->_last;
    _initialize_onexit_table(table);
    _unlock(_EXIT_LOCK1);

    if (!first) return 0;

    while (--last >= first)
        if (*last)
            (**last)();

    free(first);
    return 0;
}

typeof(_initialize_onexit_table) *__MINGW_IMP_SYMBOL(_initialize_onexit_table) = _initialize_onexit_table;
typeof(_register_onexit_function) *__MINGW_IMP_SYMBOL(_register_onexit_function) = _register_onexit_function;
typeof(_execute_onexit_table) *__MINGW_IMP_SYMBOL(_execute_onexit_table) = _execute_onexit_table;
