pub fn panic(msg: []const u8) -> noreturn { @breakpoint(); while (true) {} }

fn bar() -> %void {}

comptime {
    @export("foo", foo);
}
extern fn foo() {
    %%bar();
}
