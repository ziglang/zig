const assert = @import("std").debug.assert;

test "nullableType" {
    const x : ?bool = @generatedCode(true);

    if (x) |y| {
        if (y) {
            // OK
        } else {
            unreachable;
        }
    } else {
        unreachable;
    }

    const next_x : ?i32 = @generatedCode(null);

    const z = next_x ?? 1234;

    assert(z == 1234);

    const final_x : ?i32 = @generatedCode(13);

    const num = final_x ?? unreachable;

    assert(num == 13);
}

test "test maybe object and get a pointer to the inner value" {
    var maybe_bool: ?bool = true;

    if (maybe_bool) |*b| {
        *b = false;
    }

    assert(??maybe_bool == false);
}


test "rhsMaybeUnwrapReturn" {
    const x: ?bool = @generatedCode(true);
    const y = x ?? return;
}


test "maybe return" {
    maybeReturnImpl();
    comptime maybeReturnImpl();
}

fn maybeReturnImpl() {
    assert(??foo(1235));
    if (foo(null) != null)
        unreachable;
    assert(!??foo(1234));
}

fn foo(x: ?i32) -> ?bool {
    const value = x ?? return null;
    return value > 1234;
}


test "ifVarMaybePointer" {
    assert(shouldBeAPlus1(Particle {.a = 14, .b = 1, .c = 1, .d = 1}) == 15);
}
fn shouldBeAPlus1(p: &const Particle) -> u64 {
    var maybe_particle: ?Particle = *p;
    if (maybe_particle) |*particle| {
        particle.a += 1;
    }
    if (maybe_particle) |particle| {
        return particle.a;
    }
    return 0;
}
const Particle = struct {
    a: u64,
    b: u64,
    c: u64,
    d: u64,
};


test "nullLiteralOutsideFunction" {
    const is_null = here_is_a_null_literal.context == null;
    assert(is_null);

    const is_non_null = here_is_a_null_literal.context != null;
    assert(!is_non_null);
}
const SillyStruct = struct {
    context: ?i32,
};
const here_is_a_null_literal = SillyStruct {
    .context = null,
};


test "testNullRuntime" {
    testTestNullRuntime(null);
}
fn testTestNullRuntime(x: ?i32) {
    assert(x == null);
    assert(!(x != null));
}

test "nullableVoid" {
    nullableVoidImpl();
    comptime nullableVoidImpl();
}

fn nullableVoidImpl() {
    assert(bar(null) == null);
    assert(bar({}) != null);
}

fn bar(x: ?void) -> ?void {
    if (x) |_| {
        return {};
    } else {
        return null;
    }
}
