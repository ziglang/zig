export fn a() void {
    x += 1;
}
export fn b() void {
    x += 1;
}

// deduplicate undeclared identifier
//
// tmp.zig:2:5: error: use of undeclared identifier 'x'
