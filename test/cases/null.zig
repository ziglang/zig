fn nullableType() {
    @setFnTest(this);

    const x : ?bool = true;

    if (const y ?= x) {
        if (y) {
            // OK
        } else {
            @unreachable();
        }
    } else {
        @unreachable();
    }

    const next_x : ?i32 = null;

    const z = next_x ?? 1234;

    assert(z == 1234);

    const final_x : ?i32 = 13;

    const num = final_x ?? @unreachable();

    assert(num == 13);
}

fn assignToIfVarPtr() {
    @setFnTest(this);

    var maybe_bool: ?bool = true;

    if (const *b ?= maybe_bool) {
        *b = false;
    }

    assert(??maybe_bool == false);
}

fn rhsMaybeUnwrapReturn() {
    @setFnTest(this);

    const x: ?bool = true;
    const y = x ?? return;
}


fn maybeReturn() {
    @setFnTest(this);

    assert(??foo(1235));
    assert(if (const _ ?= foo(null)) false else true);
    assert(!??foo(1234));
}


fn ifVarMaybePointer() {
    @setFnTest(this);

    assert(shouldBeAPlus1(Particle {.a = 14, .b = 1, .c = 1, .d = 1}) == 15);
}
fn shouldBeAPlus1(p: Particle) -> u64 {
    var maybe_particle: ?Particle = p;
    if (const *particle ?= maybe_particle) {
        particle.a += 1;
    }
    if (const particle ?= maybe_particle) {
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


fn nullLiteralOutsideFunction() {
    @setFnTest(this);

    const is_null = if (const _ ?= here_is_a_null_literal.context) false else true;
    assert(is_null);
}
const SillyStruct = struct {
    context: ?i32,
};
const here_is_a_null_literal = SillyStruct {
    .context = null,
};


// TODO test static eval maybe return
fn foo(x: ?i32) -> ?bool {
    const value = ?return x;
    return value > 1234;
}

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}

