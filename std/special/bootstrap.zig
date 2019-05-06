// This file is in a package which has the root source file exposed as "@root".
// It is included in the compilation unit when exporting an executable.

const root = @import("@root");
const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

var argc_ptr: [*]usize = undefined;

comptime {
    const strong_linkage = builtin.GlobalLinkage.Strong;
    if (builtin.link_libc) {
        @export("main", main, strong_linkage);
    } else if (builtin.os == builtin.Os.windows) {
        @export("WinMainCRTStartup", WinMainCRTStartup, strong_linkage);
    } else {
        @export("_start", _start, strong_linkage);
    }
}

nakedcc fn _start() noreturn {
    if (builtin.os == builtin.Os.wasi) {
        std.os.wasi.proc_exit(callMain());
    }

    switch (builtin.arch) {
        builtin.Arch.x86_64 => {
            argc_ptr = asm ("lea (%%rsp), %[argc]"
                : [argc] "=r" (-> [*]usize)
            );
        },
        builtin.Arch.i386 => {
            argc_ptr = asm ("lea (%%esp), %[argc]"
                : [argc] "=r" (-> [*]usize)
            );
        },
        builtin.Arch.aarch64, builtin.Arch.aarch64_be => {
            argc_ptr = asm ("mov %[argc], sp"
                : [argc] "=r" (-> [*]usize)
            );
        },
        else => @compileError("unsupported arch"),
    }
    // If LLVM inlines stack variables into _start, they will overwrite
    // the command line argument data.
    @noInlineCall(posixCallMainAndExit);
}

extern fn WinMainCRTStartup() noreturn {
    @setAlignStack(16);
    if (!builtin.single_threaded) {
        _ = @import("bootstrap_windows_tls.zig");
    }
    std.os.windows.ExitProcess(callMain());
}

// TODO https://github.com/ziglang/zig/issues/265
fn posixCallMainAndExit() noreturn {
    if (builtin.os == builtin.Os.freebsd) {
        @setAlignStack(16);
    }
    const argc = argc_ptr[0];
    const argv = @ptrCast([*][*]u8, argc_ptr + 1);

    const envp_optional = @ptrCast([*]?[*]u8, argv + argc + 1);
    var envp_count: usize = 0;
    while (envp_optional[envp_count]) |_| : (envp_count += 1) {}
    const envp = @ptrCast([*][*]u8, envp_optional)[0..envp_count];
    if (builtin.os == builtin.Os.linux) {
        // Scan auxiliary vector.
        const auxv = @ptrCast([*]std.elf.Auxv, envp.ptr + envp_count + 1);
        std.os.linux_elf_aux_maybe = auxv;
        var i: usize = 0;
        var at_phdr: usize = 0;
        var at_phnum: usize = 0;
        var at_phent: usize = 0;
        while (auxv[i].a_un.a_val != 0) : (i += 1) {
            switch (auxv[i].a_type) {
                std.elf.AT_PAGESZ => assert(auxv[i].a_un.a_val == std.os.page_size),
                std.elf.AT_PHDR => at_phdr = auxv[i].a_un.a_val,
                std.elf.AT_PHNUM => at_phnum = auxv[i].a_un.a_val,
                std.elf.AT_PHENT => at_phent = auxv[i].a_un.a_val,
                else => {},
            }
        }
        if (!builtin.single_threaded) linuxInitializeThreadLocalStorage(at_phdr, at_phnum, at_phent);
    }

    std.os.posix.exit(callMainWithArgs(argc, argv, envp));
}

// This is marked inline because for some reason LLVM in release mode fails to inline it,
// and we want fewer call frames in stack traces.
inline fn callMainWithArgs(argc: usize, argv: [*][*]u8, envp: [][*]u8) u8 {
    std.os.ArgIteratorPosix.raw = argv[0..argc];
    std.os.posix_environ_raw = envp;
    return callMain();
}

extern fn main(c_argc: i32, c_argv: [*][*]u8, c_envp: [*]?[*]u8) i32 {
    var env_count: usize = 0;
    while (c_envp[env_count] != null) : (env_count += 1) {}
    const envp = @ptrCast([*][*]u8, c_envp)[0..env_count];
    return callMainWithArgs(@intCast(usize, c_argc), c_argv, envp);
}

// This is marked inline because for some reason LLVM in release mode fails to inline it,
// and we want fewer call frames in stack traces.
inline fn callMain() u8 {
    switch (@typeId(@typeOf(root.main).ReturnType)) {
        builtin.TypeId.NoReturn => {
            root.main();
        },
        builtin.TypeId.Void => {
            root.main();
            return 0;
        },
        builtin.TypeId.Int => {
            if (@typeOf(root.main).ReturnType.bit_count != 8) {
                @compileError("expected return type of main to be 'u8', 'noreturn', 'void', or '!void'");
            }
            return root.main();
        },
        builtin.TypeId.ErrorUnion => {
            root.main() catch |err| {
                std.debug.warn("error: {}\n", @errorName(err));
                if (builtin.os != builtin.Os.zen) {
                    if (@errorReturnTrace()) |trace| {
                        std.debug.dumpStackTrace(trace.*);
                    }
                }
                return 1;
            };
            return 0;
        },
        else => @compileError("expected return type of main to be 'u8', 'noreturn', 'void', or '!void'"),
    }
}

const main_thread_tls_align = 32;
var main_thread_tls_bytes: [64]u8 align(main_thread_tls_align) = [1]u8{0} ** 64;

fn linuxInitializeThreadLocalStorage(at_phdr: usize, at_phnum: usize, at_phent: usize) void {
    var phdr_addr = at_phdr;
    var n = at_phnum;
    var base: usize = 0;
    while (n != 0) : ({
        n -= 1;
        phdr_addr += at_phent;
    }) {
        const phdr = @intToPtr(*std.elf.Phdr, phdr_addr);
        // TODO look for PT_DYNAMIC when we have https://github.com/ziglang/zig/issues/1917
        switch (phdr.p_type) {
            std.elf.PT_PHDR => base = at_phdr - phdr.p_vaddr,
            std.elf.PT_TLS => std.os.linux_tls_phdr = phdr,
            else => continue,
        }
    }
    const tls_phdr = std.os.linux_tls_phdr orelse return;
    std.os.linux_tls_img_src = @intToPtr([*]const u8, base + tls_phdr.p_vaddr);
    const end_addr = @ptrToInt(&main_thread_tls_bytes) + tls_phdr.p_memsz;
    const max_end_addr = @ptrToInt(&main_thread_tls_bytes) + main_thread_tls_bytes.len;
    assert(max_end_addr >= end_addr + @sizeOf(usize)); // not enough preallocated Thread Local Storage
    assert(main_thread_tls_align >= tls_phdr.p_align); // preallocated Thread Local Storage not aligned enough
    @memcpy(&main_thread_tls_bytes, std.os.linux_tls_img_src, tls_phdr.p_filesz);
    const end_ptr = @intToPtr(*usize, end_addr);
    end_ptr.* = end_addr;
    linuxSetThreadArea(end_addr);
}

fn linuxSetThreadArea(addr: usize) void {
    switch (builtin.arch) {
        builtin.Arch.x86_64 => {
            const ARCH_SET_FS = 0x1002;
            const rc = std.os.linux.syscall2(std.os.linux.SYS_arch_prctl, ARCH_SET_FS, addr);
            // acrh_prctl is documented to never fail
            assert(rc == 0);
        },
        builtin.Arch.aarch64 => {
            asm volatile (
                \\        msr tpidr_el0,x0
                \\        mov w0,#0
                \\        ret
            );
        },
        else => @compileError("Unsupported architecture"),
    }
}
