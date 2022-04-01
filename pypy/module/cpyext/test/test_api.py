import py, pytest
import contextlib
from rpython.rtyper.lltypesystem import lltype
from rpython.translator.c.database import LowLevelDatabase
from rpython.tool.cparser import parse_source
from pypy.interpreter.baseobjspace import W_Root
from pypy.module.cpyext.state import State
from pypy.module.cpyext.api import (
    slot_function, cpython_api, copy_header_files, INTERPLEVEL_API,
    Py_ssize_t, Py_ssize_tP, PyObject, cts, ApiFunction)
from pypy.module.cpyext.test.test_cpyext import (
    freeze_refcnts, LeakCheckingTest)
from pypy.interpreter.error import OperationError
from rpython.rlib import rawrefcount
import os

@contextlib.contextmanager
def raises_w(space, expected_exc):
    with pytest.raises(OperationError) as excinfo:
        yield
    operror = excinfo.value
    assert operror.w_type is getattr(space, 'w_' + expected_exc.__name__)

class BaseApiTest(LeakCheckingTest):
    def setup_class(cls):
        space = cls.space
        cls.preload_builtins(space)
        cls.w_runappdirect = space.wrap(cls.runappdirect)

        class CAPI:
            def __repr__(self):
                return '<%s.%s instance>' % (self.__class__.__module__,
                                             self.__class__.__name__)

            def __getattr__(self, name):
                return getattr(cls.space, name)
        cls.api = CAPI()
        CAPI.__dict__.update(INTERPLEVEL_API)

    def raises(self, space, api, expected_exc, f, *args):
        if not callable(f):
            raise Exception("%s is not callable" % (f,))
        f(*args)
        state = space.fromcache(State)
        operror = state.get_exception()
        if not operror:
            raise Exception("DID NOT RAISE")
        if getattr(space, 'w_' + expected_exc.__name__) is not operror.w_type:
            raise Exception("Wrong exception")
        return state.clear_exception()

    def setup_method(self, func):
        freeze_refcnts(self)

    def teardown_method(self, func):
        state = self.space.fromcache(State)
        try:
            state.check_and_raise_exception()
        except OperationError as e:
            print e.errorstr(self.space)
            raise
        self.cleanup()

@slot_function([PyObject], lltype.Void)
def PyPy_GetWrapped(space, w_arg):
    assert isinstance(w_arg, W_Root)

@slot_function([PyObject], lltype.Void)
def PyPy_GetReference(space, arg):
    assert lltype.typeOf(arg) ==  PyObject

@cpython_api([Py_ssize_t], Py_ssize_t, error=-1)
def PyPy_TypedefTest1(space, arg):
    assert lltype.typeOf(arg) == Py_ssize_t
    return 0

@cpython_api([Py_ssize_tP], Py_ssize_tP)
def PyPy_TypedefTest2(space, arg):
    assert lltype.typeOf(arg) == Py_ssize_tP
    return None

class TestConversion(BaseApiTest):
    def test_conversions(self, space):
        PyPy_GetWrapped(space, space.w_None)
        PyPy_GetReference(space, space.w_None)

    def test_typedef(self, space):
        from rpython.translator.c.database import LowLevelDatabase
        db = LowLevelDatabase()
        assert PyPy_TypedefTest1.api_func.get_c_restype(db) == 'Signed'
        assert PyPy_TypedefTest1.api_func.get_c_args(db) == 'Signed arg0'
        assert PyPy_TypedefTest2.api_func.get_c_restype(db) == 'Signed *'
        assert PyPy_TypedefTest2.api_func.get_c_args(db) == 'Signed *arg0'

        PyPy_TypedefTest1(space, 0)
        ppos = lltype.malloc(Py_ssize_tP.TO, 1, flavor='raw')
        ppos[0] = 0
        PyPy_TypedefTest2(space, ppos)
        lltype.free(ppos, flavor='raw')

@pytest.mark.skipif(os.environ.get('USER')=='root',
                    reason='root can write to all files')
def test_copy_header_files(tmpdir):
    copy_header_files(cts, tmpdir, True)
    def check(name):
        f = tmpdir.join(name)
        assert f.check(file=True)
        py.test.raises(py.error.EACCES, "f.open('w')") # check that it's not writable
    check('Python.h')
    check('modsupport.h')
    check('pypy_decl.h')

def test_write_func():
    db = LowLevelDatabase()
    cdef = """
    typedef ssize_t Py_ssize_t;
    """
    cts = parse_source(cdef)
    cdecl = "Py_ssize_t * some_func(Py_ssize_t*)"
    decl = cts.parse_func(cdecl)
    api_function = ApiFunction(
        decl.get_llargs(cts), decl.get_llresult(cts), lambda space, x: None,
        cdecl=decl)
    assert (api_function.get_api_decl('some_func', db)
            == "PyAPI_FUNC(Py_ssize_t *) some_func(Py_ssize_t * arg0);")

