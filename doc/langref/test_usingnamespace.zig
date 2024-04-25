test "using std namespace" {
    const S = struct {
        usingnamespace @import("std");
    };
    try S.testing.expect(true);
}

// test
