const expect = @import("std").testing.expect;

const ptr = &global;
var global: u64 = 123;

test "constant pointer to global variable causes runtime load" {
    global = 1234;
    expect(&global == ptr);
    expect(ptr.* == 1234);
}
