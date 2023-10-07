const TestEnum = enum { T1, T2 };

fn err(x: u8) TestEnum {
    switch (x) {
        0 => return TestEnum.T1,
        else => return TestEnum.T2,
    }
}

fn foo(x: u8) void {
    switch (err(x)) {
        TestEnum.T1 => {},
        TestEnum.T2 => {},
        else => {},
    }
}

export fn entry() usize {
    return @sizeOf(@TypeOf(&foo));
}

// error
// backend=llvm
// target=native
//
// :14:14: error: unreachable else prong; all cases already handled
