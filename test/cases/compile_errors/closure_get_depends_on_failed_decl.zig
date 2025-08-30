pub inline fn instanceRequestAdapter() void {}

pub inline fn requestAdapter(
    comptime callbackArg: fn () callconv(.@"inline") void,
) void {
    _ = &(struct {
        pub fn callback() callconv(.c) void {
            callbackArg();
        }
    }).callback;
    instanceRequestAdapter(undefined); // note wrong number of arguments here
}

inline fn foo() void {}

pub export fn entry() void {
    requestAdapter(foo);
}

// error
//
// :11:5: error: expected 0 argument(s), found 1
// :1:12: note: function declared here
// :17:19: note: called inline here
