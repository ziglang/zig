# -*- encoding: utf-8 -*-
from __future__ import print_function

import py

from pypy.objspace.std.complexobject import W_ComplexObject, _split_complex

EPS = 1e-9

class TestW_ComplexObject:
    def test_instantiation(self):
        def _t_complex(r=0.0,i=0.0):
            c = W_ComplexObject(r, i)
            assert c.realval == float(r) and c.imagval == float(i)
        pairs = (
            (1, 1),
            (1.0, 2.0),
            (2L, 3L),
        )
        for r,i in pairs:
            _t_complex(r,i)

    def test_parse_complex(self):
        f = _split_complex
        def test_cparse(cnum, realnum, imagnum):
            result = f(cnum)
            assert len(result) == 2
            r, i = result
            assert r == realnum
            assert i == imagnum

        test_cparse('3', '3', '0.0')
        test_cparse('3+3j', '3', '3')
        test_cparse('3.0+3j', '3.0', '3')
        test_cparse('3L+3j', '3L', '3')
        test_cparse('3j', '0.0', '3')
        test_cparse('.e+5', '.e+5', '0.0')
        test_cparse('(1+2j)', '1', '2')
        test_cparse('(1-6j)', '1', '-6')
        test_cparse(' ( +3.14-6J )', '+3.14', '-6')
        test_cparse(' +J', '0.0', '1.0')
        test_cparse(' -J', '0.0', '-1.0')

    def test_unpackcomplex(self):
        space = self.space
        w_z = W_ComplexObject(2.0, 3.5)
        assert space.unpackcomplex(w_z) == (2.0, 3.5)
        space.raises_w(space.w_TypeError, space.unpackcomplex, space.w_None)
        w_f = space.newfloat(42.5)
        assert space.unpackcomplex(w_f) == (42.5, 0.0)
        w_l = space.wrap(-42L)
        assert space.unpackcomplex(w_l) == (-42.0, 0.0)

    def test_pow(self):
        def _pow((r1, i1), (r2, i2)):
            w_res = W_ComplexObject(r1, i1).pow(W_ComplexObject(r2, i2))
            return w_res.realval, w_res.imagval
        assert _pow((0.0,2.0),(0.0,0.0)) == (1.0,0.0)
        assert _pow((0.0,0.0),(2.0,0.0)) == (0.0,0.0)
        rr, ir = _pow((0.0,1.0),(2.0,0.0))
        assert abs(-1.0 - rr) < EPS
        assert abs(0.0 - ir) < EPS

        def _powu((r1, i1), n):
            w_res = W_ComplexObject(r1, i1).pow_positive_int(n)
            return w_res.realval, w_res.imagval
        assert _powu((0.0,2.0),0) == (1.0,0.0)
        assert _powu((0.0,0.0),2) == (0.0,0.0)
        assert _powu((0.0,1.0),2) == (-1.0,0.0)

        def _powi((r1, i1), n):
            w_res = W_ComplexObject(r1, i1).pow_small_int(n)
            return w_res.realval, w_res.imagval
        assert _powi((0.0,2.0),0) == (1.0,0.0)
        assert _powi((0.0,0.0),2) == (0.0,0.0)
        assert _powi((0.0,1.0),2) == (-1.0,0.0)
        c = W_ComplexObject(0.0,1.0)
        p = W_ComplexObject(2.0,0.0)
        r = c.descr_pow(self.space, p, self.space.wrap(None))
        assert r.realval == -1.0
        assert r.imagval == 0.0
