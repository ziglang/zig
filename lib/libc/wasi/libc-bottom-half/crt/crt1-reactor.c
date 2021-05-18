extern void __wasm_call_ctors(void);

__attribute__((export_name("_initialize")))
void _initialize(void) {
    // The linker synthesizes this to call constructors.
    __wasm_call_ctors();
}
