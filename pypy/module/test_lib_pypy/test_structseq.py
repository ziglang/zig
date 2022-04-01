from pypy.module.test_lib_pypy.support import import_lib_pypy


class AppTestStructseq:

    spaceconfig = dict(usemodules=('binascii', 'struct',))

    def setup_class(cls):
        cls.w__structseq = cls.space.appexec(
                [], "(): import _structseq; return _structseq")

    def w_get_mydata(self):
        _structseq = self._structseq
        ns = dict(_structseq=_structseq,
                  ssfield=_structseq.structseqfield)
        # need to exec since it uses the py3k-only metaclass syntax
        exec("""class mydata(metaclass=_structseq.structseqtype):
    st_mode  = ssfield(0, "protection bits")
    st_ino   = ssfield(1)
    st_dev   = ssfield(2)
    st_nlink = ssfield(3)
    st_uid   = ssfield(4)
    st_gid   = ssfield(5)
    st_size  = ssfield(6)
    _st_atime_as_int = ssfield(7)
    _st_mtime_as_int = ssfield(8)
    _st_ctime_as_int = ssfield(9)
    # skip to higher numbers for fields not part of the sequence.
    # the numbers are only used to ordering
    st_rdev  = ssfield(50, "device type (if inode device)")
    st_atime = ssfield(57,
                       default=lambda self: self._st_atime_as_int)
    st_mtime = ssfield(58,
                       default=lambda self: self._st_mtime_as_int)
    st_ctime = ssfield(59,
                       default=lambda self: self._st_ctime_as_int)
""", ns)
        return ns['mydata']

    def w_get_small(self):
        _structseq = self._structseq
        ns = dict(_structseq=_structseq,
                  ssfield=_structseq.structseqfield)
        # need to exec since it uses the py3k-only metaclass syntax
        exec("""class small(metaclass=_structseq.structseqtype):
    one  = ssfield(0, "one")
""", ns)
        return ns['small']


    def test_class(self):
        mydata = self.get_mydata()
        assert mydata.st_mode.__doc__ == "protection bits"
        assert mydata.n_fields == 14
        assert mydata.n_sequence_fields == 10
        assert mydata.n_unnamed_fields == 0

    def test_mydata(self):
        mydata = self.get_mydata()
        x = mydata(range(100, 111))
        assert x.n_sequence_fields == type(x).n_sequence_fields == 10
        assert x.n_fields == type(x).n_fields == 14
        assert x.st_mode  == 100
        assert x.st_size  == 106
        assert x.st_ctime == 109    # copied by the default=lambda...
        assert x.st_rdev  == 110
        assert len(x)     == 10
        assert list(x)    == list(range(100, 110))
        assert x + (5,)   == tuple(range(100, 110)) + (5,)
        assert x[4:12:2]  == (104, 106, 108)
        assert 104 in x
        assert 110 not in x

    def test_default_None(self):
        mydata = self.get_mydata()
        x = mydata(range(100, 110))
        assert x.st_rdev is None

    def test_constructor(self):
        mydata = self.get_mydata()
        x = mydata(range(100, 111), {'st_mtime': 12.25})
        assert x[8] == 108
        assert x.st_mtime == 12.25

    def test_compare_like_tuple(self):
        mydata = self.get_mydata()
        x = mydata(range(100, 111))
        y = mydata(list(range(100, 110)) + [555])
        assert x == tuple(range(100, 110))
        assert x == y    # blame CPython
        assert hash(x) == hash(y) == hash(tuple(range(100, 110)))

    def test_pickle(self):
        import pickle
        import sys
        import types
        sys.modules['mod'] = mod = types.ModuleType('mod')
        try:
            mod.mydata = mydata = self.get_mydata()
            mydata.__module__ = 'mod'
            x = mydata(range(100, 111))
            s = pickle.dumps(x)
            y = pickle.loads(s)
            assert x == y
            assert x.st_rdev == y.st_rdev == 110
        finally:
            del sys.modules['mod']

    def test_readonly(self):
        mydata = self.get_mydata()
        x = mydata(range(100, 113))
        raises((TypeError, AttributeError), "x.st_mode = 1")
        raises((TypeError, AttributeError), "x.st_mtime = 1")
        raises((TypeError, AttributeError), "x.st_rdev = 1")

    def test_no_extra_assignments(self):
        mydata = self.get_mydata()
        x = mydata(range(100, 113))
        raises((TypeError, AttributeError), "x.some_random_attribute = 1")

    def test_small(self):
        small = self.get_small()
        # strange, but for CPython compatibility, a structseq with one field
        # accepts a non-sequence single value and
        # if given a tuple, puts the whole tuple into the field
        x = small(0)
        assert x[0] == 0
        x = small((0, 0, 0))
        assert x[0] == (0, 0, 0)
