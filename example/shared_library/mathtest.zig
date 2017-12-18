comptime {
    @export("add", add);
}
extern fn add(a: i32, b: i32) -> i32 {
    a + b
}
