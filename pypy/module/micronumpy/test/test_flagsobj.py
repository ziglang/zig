from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest


class AppTestFlagsObj(BaseNumpyAppTest):
    def test_init(self):
        import numpy as np
        a = np.array([1,2,3])
        assert a.flags['C'] is True
        b = type(a.flags)()
        assert b is not a.flags
        assert b['C'] is True
        s = str(b)
        assert s == '%s' %('  C_CONTIGUOUS : True\n  F_CONTIGUOUS : True'
                         '\n  OWNDATA : True\n  WRITEABLE : False'
                         '\n  ALIGNED : True\n  UPDATEIFCOPY : False')
        a = np.array(2)
        assert a.flags.owndata

    def test_repr(self):
        import numpy as np
        a = np.array([1,2,3])
        assert repr(type(a.flags)) == "<type 'numpy.flagsobj'>"

    def test_array_flags(self):
        import numpy as np
        a = np.array([1,2,3])
        assert a.flags.c_contiguous == True
        assert a.flags['W'] == True
        assert a.flags.fnc == False
        assert a.flags.forc == True
        assert a.flags['FNC'] == False
        assert a.flags['FORC'] == True
        assert a.flags.num == 1287
        raises(KeyError, "a.flags['blah']")
        raises(KeyError, "a.flags['C_CONTIGUOUS'] = False")
        raises((TypeError, AttributeError), "a.flags.c_contiguous = False")

    def test_scalar_flags(self):
        import numpy as np
        a = np.int32(2)
        assert a.flags.c_contiguous == True
        assert a.flags.num == 263

    def test_compare(self):
        import numpy as np
        a = np.array([1,2,3])
        b = np.array([4,5,6,7])
        assert a.flags == b.flags
        assert not a.flags != b.flags

    def test_copy_order(self):
        import numpy as np
        tst = np.ones((10, 1), order='C').flags.f_contiguous
        NPY_RELAXED_STRIDES_CHECKING = tst
        a = np.arange(24).reshape(2, 1, 3, 4)
        b = a.copy(order='F')
        c = np.arange(24).reshape(2, 1, 4, 3).swapaxes(2, 3)

        def check_copy_result(x, y, ccontig, fcontig, strides=False):
            assert x is not y
            assert (x == y).all()
            assert res.flags.c_contiguous == ccontig
            assert res.flags.f_contiguous == fcontig
            # This check is impossible only because
            # NPY_RELAXED_STRIDES_CHECKING changes the strides actively
            if not NPY_RELAXED_STRIDES_CHECKING:
                if strides:
                    assert x.strides == y.strides
                else:
                    assert x.strides != y.strides

        # Validate the initial state of a, b, and c
        assert a.flags.c_contiguous
        assert not a.flags.f_contiguous
        assert not b.flags.c_contiguous
        assert b.flags.f_contiguous
        assert not c.flags.c_contiguous
        assert not c.flags.f_contiguous

        # Copy with order='C'
        res = a.copy(order='C')
        check_copy_result(res, a, ccontig=True, fcontig=False, strides=True)
        res = b.copy(order='C')
        check_copy_result(res, b, ccontig=True, fcontig=False, strides=False)
        res = c.copy(order='C')
        check_copy_result(res, c, ccontig=True, fcontig=False, strides=False)

        # Copy with order='F'
        res = a.copy(order='F')
        check_copy_result(res, a, ccontig=False, fcontig=True, strides=False)
        res = b.copy(order='F')
        check_copy_result(res, b, ccontig=False, fcontig=True, strides=True)
        res = c.copy(order='F')
        check_copy_result(res, c, ccontig=False, fcontig=True, strides=False)

        # Copy with order='K'
        res = a.copy(order='K')
        check_copy_result(res, a, ccontig=True, fcontig=False, strides=True)
        res = b.copy(order='K')
        check_copy_result(res, b, ccontig=False, fcontig=True, strides=True)
        res = c.copy(order='K')
        check_copy_result(res, c, ccontig=False, fcontig=False, strides=True)

    def test_contiguous_flags(self):
        import numpy as np
        tst = np.ones((10, 1), order='C').flags.f_contiguous
        NPY_RELAXED_STRIDES_CHECKING = tst
        a = np.ones((4, 4, 1))[::2,:,:]
        if NPY_RELAXED_STRIDES_CHECKING:
            a.strides = a.strides[:2] + (-123,)
        b = np.ones((2, 2, 1, 2, 2)).swapaxes(3, 4)

        def check_contig(a, ccontig, fcontig):
            assert a.flags.c_contiguous == ccontig
            assert a.flags.f_contiguous == fcontig

        # Check if new arrays are correct:
        check_contig(a, False, False)
        check_contig(b, False, False)
        if NPY_RELAXED_STRIDES_CHECKING:
            check_contig(np.empty((2, 2, 0, 2, 2)), True, True)
            check_contig(np.array([[[1], [2]]], order='F'), True, True)
        else:
            check_contig(np.empty((2, 2, 0, 2, 2)), True, False)
            check_contig(np.array([[[1], [2]]], order='F'), False, True)
        check_contig(np.empty((2, 2)), True, False)
        check_contig(np.empty((2, 2), order='F'), False, True)

        # Check that np.array creates correct contiguous flags:
        check_contig(np.array(a, copy=False), False, False)
        check_contig(np.array(a, copy=False, order='C'), True, False)
        check_contig(np.array(a, ndmin=4, copy=False, order='F'), False, True)

        if NPY_RELAXED_STRIDES_CHECKING:
            # Check slicing update of flags and :
            check_contig(a[0], True, True)
            check_contig(a[None, ::4, ..., None], True, True)
            check_contig(b[0, 0, ...], False, True)
            check_contig(b[:,:, 0:0,:,:], True, True)
        else:
            # Check slicing update of flags:
            check_contig(a[0], True, False)
            # Would be nice if this was C-Contiguous:
            check_contig(a[None, 0, ..., None], False, False)
            check_contig(b[0, 0, 0, ...], False, True)

        # Test ravel and squeeze.
        check_contig(a.ravel(), True, True)
        check_contig(np.ones((1, 3, 1)).squeeze(), True, True)
 
