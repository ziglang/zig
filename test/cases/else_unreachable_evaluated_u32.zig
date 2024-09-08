// from #7370 - this used to not compile on stage1

export fn foo() void {
    var x: bool = false;
    _ = &x;
    const v = // : usize here fixes the problem
        while (x) : ({})
    { // for loop has the same problem
        if (x) continue;
        break @as(usize, 0);
    } else unreachable;
    _ = &v;
}

// compile
//
