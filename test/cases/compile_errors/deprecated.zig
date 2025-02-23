const bad = @deprecated(42);

pub export fn foo() usize {
    return bad;
}

// error
//
// :1:13: error: found deprecated code
