#include <wasi/api.h>
#include <stdlib.h>
extern void __wasm_call_ctors(void);
extern int __original_main(void);
extern void __wasm_call_dtors(void);

__attribute__((export_name("_start")))
void _start(void) {
    // Call `__original_main` which will either be the application's zero-argument
    // `__original_main` function or a libc routine which calls `__main_void`.
    // TODO: Call `main` directly once we no longer have to support old compilers.
    int r = __original_main();

    // If main exited successfully, just return, otherwise call `exit`.
    if (r != 0) {
        exit(r);
    }
}
