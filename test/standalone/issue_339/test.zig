pub fn panic(msg: []const u8) -> noreturn { @breakpoint(); while (true) {} }

fn bar() -> %void {}

export fn foo() {
    %%bar();
}
