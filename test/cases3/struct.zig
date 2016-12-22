const StructWithNoFields = struct {
    fn add(a: i32, b: i32) -> i32 { a + b }
};
const empty_global_instance = StructWithNoFields {};

fn callStructStaticMethod() {
    @setFnTest(this);
    const result = StructWithNoFields.add(3, 4);
    assert(result == 7);
}

fn returnEmptyStructInstance() -> StructWithNoFields {
    @setFnTest(this);
    return empty_global_instance;
}

const should_be_11 = StructWithNoFields.add(5, 6);

fn invokeStaticMethodInGlobalScope() {
    @setFnTest(this);
    assert(should_be_11 == 11);
}

fn voidStructFields() {
    @setFnTest(this);

    const foo = VoidStructFieldsFoo {
        .a = void{},
        .b = 1,
        .c = void{},
    };
    assert(foo.b == 1);
    assert(@sizeOf(VoidStructFieldsFoo) == 4);
}
const VoidStructFieldsFoo = struct {
    a : void,
    b : i32,
    c : void,
};


pub fn structs() {
    @setFnTest(this);

    var foo: StructFoo = undefined;
    @memset((&u8)(&foo), 0, @sizeOf(StructFoo));
    foo.a += 1;
    foo.b = foo.a == 1;
    testFoo(foo);
    testMutation(&foo);
    assert(foo.c == 100);
}
const StructFoo = struct {
    a : i32,
    b : bool,
    c : f32,
};
fn testFoo(foo : StructFoo) {
    assert(foo.b);
}
fn testMutation(foo : &StructFoo) {
    foo.c = 100;
}



// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
