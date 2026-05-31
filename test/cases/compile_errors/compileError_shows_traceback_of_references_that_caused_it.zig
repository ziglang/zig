const foo = @compileError(
    "aoeu",
);

const bar = baz + foo;
const baz = 1;

export fn entry() i32 {
    return bar;
}

// error
//
// :1:13: error: aoeu
