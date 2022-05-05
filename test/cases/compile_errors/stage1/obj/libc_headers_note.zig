const c = @cImport(@cInclude("stdio.h"));
export fn entry() void {
    _ = c.printf("hello, world!\n");
}

// error
// backend=stage1
// is_test=1
// target=native-linux
//
// tmp.zig:1:11: error: C import failed
// tmp.zig:1:11: note: libc headers not available; compilation does not link against libc
