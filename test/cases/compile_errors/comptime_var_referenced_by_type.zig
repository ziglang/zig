const Wrapper = struct { ptr: *ComptimeThing };

const ComptimeThing = struct {
    x: comptime_int,
    fn NewType(comptime ct: *ComptimeThing) type {
        const wrapper: Wrapper = .{ .ptr = ct };
        return struct {
            pub fn foo() void {
                _ = wrapper.ct;
            }
        };
    }
};

comptime {
    var ct: ComptimeThing = .{ .x = 123 };
    const Inner = ct.NewType();
    Inner.foo();
}

// error
//
// :7:16: error: captured value contains reference to comptime var
// :7:16: note: 'wrapper' points to '@as(*const tmp.Wrapper, @ptrCast(&v0)).*', where
// :16:5: note: 'v0.ptr' points to comptime var declared here
// :17:29: note: called at comptime here
