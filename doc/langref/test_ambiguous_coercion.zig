// Compile time coercion of float to int
test "implicit cast to comptime_int" {
    const f: f32 = 54.0 / 5;
    _ = f;
}

// test_error=
