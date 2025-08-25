export fn entry() i32 {
    var foo: i32 addrspace(".general") = 1234;
    return foo;
}

// error
//
// :2:28: error: cannot set address space of local variable 'foo'
