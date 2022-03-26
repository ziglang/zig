const foo = @compileError("aoeu",);

const bar = baz + foo;
const baz = 1;

export fn entry() i32 {
    return bar;
}

// @compileError shows traceback of references that caused it
//
// tmp.zig:1:13: error: aoeu
