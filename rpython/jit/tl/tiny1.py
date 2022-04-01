from rpython.rlib.jit import hint


def ll_plus_minus(s, x, y):
    acc = x
    pc = 0
    while pc < len(s):
        op = s[pc]
        hint(op, concrete=True)
        if op == '+':
            acc += y
        elif op == '-':
            acc -= y
        pc += 1
    return acc


def test_simple():
    res = ll_plus_minus("+-++", 100, 10)
    assert res == 120
