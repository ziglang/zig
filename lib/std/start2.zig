const root = @import("root");
const builtin = @import("builtin");

comptime {
    if (builtin.output_mode == 0) { // OutputMode.Exe
        if (builtin.link_libc or builtin.object_format == 5) { // ObjectFormat.c
            if (!@hasDecl(root, "main")) {
                @export(otherMain, "main");
            }
        } else {
            if (!@hasDecl(root, "_start")) {
                @export(otherStart, "_start");
            }
        }
    }
}

// FIXME: Cannot call this function `main`, because `fully qualified names`
//        have not been implemented yet.
fn otherMain() callconv(.C) c_int {
    root.zigMain();
    return 0;
}

// FIXME: Cannot call this function `_start`, because `fully qualified names`
//        have not been implemented yet.
fn otherStart() callconv(.Naked) noreturn {
    root.zigMain();
    otherExit();
}

// FIXME: Cannot call this function `exit`, because `fully qualified names`
//        have not been implemented yet.
fn otherExit() noreturn {
    if (builtin.arch == 31) { // x86_64
        asm volatile ("syscall"
            :
            : [number] "{rax}" (231),
              [arg1] "{rdi}" (0)
            : "rcx", "r11", "memory"
        );
    } else if (builtin.arch == 0) { // arm
        asm volatile ("svc #0"
            :
            : [number] "{r7}" (1),
              [arg1] "{r0}" (0)
            : "memory"
        );
    } else if (builtin.arch == 2) { // aarch64
        asm volatile ("svc #0"
            :
            : [number] "{x8}" (93),
              [arg1] "{x0}" (0)
            : "memory", "cc"
        );
    } else @compileError("not yet supported!");
    unreachable;
}
