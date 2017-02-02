const assert = @import("std").debug.assert;

fn initStaticArray() -> [10]i32 {
    var array: [10]i32 = undefined;
    array[0] = 1;
    array[4] = 2;
    array[7] = 3;
    array[9] = 4;
    return array;
}
const static_array = initStaticArray();
fn initStaticArrayToUndefined() {
    @setFnTest(this);

    assert(static_array[0] == 1);
    assert(static_array[4] == 2);
    assert(static_array[7] == 3);
    assert(static_array[9] == 4);

    comptime {
        assert(static_array[0] == 1);
        assert(static_array[4] == 2);
        assert(static_array[7] == 3);
        assert(static_array[9] == 4);
    }
}

const Foo = struct {
    x: i32,
};

fn setFooX(foo: &Foo) {
    foo.x = 2;
}

fn assignUndefinedToStruct() {
    @setFnTest(this);

    comptime {
        var foo: Foo = undefined;
        setFooX(&foo);
        assert(foo.x == 2);
    }
    {
        var foo: Foo = undefined;
        setFooX(&foo);
        assert(foo.x == 2);
    }
}
