fn foo() [:0xff]const u8 {
    return "bark";
}
fn bar() [:0]const u16 {
    return "bark";
}
pub export fn entry() void {
    _ = foo();
}
pub export fn entry1() void {
    _ = bar();
}

// error
// backend=stage2
// target=native
//
// :2:12: error: expected type '[:255]const u8', found '*const [4:0]u8'
// :2:12: note: pointer sentinel '0' cannot cast into pointer sentinel '255'
// :1:10: note: function return type declared here
// :5:12: error: expected type '[:0]const u16', found '*const [4:0]u8'
// :5:12: note: pointer type child 'u8' cannot cast into pointer type child 'u16'
// :4:10: note: function return type declared here
