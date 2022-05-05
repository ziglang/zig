pub fn main() u8 {
    var x: u8 = 0;

    foo(&x);
    bar(&x);
    return x - 4;
}

fn foo(x: *u8) void {
    x.* = 2;
}

fn bar(x: *u8) void {
    x.* += 2;
}

// run
//
