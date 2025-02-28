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
// :16:30: note: 'wrapper.ptr' points to comptime var declared here
// :17:29: note: called from here
