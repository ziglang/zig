// New compilers define `__main_argc_argv`. If that doesn't exist, we
// may get called here. Old compilers define `main` expecting an
// argv/argc, so call that.
// TODO: Remove this layer when we no longer have to support old compilers.
int __wasilibc_main(int argc, char *argv[]) asm("main");

__attribute__((weak, nodebug))
int __main_argc_argv(int argc, char *argv[]) {
    return __wasilibc_main(argc, argv);
}
