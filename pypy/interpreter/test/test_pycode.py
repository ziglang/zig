import sys, StringIO
from pypy.interpreter.pycode import _code_const_eq

def test_dump(space):
    """test that pycode.dump kind of works with py3 opcodes"""
    compiler = space.createcompiler()
    code = compiler.compile('lambda *, y=7: None', 'filename', 'exec', 0)
    output = None
    stdout = sys.stdout
    try:
        sys.stdout = StringIO.StringIO()
        code.dump()
        output = sys.stdout.getvalue()
        sys.stdout.close()
    finally:
        sys.stdout = stdout
    print '>>>\n' + output + '\n<<<'
    assert ' 0 (7)' in output
    assert ' 4 (None)' in output
    assert ' 16 RETURN_VALUE' in output


def test_strong_const_equal(space):
    # test that the stronger equal that code objects are supposed to use for
    # consts works
    s = 'Python'
    values = [
        space.newint(1),
        space.newfloat(0.0),
        space.newfloat(-0.0),
        space.newfloat(1.0),
        space.newfloat(-1.0),
        space.w_True,
        space.w_False,
        space.w_None,
        space.w_Ellipsis,
        space.newcomplex(0.0, 0.0),
        space.newcomplex(0.0, -0.0),
        space.newcomplex(-0.0, 0.0),
        space.newcomplex(-0.0, -0.0),
        space.newcomplex(1.0, 1.0),
        space.newcomplex(1.0, -1.0),
        space.newcomplex(-1.0, 1.0),
        space.newcomplex(-1.0, -1.0),
        space.newfrozenset(),
        space.newtuple([]),
        space.newutf8(s, len(s)),
        space.newbytes(s),
    ]
    for w_a in values:
        assert _code_const_eq(space, w_a, w_a)
        assert _code_const_eq(space, space.newtuple([w_a]),
                              space.newtuple([w_a]))
        assert _code_const_eq(space, space.newfrozenset([w_a]),
                               space.newfrozenset([w_a]))
    for w_a in values:
        for w_b in values:
            if w_a is w_b:
                continue
            assert not _code_const_eq(space, w_a, w_b)
            assert _code_const_eq(space, space.newtuple([w_a, w_b]),
                                  space.newtuple([w_a, w_b]))
            assert not _code_const_eq(space, space.newtuple([w_a]),
                                      space.newtuple([w_b]))
            assert not _code_const_eq(space, space.newtuple([w_a, w_b]),
                                      space.newtuple([w_b, w_a]))
            assert not _code_const_eq(space, space.newfrozenset([w_a]),
                                      space.newfrozenset([w_b]))
        s1 = 'Python' + str(1) + str(1)
        s2 = 'Python' + str(11)
        assert _code_const_eq(space, space.newutf8(s1, len(s1)),
                              space.newutf8(s2, len(s2)))
        assert _code_const_eq(space, space.newbytes(s1),
                              space.newbytes(s2))
