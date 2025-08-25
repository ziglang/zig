const U = union {
    next: ?*align(1) U align(128),
};

export fn entry() usize {
    return @alignOf(U);
}

// error
//
// :1:11: error: union layout depends on being pointer aligned
