const Error = error{M};

export fn entry() void {
    const f: Error!void = void{};
    if (f) {} else |e| switch (e) {}
}

export fn entry2() void {
    const f: Error!void = void{};
    f catch |e| switch (e) {};
}

// error
// backend=stage2
// target=native
//
// :5:24: error: switch must handle all possibilities
// :5:24: note: unhandled error value: 'error.M'
// :10:17: error: switch must handle all possibilities
// :10:17: note: unhandled error value: 'error.M'
