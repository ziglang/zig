fn foo() !void {
    var i: anyerror!usize = 1;
    _ = i catch |i| return i;
}

// error
//
// :3:18: error: redeclaration of local variable 'i'
// :2:9: note: previous declaration here
