const expect = @import("std").testing.expect;

const HasFuncs = struct {
    state: u32,
    func_field: fn (u32) u32,

    fn inc(self: *HasFuncs) void {
        self.state += 1;
    }

    fn get(self: HasFuncs) u32 {
        return self.state;
    }

    fn getPtr(self: *const HasFuncs) *const u32 {
        return &self.state;
    }

    fn one(_: u32) u32 {
        return 1;
    }
    fn two(_: u32) u32 {
        return 2;
    }
};

test "standard field calls" {
    try expect(HasFuncs.one(0) == 1);
    try expect(HasFuncs.two(0) == 2);

    var v: HasFuncs = undefined;
    v.state = 0;
    v.func_field = HasFuncs.one;

    const pv = &v;
    const pcv: *const HasFuncs = pv;

    try expect(v.get() == 0);
    v.inc();
    try expect(v.state == 1);
    try expect(v.get() == 1);

    pv.inc();
    try expect(v.state == 2);
    try expect(pv.get() == 2);
    try expect(v.getPtr().* == 2);
    try expect(pcv.get() == 2);
    try expect(pcv.getPtr().* == 2);

    v.func_field = HasFuncs.one;
    try expect(v.func_field(0) == 1);
    try expect(pv.func_field(0) == 1);
    try expect(pcv.func_field(0) == 1);

    try expect(pcv.func_field(blk: {
        pv.func_field = HasFuncs.two;
        break :blk 0;
    }) == 1);

    v.func_field = HasFuncs.two;
    try expect(v.func_field(0) == 2);
    try expect(pv.func_field(0) == 2);
    try expect(pcv.func_field(0) == 2);
}

test "@field field calls" {
    try expect(@field(HasFuncs, "one")(0) == 1);
    try expect(@field(HasFuncs, "two")(0) == 2);

    var v: HasFuncs = undefined;
    v.state = 0;
    v.func_field = HasFuncs.one;

    const pv = &v;
    const pcv: *const HasFuncs = pv;

    try expect(@field(v, "get")() == 0);
    @field(v, "inc")();
    try expect(v.state == 1);
    try expect(@field(v, "get")() == 1);

    @field(pv, "inc")();
    try expect(v.state == 2);
    try expect(@field(pv, "get")() == 2);
    try expect(@field(v, "getPtr")().* == 2);
    try expect(@field(pcv, "get")() == 2);
    try expect(@field(pcv, "getPtr")().* == 2);

    v.func_field = HasFuncs.one;
    try expect(@field(v, "func_field")(0) == 1);
    try expect(@field(pv, "func_field")(0) == 1);
    try expect(@field(pcv, "func_field")(0) == 1);

    try expect(@field(pcv, "func_field")(blk: {
        pv.func_field = HasFuncs.two;
        break :blk 0;
    }) == 1);

    v.func_field = HasFuncs.two;
    try expect(@field(v, "func_field")(0) == 2);
    try expect(@field(pv, "func_field")(0) == 2);
    try expect(@field(pcv, "func_field")(0) == 2);
}
