from ctypes import *
import sys
import pytest

@pytest.fixture
def dll(sofile):
    return CDLL(str(sofile), use_errno=True)


def test_char_result(dll):
    f = dll._testfunc_i_bhilfd
    f.argtypes = [c_byte, c_short, c_int, c_long, c_float, c_double]
    f.restype = c_char
    result = f(0, 0, 0, 0, 0, 0)
    assert result == b'\x00'

def test_boolresult(dll):
    f = dll._testfunc_i_bhilfd
    f.argtypes = [c_byte, c_short, c_int, c_long, c_float, c_double]
    f.restype = c_bool
    false_result = f(0, 0, 0, 0, 0, 0)
    assert false_result is False
    true_result = f(1, 0, 0, 0, 0, 0)
    assert true_result is True

def test_unicode_function_name(dll):
    f = dll[u'_testfunc_i_bhilfd']
    f.argtypes = [c_byte, c_short, c_int, c_long, c_float, c_double]
    f.restype = c_int
    result = f(1, 2, 3, 4, 5.0, 6.0)
    assert result == 21

def test_truncate_python_longs(dll):
    f = dll._testfunc_i_bhilfd
    f.argtypes = [c_byte, c_short, c_int, c_long, c_float, c_double]
    f.restype = c_int
    x = sys.maxsize * 2
    result = f(x, x, x, x, 0, 0)
    assert result == -8

def test_convert_pointers(dll):
    f = dll.deref_LP_c_char_p
    f.restype = c_char
    f.argtypes = [POINTER(c_char_p)]
    #
    s = c_char_p(b'hello world')
    ps = pointer(s)
    assert f(ps) == b'h'
    assert f(s) == b'h'  # automatic conversion from char** to char*

################################################################

def test_call_some_args(dll):
    f = dll.my_strchr
    f.argtypes = [c_char_p]
    f.restype = c_char_p
    result = f(b"abcd", ord("b"))
    assert result == b"bcd"

@pytest.mark.pypy_only
def test_keepalive_buffers(monkeypatch, dll):
    import gc
    f = dll.my_strchr
    f.argtypes = [c_char_p]
    f.restype = c_char_p
    #
    orig__call_funcptr = f._call_funcptr
    def _call_funcptr(funcptr, *newargs):
        gc.collect()
        gc.collect()
        gc.collect()
        return orig__call_funcptr(funcptr, *newargs)
    monkeypatch.setattr(f, '_call_funcptr', _call_funcptr)
    #
    result = f(b"abcd", ord("b"))
    assert result == b"bcd"

def test_caching_bug_1(dll):
    # the same test as test_call_some_args, with two extra lines
    # in the middle that trigger caching in f._ptr, which then
    # makes the last two lines fail
    f = dll.my_strchr
    f.argtypes = [c_char_p, c_int]
    f.restype = c_char_p
    result = f(b"abcd", ord("b"))
    assert result == b"bcd"
    result = f(b"abcd", ord("b"), 42)
    assert result == b"bcd"

def test_argument_conversion_and_checks(dll):
    #This test is designed to check for segfaults if the wrong type of argument is passed as parameter
    strlen = dll.my_strchr
    strlen.argtypes = [c_char_p, c_int]
    strlen.restype = c_char_p
    assert strlen(b"eggs", ord("g")) == b"ggs"

    # Should raise ArgumentError, not segfault
    with pytest.raises(ArgumentError):
        strlen(0, 0)
    with pytest.raises(ArgumentError):
        strlen(False, 0)

def test_union_as_passed_value(dll):
    class UN(Union):
        _fields_ = [("x", c_short),
                    ("y", c_long)]
    dll.ret_un_func.restype = UN
    dll.ret_un_func.argtypes = [UN]
    A = UN * 2
    a = A()
    a[1].x = 33
    u = dll.ret_un_func(a[1])
    assert u.y == 33 * 10000

@pytest.mark.pypy_only
def test_cache_funcptr(dll):
    tf_b = dll.tf_b
    tf_b.restype = c_byte
    tf_b.argtypes = (c_byte,)
    assert tf_b(-126) == -42
    ptr = tf_b._ptr
    assert ptr is not None
    assert tf_b(-126) == -42
    assert tf_b._ptr is ptr

def test_custom_from_param(dll):
    class A(c_byte):
        @classmethod
        def from_param(cls, obj):
            seen.append(obj)
            return -126
    tf_b = dll.tf_b
    tf_b.restype = c_byte
    tf_b.argtypes = (c_byte,)
    tf_b.argtypes = [A]
    seen = []
    assert tf_b("yadda") == -42
    assert seen == ["yadda"]

@pytest.mark.xfail(reason="warnings are disabled")
def test_warnings(dll):
    import warnings
    warnings.simplefilter("always")
    with warnings.catch_warnings(record=True) as w:
        dll.get_an_integer()
        assert len(w) == 1
        assert issubclass(w[0].category, RuntimeWarning)
        assert "C function without declared arguments called" in str(w[0].message)

@pytest.mark.xfail
def test_errcheck(dll):
    import warnings
    def errcheck(result, func, args):
        assert result == -42
        assert type(result) is int
        arg, = args
        assert arg == -126
        assert type(arg) is int
        return result
    #
    tf_b = dll.tf_b
    tf_b.restype = c_byte
    tf_b.argtypes = (c_byte,)
    tf_b.errcheck = errcheck
    assert tf_b(-126) == -42
    del tf_b.errcheck
    with warnings.catch_warnings(record=True) as w:
        dll.get_an_integer.argtypes = []
        dll.get_an_integer()
        assert len(w) == 1
        assert issubclass(w[0].category, RuntimeWarning)
        assert "C function without declared return type called" in str(w[0].message)

    with warnings.catch_warnings(record=True) as w:
        dll.get_an_integer.restype = None
        dll.get_an_integer()
        assert len(w) == 0

    warnings.resetwarnings()

def test_errno(dll):
    test_errno = dll.test_errno
    test_errno.restype = c_int
    set_errno(42)
    res = test_errno()
    n = get_errno()
    assert (res, n) == (42, 43)
    set_errno(0)
    assert get_errno() == 0

def test_issue1655(dll):
    def ret_list_p(icount):
        def sz_array_p(obj, func, args):
            assert ('.LP_c_int object' in repr(obj) or
                    '.LP_c_long object' in repr(obj))
            assert repr(args) =="(b'testing!', c_int(4))"
            assert args[icount].value == 4
            return [obj[i] for i in range(args[icount].value)]
        return sz_array_p

    get_data_prototype = CFUNCTYPE(POINTER(c_int),
                                    c_char_p, POINTER(c_int))
    get_data_paramflag = ((1,), (2,))
    get_data_signature = ('test_issue1655', dll)

    get_data = get_data_prototype(get_data_signature, get_data_paramflag)
    assert get_data(b'testing!') == 4

    get_data.errcheck = ret_list_p(1)
    assert get_data(b'testing!') == [-1, -2, -3, -4]

def test_issue2533(tmpdir):
    import cffi
    ffi = cffi.FFI()
    ffi.cdef("int **fetchme(void);")
    ffi.set_source("_x_cffi", """
        int **fetchme(void)
        {
            static int a = 42;
            static int *pa = &a;
            return &pa;
        }
    """)
    ffi.compile(verbose=True, tmpdir=str(tmpdir))

    import sys
    sys.path.insert(0, str(tmpdir))
    try:
        from _x_cffi import ffi, lib
    finally:
        sys.path.pop(0)
    fetchme = ffi.addressof(lib, 'fetchme')
    fetchme = int(ffi.cast("intptr_t", fetchme))

    FN = CFUNCTYPE(POINTER(POINTER(c_int)))
    ff = cast(fetchme, FN)

    g = ff()
    assert g.contents.contents.value == 42

    h = c_int(43)
    g[0] = pointer(h)     # used to crash here
    assert g.contents.contents.value == 43
