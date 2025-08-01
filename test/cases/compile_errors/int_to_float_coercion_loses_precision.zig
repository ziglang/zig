export fn foo() void {
    const int: u16 = 65535;
    const float: f16 = int;
    _ = float;
}

// error
//
// :3:24: error: type 'f16' cannot represent integer value '65535'
