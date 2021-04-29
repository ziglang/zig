const expect = @import("std").testing.expect;
const mem = @import("std").mem;
const reflection = @This();

test "reflection: function return type, var args, and param types" {
    comptime {
        const info = @typeInfo(@TypeOf(dummy)).Fn;
        expect(info.return_type.? == i32);
        expect(!info.is_var_args);
        expect(info.args.len == 3);
        expect(info.args[0].arg_type.? == bool);
        expect(info.args[1].arg_type.? == i32);
        expect(info.args[2].arg_type.? == f32);
    }
}

fn dummy(a: bool, b: i32, c: f32) i32 {
    return 1234;
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
