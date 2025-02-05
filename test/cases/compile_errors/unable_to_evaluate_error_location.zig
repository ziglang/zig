export fn Demo(chr: u8) c_int {
    var buf = [_]u8{chr};
    _ = Foo.init(&buf);
    return 0;
}

const ImAlreadyAType = []u8;

const Foo = struct {
    what: @TypeOf(ImAlreadyAType),
    pub fn init(foo: []u8) Foo {
        _ = foo;
        return Foo{ .what = &.{} };
    }
};

// error
// target=native
// backend=stage2
//
// :3:18: error: unable to resolve comptime value
// :3:17: note: call to function with comptime-only return type 'tmp.Foo' is evaluated at comptime
// :11:28: note: return type declared here
// :10:11: note: struct requires comptime because of this field
// :10:11: note: types are not available at runtime
