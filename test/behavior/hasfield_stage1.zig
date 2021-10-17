const expect = @import("std").testing.expect;
const builtin = @import("builtin");

test "@hasField" {
    const struc = struct {
        a: i32,
        b: []const u8,

        pub const nope = 1;
    };
    try expect(@hasField(struc, "a") == true);
    try expect(@hasField(struc, "b") == true);
    try expect(@hasField(struc, "non-existant") == false);
    try expect(@hasField(struc, "nope") == false);

    const unin = union {
        a: u64,
        b: []const u16,

        pub const nope = 1;
    };
    try expect(@hasField(unin, "a") == true);
    try expect(@hasField(unin, "b") == true);
    try expect(@hasField(unin, "non-existant") == false);
    try expect(@hasField(unin, "nope") == false);
}
