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

test "reflection: function return type and var args" {
    comptime {
        assert(@typeOf(dummy).ReturnType == i32);
        assert(!@typeOf(dummy).is_var_args);
        assert(@typeOf(dummy_varargs).is_var_args);
    }
}

fn dummy() -> i32 { 1234 }
fn dummy_varargs(args: ...) {}
