#if defined(_REENTRANT)
#include <stdatomic.h>
extern void __wasi_init_tp(void);
#endif
extern void __wasm_call_ctors(void);

__attribute__((export_name("_initialize")))
void _initialize(void) {
#if defined(_REENTRANT)
    static volatile atomic_int initialized = 0;
    int expected = 0;
    if (!atomic_compare_exchange_strong(&initialized, &expected, 1)) {
        __builtin_trap();
    }

    __wasi_init_tp();
#else
    static volatile int initialized = 0;
    if (initialized != 0) {
        __builtin_trap();
    }
    initialized = 1;
#endif

    // The linker synthesizes this to call constructors.
    __wasm_call_ctors();
}
