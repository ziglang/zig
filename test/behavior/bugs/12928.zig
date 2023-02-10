const std = @import("std");
const expect = std.testing.expect;
const A = extern struct {
    value: *volatile B,
};
const B = extern struct {
    a: u32,
    b: i32,
};
test {
    var a: *A = undefined;
    try expect(@TypeOf(&a.value.a) == *volatile u32);
    try expect(@TypeOf(&a.value.b) == *volatile i32);
}
const C = extern struct {
    value: *volatile D,
};
const D = extern union {
    a: u32,
    b: i32,
};
test {
    var c: *C = undefined;
    try expect(@TypeOf(&c.value.a) == *volatile u32);
    try expect(@TypeOf(&c.value.b) == *volatile i32);
}
