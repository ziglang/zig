fn a() type {
    return struct {
        pub fn b() void {
            const c = 6;
            const c = 69;
        }
    };
}

// error
//
// :5:19: error: redeclaration of local constant 'c'
// :4:19: note: previous declaration here
