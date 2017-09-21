const assert = @import("std").debug.assert;

test "nullable type" {
    const x : ?bool = true;

    if (x) |y| {
        if (y) {
            // OK
        } else {
            unreachable;
        }
    } else {
        unreachable;
    }

    const next_x : ?i32 = null;

    const z = next_x ?? 1234;

    assert(z == 1234);

    const final_x : ?i32 = 13;

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


test "rhs maybe unwrap return" {
    const x: ?bool = true;
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


test "if var maybe pointer" {
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


test "null literal outside function" {
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


test "test null runtime" {
    testTestNullRuntime(null);
}
fn testTestNullRuntime(x: ?i32) {
    assert(x == null);
    assert(!(x != null));
}

test "nullable void" {
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



const StructWithNullable = struct {
    field: ?i32,
};

var struct_with_nullable: StructWithNullable = undefined;

test "unwrap nullable which is field of global var" {
    struct_with_nullable.field = null;
    if (struct_with_nullable.field) |payload| {
        unreachable;
    }
    struct_with_nullable.field = 1234;
    if (struct_with_nullable.field) |payload| {
        assert(payload == 1234);
    } else {
        unreachable;
    }
}

test "null with default unwrap" {
    const x: i32 = null ?? 1;
    assert(x == 1);
}
