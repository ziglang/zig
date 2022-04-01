from __future__ import with_statement

import rpython.rlib.rcomplex as c
import os, sys, math, struct


def test_add():
    for c1, c2, result in [
        ((0, 0), (0, 0), (0, 0)),
        ((1, 0), (2, 0), (3, 0)),
        ((0, 3), (0, 2), (0, 5)),
        ((10., -3.), (-5, 7), (5, 4)),
    ]:
        assert c.c_add(c1, c2) == result

def test_sub():
    for c1, c2, result in [
            ((0, 0), (0, 0), (0, 0)),
            ((1, 0), (2, 0), (-1, 0)),
            ((0, 3), (0, 2), (0, 1)),
            ((10, -3), (-5, 7), (15, -10)),
            ((42, 0.3), (42, 0.3), (0, 0))
        ]:
            assert c.c_sub(c1, c2) == result

def test_mul():
    for c1, c2, result in [
            ((0, 0), (0, 0), (0, 0)),
            ((1, 0), (2, 0), (2, 0)),
            ((0, 3), (0, 2), (-6, 0)),
            ((0, -3), (-5, 0), (0, 15)),
    ]:
            assert c.c_mul(c1, c2) == result

def test_div():
    c.c_div((2., 3.), (float('nan'), 0.)) == (float('nan'), float('nan'))

def parse_testfile2(fname):
    """Parse a file with test values

    Empty lines or lines starting with -- are ignored
    yields id, fn, arg1_real, arg1_imag, arg2_real, arg2_imag,
    exp_real, exp_imag where numbers in file may be expressed as     floating point or hex
    """
    fname = os.path.join(os.path.dirname(__file__), fname)
    with open(fname) as fp:
        for line in fp:
            # skip comment lines and blank lines
            if line.startswith('--') or not line.strip():
                continue

            lhs, rhs = line.split('->')
            lhs_pieces = lhs.split()
            rhs_pieces = rhs.split()
            for i in range(2, len(lhs_pieces)):
                if lhs_pieces[i].lower().startswith('0x'):
                    lhs_pieces[i] = struct.unpack('d',
                        struct.pack('q',int(lhs_pieces[i])))
                else:
                    lhs_pieces[i] = float(lhs_pieces[i])
            for i in range(2):
                if rhs_pieces[i].lower().startswith('0x'):
                    rhs_pieces[i] = struct.unpack('d',
                        struct.pack('l',int(rhs_pieces[i])))
                else:
                    rhs_pieces[i] = float(rhs_pieces[i])
            #id, fn, arg1_real, arg1_imag arg2_real, arg2_imag =
            #exp_real, exp_imag = rhs_pieces[0], rhs_pieces[1]
            flags = rhs_pieces[2:]
            id_f, fn = lhs_pieces[:2]
            if len(lhs_pieces)>4:
                args = (lhs_pieces[2:4], lhs_pieces[4:])
            else:
                args = lhs_pieces[2:]
            yield id_f, fn, args, rhs_pieces[:2], flags



def parse_testfile(fname):
    """Parse a file with test values

    Empty lines or lines starting with -- are ignored
    yields id, fn, arg_real, arg_imag, exp_real, exp_imag
    """
    fname = os.path.join(os.path.dirname(__file__), fname)
    with open(fname) as fp:
        for line in fp:
            # skip comment lines and blank lines
            if line.startswith('--') or not line.strip():
                continue

            lhs, rhs = line.split('->')
            id, fn, arg_real, arg_imag = lhs.split()
            rhs_pieces = rhs.split()
            exp_real, exp_imag = rhs_pieces[0], rhs_pieces[1]
            flags = rhs_pieces[2:]

            yield (id, fn,
                   float(arg_real), float(arg_imag),
                   float(exp_real), float(exp_imag),
                   flags
                  )

def args_to_str(args):
    if isinstance(args[0],(list, tuple)):
        return '(complex(%r, %r), complex(%r, %r))' % \
             (args[0][0], args[0][1], args[1][0], args[1][1])
    else:
        return '(complex(%r, %r))' % (args[0], args[1])

def rAssertAlmostEqual(a, b, rel_err = 2e-15, abs_err = 5e-323, msg=''):
    """Fail if the two floating-point numbers are not almost equal.

    Determine whether floating-point values a and b are equal to within
    a (small) rounding error.  The default values for rel_err and
    abs_err are chosen to be suitable for platforms where a float is
    represented by an IEEE 754 double.  They allow an error of between
    9 and 19 ulps.
    """

    # special values testing
    if math.isnan(a):
        if math.isnan(b):
            return
        raise AssertionError(msg + '%r should be nan' % (b,))

    if math.isinf(a):
        if a == b:
            return
        raise AssertionError(msg + 'finite result where infinity expected: '
                                   'expected %r, got %r' % (a, b))

    # if both a and b are zero, check whether they have the same sign
    # (in theory there are examples where it would be legitimate for a
    # and b to have opposite signs; in practice these hardly ever
    # occur).
    if not a and not b:
        if math.copysign(1., a) != math.copysign(1., b):
            raise AssertionError(msg + 'zero has wrong sign: expected %r, '
                                       'got %r' % (a, b))

    # if a-b overflows, or b is infinite, return False.  Again, in
    # theory there are examples where a is within a few ulps of the
    # max representable float, and then b could legitimately be
    # infinite.  In practice these examples are rare.
    try:
        absolute_error = abs(b-a)
    except OverflowError:
        pass
    else:
        # test passes if either the absolute error or the relative
        # error is sufficiently small.  The defaults amount to an
        # error of between 9 ulps and 19 ulps on an IEEE-754 compliant
        # machine.
        if absolute_error <= max(abs_err, rel_err * abs(a)):
            return
    raise AssertionError(msg + '%r and %r are not sufficiently close' % (a, b))

def test_specific_values():
    #if not float.__getformat__("double").startswith("IEEE"):
    #    return

    for id, fn, arg, expected, flags in parse_testfile2('rcomplex_testcases.txt'):
        function = getattr(c, 'c_' + fn)
        #
        if 'divide-by-zero' in flags or 'invalid' in flags:
            try:
                actual = function(*arg)
            except ValueError:
                continue
            else:
                raise AssertionError('ValueError not raised in test '
                          '%s: %s%s' % (id, fn, args_to_str(arg)))
        if 'overflow' in flags:
            try:
                actual = function(*arg)
            except OverflowError:
                continue
            else:
                raise AssertionError('OverflowError not raised in test '
                          '%s: %s%s' % (id, fn, args_to_str(arg)))
        actual = function(*arg)

        if 'ignore-real-sign' in flags:
            actual = (abs(actual[0]), actual[1])
            expected = (abs(expected[0]), expected[1])
        if 'ignore-imag-sign' in flags:
            actual = (actual[0], abs(actual[1]))
            expected = (expected[0], abs(expected[1]))

        # for the real part of the log function, we allow an
        # absolute error of up to 2e-15.
        if fn in ('log', 'log10'):
            real_abs_err = 2e-15
        else:
            real_abs_err = 5e-323

        error_message = (
            '%s: %s%s\n'
            'Expected: complex(%r, %r)\n'
            'Received: complex(%r, %r)\n'
            ) % (id, fn, args_to_str(arg),
                 expected[0], expected[1],
                 actual[0], actual[1])

        rAssertAlmostEqual(expected[0], actual[0],
                           abs_err=real_abs_err,
                           msg=error_message)
        rAssertAlmostEqual(expected[1], actual[1],
                           abs_err=real_abs_err,
                           msg=error_message)

    for id, fn, a, expected, flags in parse_testfile2('rcomplex_testcases2.txt'):
        function = getattr(c, 'c_' + fn)
        #
        if 'divide-by-zero' in flags or 'invalid' in flags:
            try:
                actual = function(*a)
            except ValueError:
                continue
            else:
                raise AssertionError('ValueError not raised in test '
                            '%s: %s%s' % (id, fn, args_to_str(a)))
        if 'overflow' in flags:
            try:
                actual = function(*a)
            except OverflowError:
                continue
            else:
                raise AssertionError('OverflowError not raised in test '
                            '%s: %s%s' % (id, fn, args_to_str(a)))
        actual = function(*a)

        if 'ignore-real-sign' in flags:
            actual = (abs(actual[0]), actual[1])
            expected = (abs(expected[0]), expected[1])
        if 'ignore-imag-sign' in flags:
            actual = (actual[0], abs(actual[1]))
            expected = (expected[0], abs(expected[1]))

        # for the real part of the log function, we allow an
        # absolute error of up to 2e-15.
        if fn in ('log', 'log10'):
            real_abs_err = 2e-15
        else:
            real_abs_err = 5e-323
        error_message = (
            '%s: %s%s\n'
            'Expected: complex(%r, %r)\n'
            'Received: complex(%r, %r)\n'
            ) % (id, fn, args_to_str(a),
                 expected[0], expected[1],
                 actual[0], actual[1])

        rAssertAlmostEqual(expected[0], actual[0],
                           abs_err=real_abs_err,
                           msg=error_message)
        rAssertAlmostEqual(expected[1], actual[1],
                           abs_err=real_abs_err,
                           msg=error_message)

def test_isnan():
    assert not c.c_isnan(0, 0)
    assert c.c_isnan(float('nan'), 0)
    assert c.c_isnan(1, float('nan'))
    assert not c.c_isnan(float('inf'), 0)

def test_isinf():
    assert not c.c_isinf(0, 0)
    assert c.c_isinf(float('inf'), 0)
    assert c.c_isinf(float('-inf'), 0)
    assert c.c_isinf(1, float('inf'))
    assert not c.c_isinf(float('nan'), 0)

def test_isfinite():
    assert c.c_isfinite(0, 0)
    assert not c.c_isfinite(float('nan'), 0)
    assert not c.c_isfinite(float('-inf'), 0)
    assert not c.c_isfinite(0, float('nan'))
    assert not c.c_isfinite(0, float('-inf'))

