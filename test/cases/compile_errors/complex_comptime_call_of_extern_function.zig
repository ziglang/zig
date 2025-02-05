extern fn next_id() u32;

const Foo = struct {
    bar: Bar,

    fn init() Foo {
        return .{ .bar = .init() };
    }
};
const Bar = struct {
    qux: ?Qux,
    id: u32,

    fn init() Bar {
        return .{
            .qux = null,
            .id = next_id(),
        };
    }
};
const Qux = struct {
    handleThing: fn () void,
};

export fn entry() void {
    const foo: Foo = .init();
    _ = foo;
}

// error
//
// :17:26: error: comptime call of extern function
// :7:31: note: called at comptime from here
// :26:27: note: called at comptime from here
// :26:27: note: call to function with comptime-only return type 'tmp.Foo' is evaluated at comptime
// :6:15: note: return type declared here
// :4:10: note: struct requires comptime because of this field
// :11:10: note: struct requires comptime because of this field
// :22:18: note: struct requires comptime because of this field
// :22:18: note: use '*const fn () void' for a function pointer type
