const bad = @deprecated(42);

pub export fn foo() usize {
    return bad;
}

// error
//
// :1:13: error: reached deprecated code
