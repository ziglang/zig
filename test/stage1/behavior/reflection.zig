const expect = @import("std").testing.expect;
const mem = @import("std").mem;
const reflection = @This();

test "reflection: array, pointer, optional, error union type child" {
    comptime {
        expect(([10]u8).Child == u8);
        expect((*u8).Child == u8);
        expect((anyerror!u8).Payload == u8);
        expect((?u8).Child == u8);
    }
}

test "reflection: function return type, var args, and param types" {
    comptime {
        expect(@TypeOf(dummy).ReturnType == i32);
        expect(!@TypeOf(dummy).is_var_args);
        expect(@TypeOf(dummy).arg_count == 3);
        expect(@ArgType(@TypeOf(dummy), 0) == bool);
        expect(@ArgType(@TypeOf(dummy), 1) == i32);
        expect(@ArgType(@TypeOf(dummy), 2) == f32);
    }
}

fn dummy(a: bool, b: i32, c: f32) i32 {
    return 1234;
}

test "reflection: struct member types and names" {
    comptime {
        expect(@memberCount(Foo) == 3);

        expect(@memberType(Foo, 0) == i32);
        expect(@memberType(Foo, 1) == bool);
        expect(@memberType(Foo, 2) == void);

        expect(mem.eql(u8, @memberName(Foo, 0), "one"));
        expect(mem.eql(u8, @memberName(Foo, 1), "two"));
        expect(mem.eql(u8, @memberName(Foo, 2), "three"));
    }
}

test "reflection: enum member types and names" {
    comptime {
        expect(@memberCount(Bar) == 4);

        expect(@memberType(Bar, 0) == void);
        expect(@memberType(Bar, 1) == i32);
        expect(@memberType(Bar, 2) == bool);
        expect(@memberType(Bar, 3) == f64);

        expect(mem.eql(u8, @memberName(Bar, 0), "One"));
        expect(mem.eql(u8, @memberName(Bar, 1), "Two"));
        expect(mem.eql(u8, @memberName(Bar, 2), "Three"));
        expect(mem.eql(u8, @memberName(Bar, 3), "Four"));
    }
}

test "reflection: @field" {
    var f = Foo{
        .one = 42,
        .two = true,
        .three = void{},
    };

    expect(f.one == f.one);
    expect(@field(f, "o" ++ "ne") == f.one);
    expect(@field(f, "t" ++ "wo") == f.two);
    expect(@field(f, "th" ++ "ree") == f.three);
    expect(@field(Foo, "const" ++ "ant") == Foo.constant);
    expect(@field(Bar, "O" ++ "ne") == Bar.One);
    expect(@field(Bar, "T" ++ "wo") == Bar.Two);
    expect(@field(Bar, "Th" ++ "ree") == Bar.Three);
    expect(@field(Bar, "F" ++ "our") == Bar.Four);
    expect(@field(reflection, "dum" ++ "my")(true, 1, 2) == dummy(true, 1, 2));
    @field(f, "o" ++ "ne") = 4;
    expect(f.one == 4);
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
