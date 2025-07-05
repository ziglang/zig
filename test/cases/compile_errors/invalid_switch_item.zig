const E = enum { a, b, c };
var my_e: E = .a;

export fn f0() void {
    switch (my_e) {
        .a => {},
        .b => {},
        .x => {},
        .c => {},
    }
}

export fn f1() void {
    switch (my_e) {
        else => {},
        .x, .y => {},
    }
}

export fn f2() void {
    switch (my_e) {
        else => {},
        .a => {},
        .x, .y => {},
        .b => {},
    }
}

export fn f3() void {
    switch (my_e) {
        .a, .b => {},
        .x, .y => {},
        else => {},
    }
}

// error
//
// :8:10: error: enum 'tmp.E' has no member named 'x'
// :1:11: note: enum declared here
// :16:10: error: enum 'tmp.E' has no member named 'x'
// :1:11: note: enum declared here
// :24:10: error: enum 'tmp.E' has no member named 'x'
// :1:11: note: enum declared here
// :32:10: error: enum 'tmp.E' has no member named 'x'
// :1:11: note: enum declared here
