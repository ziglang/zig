const T = struct {
    const T = struct {
        fn f() void {
            _ = T;
        }
    };
};

// error
//
// :4:17: error: ambiguous reference
// :2:5: note: declared here
// :1:1: note: also declared here
