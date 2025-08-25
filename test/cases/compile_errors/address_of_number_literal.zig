const x = 3;
const y = &x;
fn foo() *const i32 {
    return y;
}
export fn entry() usize {
    return @sizeOf(@TypeOf(&foo));
}

// error
// backend=stage2
// target=native
//
// :4:12: error: expected type '*const i32', found '*const comptime_int'
// :4:12: note: pointer type child 'comptime_int' cannot cast into pointer type child 'i32'
// :3:10: note: function return type declared here
