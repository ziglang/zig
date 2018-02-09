const assert = @import("std").debug.assert;
const mem = @import("std").mem;

test "reflection: array, pointer, nullable, error union type child" {
    comptime {
        assert(([10]u8).Child == u8);
        assert((&u8).Child == u8);
        assert((error!u8).Payload == u8);
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

fn dummy(a: bool, b: i32, c: f32) i32 { return 1234; }
fn dummy_varargs(args: ...) void {}

test "reflection: struct member types and names" {
    comptime {
        assert(@memberCount(Foo) == 3);

        assert(@memberType(Foo, 0) == i32);
        assert(@memberType(Foo, 1) == bool);
        assert(@memberType(Foo, 2) == void);

        assert(mem.eql(u8, @memberName(Foo, 0), "one"));
        assert(mem.eql(u8, @memberName(Foo, 1), "two"));
        assert(mem.eql(u8, @memberName(Foo, 2), "three"));
    }
}

test "reflection: enum member types and names" {
    comptime {
        assert(@memberCount(Bar) == 4);

        assert(@memberType(Bar, 0) == void);
        assert(@memberType(Bar, 1) == i32);
        assert(@memberType(Bar, 2) == bool);
        assert(@memberType(Bar, 3) == f64);

        assert(mem.eql(u8, @memberName(Bar, 0), "One"));
        assert(mem.eql(u8, @memberName(Bar, 1), "Two"));
        assert(mem.eql(u8, @memberName(Bar, 2), "Three"));
        assert(mem.eql(u8, @memberName(Bar, 3), "Four"));
    }

}

const Foo = struct {
    one: i32,
    two: bool,
    three: void,
};

const Bar = union(enum) {
    One: void,
    Two: i32,
    Three: bool,
    Four: f64,
};
