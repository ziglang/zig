from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest


class AppTestSupport(BaseNumpyAppTest):
    spaceconfig = dict(usemodules=["micronumpy", "struct", "binascii", "mmap"])

    def setup_class(cls):
        BaseNumpyAppTest.setup_class.im_func(cls)
        cls.w_NoNew = cls.space.appexec([], '''():
            from numpy import ndarray
            class NoNew(ndarray):
                def __new__(cls, subtype):
                    raise ValueError('should not call __new__')
                def __array_finalize__(self, obj):

                    self.called_finalize = True
            return NoNew ''')
        cls.w_SubType = cls.space.appexec([], '''():
            from numpy import ndarray, array
            class SubType(ndarray):
                def __new__(obj, input_array):
                    obj = array(input_array, copy=False).view(obj)
                    obj.called_new = True
                    return obj
                def __array_finalize__(self, obj):
                    self.called_finalize = True
            return SubType ''')

    def test_subtype_ndarray(self):
        from numpy import arange, array
        a = arange(24, dtype='int32').reshape((6,4))
        b = array(a, dtype='float64', subok=True)
        assert (a == b).all()

    def test_subtype_base(self):
        from numpy import ndarray, dtype
        class C(ndarray):
            def __new__(subtype, shape, dtype):
                self = ndarray.__new__(subtype, shape, dtype)
                self.id = 'subtype'
                return self
        a = C((), int)
        assert type(a) is C
        assert a.shape == ()
        assert a.dtype is dtype(int)
        assert a.id == 'subtype'
        a = C([2, 2], int)
        assert isinstance(a, C)
        assert isinstance(a, ndarray)
        assert a.shape == (2, 2)
        assert a.dtype is dtype(int)
        assert a.id == 'subtype'
        a = a.reshape(1, 4)
        b = a.reshape(4, 1)
        assert isinstance(b, C)
        #make sure __new__ was not called
        assert not getattr(b, 'id', None)
        a.fill(3)
        b = a[0]
        assert isinstance(b, C)
        assert (b == 3).all()
        b[0]=100
        assert a[0,0] == 100

        assert type(a) is not ndarray
        assert a[0,0] == 100
        assert a.base is not None
        b = a.__array__()
        assert type(b) is ndarray
        assert b[0,0] == 100
        assert b.base is a

    def test_subtype_view(self):
        from numpy import ndarray, array
        class matrix(ndarray):
            def __new__(subtype, data, dtype=None, copy=True):
                if isinstance(data, matrix):
                    return data
                return data.view(subtype)
        a = array(range(5))
        b = matrix(a)
        assert isinstance(b, matrix)
        assert b.__array_priority__ == 0.0
        assert (b == a).all()
        assert isinstance(b.view(), matrix) 
        a = array(5)[()]
        for s in [matrix, ndarray]:
            b = a.view(s)
            assert b == a
            assert type(b) is type(a)
        a = matrix(array(range(5)))
        for s in [matrix, ndarray]:
            b = ndarray.view(a, s)
            assert (b == a).all()
            assert type(b) is s

    def test_subtype_like_matrix(self):
        import numpy as np
        arr = np.array([1,2,3])
        ret = np.ndarray.__new__(np.ndarray, arr.shape, arr.dtype, buffer=arr)
        assert ret.__array_priority__ == 0.0
        assert (arr == ret).all()
    
    def test_priority(self):
        from numpy import ndarray, arange, add
        class DoReflected(object):
            __array_priority__ = 10
            def __radd__(self, other):
                return 42

        class A(object):
            def __add__(self, other):
                return NotImplemented


        a = arange(10)
        b = DoReflected()
        c = A()
        assert c + b == 42
        assert a.__add__(b) is NotImplemented # not an exception
        assert b.__radd__(a) == 42
        assert a + b == 42
        
    def test_finalize(self):
        #taken from http://docs.scipy.org/doc/numpy/user/basics.subclassing.html#simple-example-adding-an-extra-attribute-to-ndarray
        import numpy as np
        class InfoArray(np.ndarray):
            def __new__(subtype, shape, dtype=float, buffer=None, offset=0,
                          strides=None, order='C', info=1):
                obj = np.ndarray.__new__(subtype, shape, dtype, buffer,
                         offset, strides, order)
                obj.info = info
                return obj

            def __array_finalize__(self, obj):
                if obj is None:
                    return
                # printing the object itself will crash the test
                self.info = 1 + getattr(obj, 'info', 0)
                if hasattr(obj, 'info'):
                    obj.info += 100

        obj = InfoArray(shape=(3,))
        assert isinstance(obj, InfoArray)
        assert obj.info == 1
        obj = InfoArray(shape=(3,), info=10)
        assert obj.info == 10
        v = obj[1:]
        assert isinstance(v, InfoArray)
        assert v.base is obj
        assert v.info == 11
        arr = np.arange(10)
        cast_arr = arr.view(InfoArray)
        assert isinstance(cast_arr, InfoArray)
        assert cast_arr.base is arr
        assert cast_arr.info == 1
        # Test that setshape calls __array_finalize__
        cast_arr.shape = (5,2)
        z = cast_arr.info
        assert z == 101


    def test_sub_where(self):
        from numpy import where, ones, zeros, array
        a = array([1, 2, 3, 0, -3])
        v = a.view(self.NoNew)
        b = where(array(v) > 0, ones(5), zeros(5))
        assert (b == [1, 1, 1, 0, 0]).all()
        # where returns an ndarray irregardless of the subtype of v
        assert not isinstance(b, self.NoNew)

    def test_sub_repeat(self):
        from numpy import array
        a = self.SubType(array([[1, 2], [3, 4]]))
        b = a.repeat(3)
        assert (b == [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4]).all()
        assert isinstance(b, self.SubType)

    def test_sub_flatiter(self):
        from numpy import array
        a = array(range(9)).reshape(3, 3).view(self.NoNew)
        c = array(range(9)).reshape(3, 3)
        assert isinstance(a.flat[:] + a.flat[:], self.NoNew)
        assert isinstance(a.flat[:] + c.flat[:], self.NoNew)
        assert isinstance(c.flat[:] + a.flat[:], self.NoNew)
        assert not isinstance(c.flat[:] + c.flat[:], self.NoNew)

    def test_sub_getitem_filter(self):
        from numpy import array
        a = array(range(5))
        b = self.SubType(a)
        c = b[array([False, True, False, True, False])]
        assert c.shape == (2,)
        assert (c == [1, 3]).all()
        assert isinstance(c, self.SubType)
        assert b.called_new
        assert not getattr(c, 'called_new', False)
        assert c.called_finalize

    def test_sub_getitem_array_int(self):
        from numpy import array
        a = array(range(5))
        b = self.SubType(a)
        assert b.called_new
        c = b[array([3, 2, 1, 4])]
        assert (c == [3, 2, 1, 4]).all()
        assert isinstance(c, self.SubType)
        assert not getattr(c, 'called_new', False)
        assert c.called_finalize

    def test_sub_round(self):
        from numpy import array
        a = array(range(10), dtype=float).view(self.NoNew)
        # numpy compatibility
        b = a.round(decimals=0)
        assert isinstance(b, self.NoNew)
        b = a.round(decimals=1)
        assert not isinstance(b, self.NoNew)
        b = a.round(decimals=-1)
        assert not isinstance(b, self.NoNew)

    def test_sub_dot(self):
        # the returned type is that of the first argument
        from numpy import array
        a = array(range(12)).reshape(3,4)
        b = self.SubType(a)
        c = array(range(12)).reshape(4,3).view(self.SubType)
        d = c.dot(a)
        assert isinstance(d, self.SubType)
        assert not getattr(d, 'called_new', False)
        assert d.called_finalize
        d = a.dot(c)
        assert not isinstance(d, self.SubType)
        assert not getattr(d, 'called_new', False)
        assert not getattr(d, 'called_finalize', False)

    def test_sub_reduce(self):
        # i.e. sum, max
        # test for out as well
        from numpy import array
        a = array(range(12)).reshape(3,4)
        b = self.SubType(a)
        c = b.sum(axis=0)
        assert (c == [12, 15, 18, 21]).all()
        assert isinstance(c, self.SubType)
        assert not getattr(c, 'called_new', False)
        assert c.called_finalize
        d = array(range(4))
        c = b.sum(axis=0, out=d)
        assert c is d
        assert not isinstance(c, self.SubType)
        d = array(range(4)).view(self.NoNew)
        c = b.sum(axis=0, out=d)
        assert c is d
        assert isinstance(c, self.NoNew)

    def test_sub_call2(self):
        # c + a vs. a + c, what about array priority?
        from numpy import array
        a = array(range(12)).view(self.NoNew)
        b = self.SubType(range(12))
        c = b + a
        assert isinstance(c, self.SubType)
        c = a + b
        assert isinstance(c, self.NoNew)
        d = range(12)
        e = a - d
        assert isinstance(e, self.NoNew)

    def test_sub_call1(self):
        from numpy import array, sqrt
        a = array(range(12)).view(self.NoNew)
        b = sqrt(a)
        assert b.called_finalize == True

    def test_sub_astype(self):
        from numpy import array
        a = array(range(12)).view(self.NoNew)
        b = a.astype(float)
        assert b.called_finalize == True

    def test_sub_reshape(self):
        from numpy import array
        a = array(range(12)).view(self.NoNew)
        b = a.reshape(3, 4)
        assert b.called_finalize == True

    def test___array__(self):
        import sys
        from numpy import ndarray, array, dtype
        class D(ndarray):
            def __new__(subtype, shape, dtype):
                self = ndarray.__new__(subtype, shape, dtype)
                self.id = 'subtype'
                return self
        class C(object):
            def __init__(self, val, dtype):
                self.val = val
                self.dtype = dtype
            def __array__(self, dtype=None):
                retVal = D(self.val, dtype)
                return retVal

        a = C([2, 2], int)
        b = array(a, subok=True)
        assert b.shape == (2, 2)
        assert isinstance(b, D)
        c = array(a, float)
        assert c.dtype is dtype(float)

    def test_array_of_subtype(self):
        import numpy as np
        # this part of numpy's matrix class causes an infinite loop
        # on cpython
        import sys
        if '__pypy__' not in sys.builtin_module_names:
            skip('does not pass on cpython')
        class matrix(np.ndarray):
            def __new__(subtype, data, dtype=None, copy=True):
                print('matrix __new__')
                if isinstance(data, matrix):
                    dtype2 = data.dtype
                    if (dtype is None):
                        dtype = dtype2
                    if (dtype2 == dtype) and (not copy):
                        return data
                    return data.astype(dtype)

                if isinstance(data, np.ndarray):
                    if dtype is None:
                        intype = data.dtype
                    else:
                        intype = np.dtype(dtype)
                    new = data.view(subtype)
                    if intype != data.dtype:
                        return new.astype(intype)
                    if copy: return new.copy()
                    else: return new

                if isinstance(data, str):
                    data = _convert_from_string(data)

                # now convert data to an array
                arr = np.array(data, dtype=dtype, copy=copy)
                ndim = arr.ndim
                shape = arr.shape
                if (ndim > 2):
                    raise ValueError("matrix must be 2-dimensional")
                elif ndim == 0:
                    shape = (1, 1)
                elif ndim == 1:
                    shape = (1, shape[0])

                order = False
                if (ndim == 2) and arr.flags.fortran:
                    order = True

                if not (order or arr.flags.contiguous):
                    arr = arr.copy()

                ret = np.ndarray.__new__(subtype, shape, arr.dtype,
                                        buffer=arr,
                                        order=order)
                return ret

            def __array_finalize__(self, obj):
                print('matrix __array_finalize__',obj)
                self._getitem = False
                if (isinstance(obj, matrix) and obj._getitem): return
                ndim = self.ndim
                if (ndim == 2):
                    return
                if (ndim > 2):
                    newshape = tuple([x for x in self.shape if x > 1])
                    ndim = len(newshape)
                    if ndim == 2:
                        self.shape = newshape
                        return
                    elif (ndim > 2):
                        raise ValueError("shape too large to be a matrix.")
                else:
                    newshape = self.shape
                if ndim == 0:
                    self.shape = (1, 1)
                elif ndim == 1:
                    self.shape = (1, newshape[0])
                return

            def __getitem__(self, index):
                print('matrix __getitem__',index)
                self._getitem = True

                try:
                    out = np.ndarray.__getitem__(self, index)
                finally:
                    self._getitem = False

                if not isinstance(out, np.ndarray):
                    return out

                if out.ndim == 0:
                    return out[()]
                if out.ndim == 1:
                    sh = out.shape[0]
                    # Determine when we should have a column array
                    try:
                        n = len(index)
                    except:
                        n = 0
                    if n > 1 and isscalar(index[1]):
                        out.shape = (sh, 1)
                    else:
                        out.shape = (1, sh)
                return out

        a = matrix([[1., 2.], [3., 4.]])
        b = np.array([a])
        assert (b == a).all()

        b = np.array(a)
        assert len(b.shape) == 2
        assert (b == a).all()

        b = np.array(a, copy=False)
        assert len(b.shape) == 2
        assert (b == a).all()

        b = np.array(a, copy=True, dtype=int)
        assert len(b.shape) == 2
        assert (b == a).all()

        c = matrix(a, copy=False)
        assert c.base is not None
        c[0, 0] = 100
        assert a[0, 0] == 100
        b = np.array(c, copy=True)
        assert (b == a).all()

        d = np.empty([6,2], dtype=float)
        d.view('int64').fill(0xdeadbeef)
        e = d[0::3,:]
        e[...] = [[1, 2], [3, 4]]
        assert e.strides == (48, 8)
        f = e.view(matrix)
        assert f.strides == (48, 8)
        g = np.array(f, copy=False)
        assert (g == [[1, 2], [3, 4]]).all()

        k = np.empty([2, 8], dtype=float)
        k.view('int64').fill(0xdeadbeef)
        m = k[:, ::-4]
        m[...] = [[1, 2], [3, 4]]
        assert m.strides == (64, -32)
        n = m.view(matrix)
        assert n.strides == (64, -32)
        p = np.array(n, copy=False)
        assert (p == [[1, 2], [3, 4]]).all()


    def test_setstate_no_version(self):
        # Some subclasses of ndarray, like MaskedArray, do not use
        # version in __setstate__
        from numpy import ndarray, array
        from pickle import loads, dumps
        import sys, new
        class D(ndarray):
            ''' A subtype with a constructor that accepts a list of
                data values, where ndarray accepts a shape
            '''
            def __new__(subtype, data, dtype=None, copy=True):
                arr = array(data, dtype=dtype, copy=copy)
                shape = arr.shape
                ret = ndarray.__new__(subtype, shape, arr.dtype,
                                        buffer=arr,
                                        order=True)
                return ret
            def __setstate__(self, state):
                (version, shp, typ, isf, raw) = state
                ndarray.__setstate__(self, (shp, typ, isf, raw))

        E = '<' if sys.byteorder == 'little' else '>'
        D.__module__ = 'mod'
        mod = new.module('mod')
        mod.D = D
        sys.modules['mod'] = mod
        a = D([1., 2.])
        s = dumps(a)
        #Taken from numpy version 1.8
        s_from_numpy = '''ignore this line
            _reconstruct
            p0
            (cmod
            D
            p1
            (I0
            tp2
            S'b'
            p3
            tp4
            Rp5
            (I1
            (I2
            tp6
            cnumpy
            dtype
            p7
            (S'f8'
            p8
            I0
            I1
            tp9
            Rp10
            (I3
            S'{E}'
            p11
            NNNI-1
            I-1
            I0
            tp12
            bI00
            S'\x00\x00\x00\x00\x00\x00\xf0?\x00\x00\x00\x00\x00\x00\x00@'
            p13
            tp14
            b.'''.replace('            ','').format(E=E)
        for ss,sn in zip(s.split('\n')[1:],s_from_numpy.split('\n')[1:]):
            if len(ss)>10:
                # ignore binary data, it will be checked later
                continue
            assert ss == sn
        b = loads(s)
        assert (a == b).all()
        assert isinstance(b, D)

    def test_subok(self):
        from numpy import array, ndarray
        a = self.SubType(array([[1, 2], [3, 4]]))
        b = array(a, subok=False)
        assert type(b) is ndarray
    
    def test_numpypy_mmap(self):
        # issue #21 on pypy/numpy 
        from numpy import array, ndarray, arange, dtype as dtypedescr
        import mmap
        import os.path
        from tempfile import mkdtemp
        import os.path as path
        valid_filemodes = ["r", "c", "r+", "w+"]
        writeable_filemodes = ["r+", "w+"]
        mode_equivalents = {
            "readonly":"r",
            "copyonwrite":"c",
            "readwrite":"r+",
            "write":"w+"
            }

        class memmap(ndarray):
            def __new__(subtype, filename, dtype='uint8', mode='r+', offset=0, shape=None, order='C'):
                # Import here to minimize 'import numpy' overhead
                try:
                    mode = mode_equivalents[mode]
                except KeyError:
                    if mode not in valid_filemodes:
                        raise ValueError("mode must be one of %s" %
                                         (valid_filemodes + list(mode_equivalents.keys())))

                if hasattr(filename, 'read'):
                    fid = filename
                    own_file = False
                else:
                    fid = open(filename, (mode == 'c' and 'r' or mode)+'b')
                    own_file = True

                if (mode == 'w+') and shape is None:
                    raise ValueError("shape must be given")

                fid.seek(0, 2)
                flen = fid.tell()
                descr = dtypedescr(dtype)
                _dbytes = descr.itemsize

                if shape is None:
                    bytes = flen - offset
                    if (bytes % _dbytes):
                        fid.close()
                        raise ValueError("Size of available data is not a "
                                "multiple of the data-type size.")
                    size = bytes // _dbytes
                    shape = (size,)
                else:
                    if not isinstance(shape, tuple):
                        shape = (shape,)
                    size = 1
                    for k in shape:
                        size *= k

                bytes = long(offset + size*_dbytes)

                if mode == 'w+' or (mode == 'r+' and flen < bytes):
                    fid.seek(bytes - 1, 0)
                    fid.write('\0')
                    fid.flush()

                if mode == 'c':
                    acc = mmap.ACCESS_COPY
                elif mode == 'r':
                    acc = mmap.ACCESS_READ
                else:
                    acc = mmap.ACCESS_WRITE

                start = offset - offset % mmap.ALLOCATIONGRANULARITY
                bytes -= start
                offset -= start
                mm = mmap.mmap(fid.fileno(), bytes, access=acc, offset=start)

                self = ndarray.__new__(subtype, shape, dtype=descr, buffer=mm,
                    offset=offset, order=order)
                self._mmap = mm
                self.offset = offset
                self.mode = mode

                if isinstance(filename, basestring):
                    self.filename = os.path.abspath(filename)
                # py3 returns int for TemporaryFile().name
                elif (hasattr(filename, "name") and
                      isinstance(filename.name, basestring)):
                    self.filename = os.path.abspath(filename.name)
                # same as memmap copies (e.g. memmap + 1)
                else:
                    self.filename = None

                if own_file:
                    fid.close()

                return self

            def flush(self):
                if self.base is not None and hasattr(self.base, 'flush'):
                    self.base.flush() 

        def asarray(obj, itemsize=None, order=None):
            return array(obj, itemsize, copy=False, order=order)

        filename = path.join(mkdtemp(), 'newfile.dat')
        data = arange(10*10*36).reshape(10, 10, 36)
        fp = memmap(filename, dtype='float32', mode='w+', shape=data.shape)
        vals = [   242,    507,    255,    505,    315,    316,    308,    506,
          309,    255,    211,    505,    315,    316,    308,    506,
          309,    255,    255,    711,    194,    232,    711,    711,
          709,    710,    709,    710,    882,    897,    711,    245,
          711,    711,    168,    245]
        fp[:] = data
        fp[5:6][:,4] = vals
        a = asarray(fp[5:6][:,4])
        assert (a == vals).all()

    def test__array_wrap__(self):
        ''' Straight from the documentation of __array_wrap__
        '''
        import numpy as np

        class MySubClass(np.ndarray):
            output = ''

            def __new__(cls, input_array, info=None):
                obj = np.array(input_array).view(cls)
                obj.info = info
                return obj

            def __array_finalize__(self, obj):
                self.output += 'In __array_finalize__:'
                self.output += '   self is %s' % repr(self)
                self.output += '   obj is %s\n' % repr(obj)
                print self.output
                if obj is None: return
                self.info = getattr(obj, 'info', None)

            def __array_wrap__(self, out_arr, context=None):
                self.output += 'In __array_wrap__:'
                self.output += '   self is %s' % repr(self)
                self.output += '   arr is %r\n' % (out_arr,)
                self.output += '   context is %r\n' % (context,)
                # then just call the parent
                ret = np.ndarray.__array_wrap__(self, out_arr, context)
                print 'wrap',self.output
                return ret 

        obj = MySubClass(np.arange(5), info='spam')
        assert obj.output.startswith('In __array_finalize')
        obj.output = ''
        print 'np.arange(5) + 1'
        arr2 = np.arange(5) + 1
        assert len(obj.output) < 1
        print 'np.add(arr2, obj)'
        ret = np.add(arr2, obj)
        assert obj.output.startswith('In __array_wrap')
        assert 'finalize' not in obj.output
        assert ret.info == 'spam'
        print 'np.negative(obj)'
        ret = np.negative(obj)
        assert ret.info == 'spam'
        print 'obj.sum()'
        ret = obj.sum()
        print type(ret)
        assert ret.info == 'spam'

    def test_ndarray_subclass_assigns_base(self):
        import numpy as np
        init_called = []
        class _DummyArray(object):
            """ Dummy object that just exists to hang __array_interface__ dictionaries
            and possibly keep alive a reference to a base array.
            """
            def __init__(self, interface, base=None):
                self.__array_interface__ = interface
                init_called.append(1)
                self.base = base

        x = np.zeros(10)
        d = _DummyArray(x.__array_interface__, base=x)
        y = np.array(d, copy=False)
        assert sum(init_called) == 1
        assert y.base is d

        x = np.zeros((0,), dtype='float32')
        intf = x.__array_interface__.copy()
        intf["strides"] = x.strides
        x.__array_interface__["strides"] = x.strides
        d = _DummyArray(x.__array_interface__, base=x)
        y = np.array(d, copy=False)
        assert sum(init_called) == 2
        assert y.base is d


