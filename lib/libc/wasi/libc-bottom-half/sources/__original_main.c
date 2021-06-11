// Old compilers define `__original_main`. If that doesn't exist, we
// get called here. New compilers define `__main_void`. If that doesn't
// exist, we'll try something else.
// TODO: Remove this layer when we no longer have to support old compilers.
int __main_void(void);

__attribute__((weak))
int __original_main(void) {
    return __main_void();
}
