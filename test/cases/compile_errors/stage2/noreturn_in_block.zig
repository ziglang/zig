export fn entry1() void {
    {
        return;
    }
    return;
}

export fn entry2() void {
    outer: {
        {
            break :outer;
        }
        return;
    }
}

export fn entry3() void {
    while (true) {
        {
            break;
        }
        return;
    }
}

// error
// target=native
//
// :5:5: error: unreachable code
// :2:5: note: control flow is diverted here
// :13:9: error: unreachable code
// :10:9: note: control flow is diverted here
// :22:9: error: unreachable code
// :19:9: note: control flow is diverted here
