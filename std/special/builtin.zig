// These functions are provided when not linking against libc because LLVM
// sometimes generates code that calls them.

// Note that these functions do not return `dest`, like the libc API.
// The semantics of these functions is dictated by the corresponding
// LLVM intrinsics, not by the libc API.
const builtin = @import("builtin");

export fn memset(dest: ?&u8, c: u8, n: usize) {
    @setDebugSafety(this, false);

    if (n == 0)
        return;

    const d = ??dest;
    var index: usize = 0;
    while (index != n; index += 1)
        d[index] = c;
}

export fn memcpy(noalias dest: ?&u8, noalias src: ?&const u8, n: usize) {
    @setDebugSafety(this, false);

    if (n == 0)
        return;

    const d = ??dest;
    const s = ??src;
    var index: usize = 0;
    while (index != n; index += 1)
        d[index] = s[index];
}

export fn __stack_chk_fail() {
    if (builtin.mode == builtin.Mode.ReleaseFast) {
        @setGlobalLinkage(__stack_chk_fail, builtin.GlobalLinkage.Internal);
        unreachable;
    }
    @panic("stack smashing detected");
}
