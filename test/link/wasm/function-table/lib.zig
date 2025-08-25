var func: *const fn () void = &bar;

export fn foo() void {
    func();
}

fn bar() void {}
