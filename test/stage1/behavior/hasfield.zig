const expect = @import("std").testing.expect;
const builtin = @import("builtin");

test "@hasField" {
    const struc = struct {
        a: i32,
        b: []u8,
    };
    expect(@hasField(struc, "a") == true);
    expect(@hasField(struc, "b") == true);
    expect(@hasField(struc, "non-existant") == false);

    const unin = union {
        a: u64,
        b: []u16,
    };
    expect(@hasField(unin, "a") == true);
    expect(@hasField(unin, "b") == true);
    expect(@hasField(unin, "non-existant") == false);

    const enm = enum {
        a,
        b,
    };
    expect(@hasField(enm, "a") == true);
    expect(@hasField(enm, "b") == true);
    expect(@hasField(enm, "non-existant") == false);

    expect(@hasField(builtin, "os") == true);
}
