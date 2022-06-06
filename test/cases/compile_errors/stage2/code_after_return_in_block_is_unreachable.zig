export fn entry() void {
    {
        return;
    }

    return;
}

// error
// target=native
//
// :6:5: error: unreachable code
// :2:5: note: control flow is diverted here

