fn bug() void {
    comptime var foo = 0;

    comptime var counter = 0;

    while (counter != 1) : (counter += 1) {
        foo = 1;
        if (false) {}
    }

    return;
}

test {
    comptime bug();
}

// error
// is_test=1
// backend=stage2
//
// :7:15: error: cannot store to comptime variable in non-inline loop
// :6:5: note: non-inline loop here
