export fn foo() void {
    @compileError("this is an error");
}

// error
//
// :2:5: error: this is an error
