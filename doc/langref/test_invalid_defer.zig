fn deferInvalidExample() !void {
    defer {
        return error.DeferError;
    }

    return error.DeferError;
}

// test_error=cannot return from defer expression
