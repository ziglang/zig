<img src="https://aro.vexu.eu/aro-logo.svg" alt="Aro" width="120px"/>

# Aro

A C compiler with the goal of providing fast compilation and low memory usage with good diagnostics.

Aro is included as an alternative C frontend in the [Zig compiler](https://github.com/ziglang/zig)
for `translate-c` and eventually compiling C files by translating them to Zig first.
Aro is developed in https://github.com/Vexu/arocc and the Zig dependency is
updated from there when needed.

Currently most of standard C is supported up to C23 and as are many of the common
extensions from GNU, MSVC, and Clang

Basic code generation is supported for x86-64 linux and can produce a valid hello world:
```sh-session
$ cat hello.c
extern int printf(const char *restrict fmt, ...);
int main(void) {
    printf("Hello, world!\n");
    return 0;
}
$ zig build && ./zig-out/bin/arocc hello.c -o hello
$ ./hello
Hello, world!
```
