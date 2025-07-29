//! Whew, that filename is a bit of a mouthful!
//! To maximise consistency with other parts of the language, function arguments expressions are
//! only *evaluated* at comptime if the parameter is declared `comptime`. If the parameter type is
//! comptime-only, but the parameter is not declared `comptime`, the evaluation happens at runtime,
//! and the value is just comptime-resolved.

export fn foo() void {
    // This function is itself generic, with the comptime-only parameter being generic.
    simpleGeneric(type, if (cond()) u8 else u16);
}

export fn bar() void {
    // This function is not generic; once `Wrapper` is called, its parameter type is immediately known.
    Wrapper(type).inner(if (cond()) u8 else u16);
}

fn simpleGeneric(comptime T: type, _: T) void {}

fn Wrapper(comptime T: type) type {
    return struct {
        fn inner(_: T) void {}
    };
}

fn cond() bool {
    return true;
}

// error
//
// :9:25: error: value with comptime-only type 'type' depends on runtime control flow
// :9:33: note: runtime control flow here
// :9:25: note: types are not available at runtime
// :14:25: error: value with comptime-only type 'type' depends on runtime control flow
// :14:33: note: runtime control flow here
// :14:25: note: types are not available at runtime
