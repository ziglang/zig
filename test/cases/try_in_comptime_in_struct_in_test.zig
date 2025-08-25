test "@unionInit on union w/ tag but no fields" {
    const S = struct {
        comptime {
            try expect(false);
        }
    };
    _ = S;
}

// error
// is_test=true
//
// :4:13: error: 'try' outside function scope
