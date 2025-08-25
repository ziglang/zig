extern "" var a: u32;
extern "" fn b() void;

extern "\x00" var c: u32;
extern "\x00" fn d() void;

test "" {}
test "\x00" {}

const e = @import("");
const f = @import("\x00");

comptime {
    const @"" = undefined;
}
comptime {
    const @"\x00" = undefined;
}

// error
// backend=stage2
// target=native
//
// :1:8: error: library name cannot be empty
// :2:8: error: library name cannot be empty
// :4:8: error: library name cannot contain null bytes
// :5:8: error: library name cannot contain null bytes
// :7:6: error: empty test name must be omitted
// :8:6: error: test name cannot contain null bytes
// :10:19: error: import path cannot be empty
// :11:19: error: import path cannot contain null bytes
// :14:11: error: identifier cannot be empty
// :17:11: error: identifier cannot contain null bytes
