export fn entry() void {
    if (2 == undefined) {}
}

// comparing against undefined produces undefined value
//
// tmp.zig:2:11: error: use of undefined value here causes undefined behavior
