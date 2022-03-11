const expect = @import("std").testing.expect;
const builtin = @import("builtin");

test "@hasField" {
    const struc = struct {
        a: i32,
        b: []u8,

        pub const nope = 1;
    };
    try expect(@hasField(struc, "a") == true);
    try expect(@hasField(struc, "b") == true);
    try expect(@hasField(struc, "non-existant") == false);
    try expect(@hasField(struc, "nope") == false);

    const unin = union {
        a: u64,
        b: []u16,

        pub const nope = 1;
    };
    try expect(@hasField(unin, "a") == true);
    try expect(@hasField(unin, "b") == true);
    try expect(@hasField(unin, "non-existant") == false);
    try expect(@hasField(unin, "nope") == false);

    const enm = enum {
        a,
        b,

        pub const nope = 1;
    };
    try expect(@hasField(enm, "a") == true);
    try expect(@hasField(enm, "b") == true);
    try expect(@hasField(enm, "non-existant") == false);
    try expect(@hasField(enm, "nope") == false);

    const anon = @TypeOf(.{ .a = 1 });
    try expect(@hasField(anon, "a") == true);
    try expect(@hasField(anon, "b") == false);

    const tuple = @TypeOf(.{ 1, 2 });
    try expect(@hasField(tuple, "a") == false);
    try expect(@hasField(tuple, "b") == false);
    try expect(@hasField(tuple, "0") == true);
    try expect(@hasField(tuple, "1") == true);
    try expect(@hasField(tuple, "2") == false);
    try expect(@hasField(tuple, "9999999999999999999999999") == false);
}
