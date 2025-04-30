export fn entry() void {
    const E = error{Foo};
    const e: E = .Foo;
    _ = e;
}

// error
//
// :3:19: error: expected type 'error{Foo}', found '@TypeOf(.enum_literal)'
