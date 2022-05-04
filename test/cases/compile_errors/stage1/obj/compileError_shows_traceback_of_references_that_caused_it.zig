const foo = @compileError("aoeu",);

const bar = baz + foo;
const baz = 1;

export fn entry() i32 {
    return bar;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:13: error: aoeu
