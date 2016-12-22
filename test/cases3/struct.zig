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



// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
