const assert = @import("std").debug.assert;
const mem = @import("std").mem;

test "reflection: array, pointer, nullable, error union type child" {
    comptime {
        assert(([10]u8).Child == u8);
        assert((&u8).Child == u8);
        assert((%u8).Child == u8);
        assert((?u8).Child == u8);
    }
}

test "reflection: function return type, var args, and param types" {
    comptime {
        assert(@typeOf(dummy).ReturnType == i32);
        assert(!@typeOf(dummy).is_var_args);
        assert(@typeOf(dummy_varargs).is_var_args);
        assert(@typeOf(dummy).arg_count == 3);
        assert(@ArgType(@typeOf(dummy), 0) == bool);
        assert(@ArgType(@typeOf(dummy), 1) == i32);
        assert(@ArgType(@typeOf(dummy), 2) == f32);
    }
}

fn dummy(a: bool, b: i32, c: f32) -> i32 { 1234 }
fn dummy_varargs(args: ...) {}

