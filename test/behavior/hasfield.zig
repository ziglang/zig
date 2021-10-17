const expect = @import("std").testing.expect;
const builtin = @import("builtin");

test "@hasField" {
    const enm = enum {
        a,
        b,

        pub const nope = 1;
    };
    try expect(@hasField(enm, "a") == true);
    try expect(@hasField(enm, "b") == true);
    try expect(@hasField(enm, "non-existant") == false);
    try expect(@hasField(enm, "nope") == false);
}
