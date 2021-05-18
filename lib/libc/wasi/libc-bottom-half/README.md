# WASI libc "bottom half".

The WASI libc "bottom half" is conceptually the lower half of a traditional libc
implementation, consisting of C interfaces to the low-level WASI syscalls.

This implementation is partially derived from the "bottom half" of [cloudlibc],
revision 8835639f27fc42d32096d59d294a0bbb857dc368.

[cloudlibc]: https://github.com/NuxiNL/cloudlibc

This implementation includes preopen functionality, which emulates POSIX APIs
accepting absolute paths by translating them into pre-opened directory handles
and relative paths that can be opened with `openat`. This technique is inspired
by [libpreopen], however the implementation here is designed to be built into
libc rather than to be a layer on top of libc.

[libpreopen]: https://github.com/musec/libpreopen

The WASI libc lower half currently depends on the dlmalloc component.
