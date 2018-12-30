const assertOrPanic = @import("std").debug.assertOrPanic;
const mem = @import("std").mem;
const reflection = @This();

test "reflection: array, pointer, optional, error union type child" {
    comptime {
        assertOrPanic(([10]u8).Child == u8);
        assertOrPanic((*u8).Child == u8);
        assertOrPanic((anyerror!u8).Payload == u8);
        assertOrPanic((?u8).Child == u8);
    }
}

test "reflection: function return type, var args, and param types" {
    comptime {
        assertOrPanic(@typeOf(dummy).ReturnType == i32);
        assertOrPanic(!@typeOf(dummy).is_var_args);
        assertOrPanic(@typeOf(dummy_varargs).is_var_args);
        assertOrPanic(@typeOf(dummy).arg_count == 3);
        assertOrPanic(@ArgType(@typeOf(dummy), 0) == bool);
        assertOrPanic(@ArgType(@typeOf(dummy), 1) == i32);
        assertOrPanic(@ArgType(@typeOf(dummy), 2) == f32);
    }
}

fn dummy(a: bool, b: i32, c: f32) i32 {
    return 1234;
}
fn dummy_varargs(args: ...) void {}

test "reflection: struct member types and names" {
    comptime {
        assertOrPanic(@memberCount(Foo) == 3);

        assertOrPanic(@memberType(Foo, 0) == i32);
        assertOrPanic(@memberType(Foo, 1) == bool);
        assertOrPanic(@memberType(Foo, 2) == void);

        assertOrPanic(mem.eql(u8, @memberName(Foo, 0), "one"));
        assertOrPanic(mem.eql(u8, @memberName(Foo, 1), "two"));
        assertOrPanic(mem.eql(u8, @memberName(Foo, 2), "three"));
    }
}

test "reflection: enum member types and names" {
    comptime {
        assertOrPanic(@memberCount(Bar) == 4);

        assertOrPanic(@memberType(Bar, 0) == void);
        assertOrPanic(@memberType(Bar, 1) == i32);
        assertOrPanic(@memberType(Bar, 2) == bool);
        assertOrPanic(@memberType(Bar, 3) == f64);

        assertOrPanic(mem.eql(u8, @memberName(Bar, 0), "One"));
        assertOrPanic(mem.eql(u8, @memberName(Bar, 1), "Two"));
        assertOrPanic(mem.eql(u8, @memberName(Bar, 2), "Three"));
        assertOrPanic(mem.eql(u8, @memberName(Bar, 3), "Four"));
    }
}

test "reflection: @field" {
    var f = Foo{
        .one = 42,
        .two = true,
        .three = void{},
    };

    assertOrPanic(f.one == f.one);
    assertOrPanic(@field(f, "o" ++ "ne") == f.one);
    assertOrPanic(@field(f, "t" ++ "wo") == f.two);
    assertOrPanic(@field(f, "th" ++ "ree") == f.three);
    assertOrPanic(@field(Foo, "const" ++ "ant") == Foo.constant);
    assertOrPanic(@field(Bar, "O" ++ "ne") == Bar.One);
    assertOrPanic(@field(Bar, "T" ++ "wo") == Bar.Two);
    assertOrPanic(@field(Bar, "Th" ++ "ree") == Bar.Three);
    assertOrPanic(@field(Bar, "F" ++ "our") == Bar.Four);
    assertOrPanic(@field(reflection, "dum" ++ "my")(true, 1, 2) == dummy(true, 1, 2));
    @field(f, "o" ++ "ne") = 4;
    assertOrPanic(f.one == 4);
}

const Foo = struct {
    const constant = 52;

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

