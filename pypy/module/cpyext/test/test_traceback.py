from rpython.rtyper.lltypesystem import lltype, rffi
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.pyobject import PyObject, make_ref, from_ref, decref
from pypy.module.cpyext.pytraceback import PyTracebackObject
from pypy.interpreter.pytraceback import PyTraceback
from pypy.interpreter.baseobjspace import AppExecCache

class TestPyTracebackObject(BaseApiTest):
    def test_traceback(self, space, api):
        src = """():
            import sys
            try:
                1/0
            except:
                return sys.exc_info()[2]
        """
        w_traceback = space.appexec([], src)

        py_obj = make_ref(space, w_traceback)
        py_traceback = rffi.cast(PyTracebackObject, py_obj)
        assert (from_ref(space, rffi.cast(PyObject, py_obj.c_ob_type)) is
                space.gettypeobject(PyTraceback.typedef))

        traceback = space.interp_w(PyTraceback, w_traceback)
        assert traceback.lasti == py_traceback.c_tb_lasti
        assert traceback.get_lineno() == py_traceback.c_tb_lineno
        assert space.eq_w(space.getattr(w_traceback, space.wrap("tb_lasti")),
                          space.wrap(py_traceback.c_tb_lasti))
        assert space.is_w(space.getattr(w_traceback, space.wrap("tb_frame")),
                          from_ref(space, rffi.cast(PyObject,
                                                    py_traceback.c_tb_frame)))

        while not space.is_w(w_traceback, space.w_None):
            assert space.is_w(
                w_traceback,
                from_ref(space, rffi.cast(PyObject, py_traceback)))
            w_traceback = space.getattr(w_traceback, space.wrap("tb_next"))
            py_traceback = py_traceback.c_tb_next

        assert lltype.normalizeptr(py_traceback) is None

        decref(space, py_obj)
        # hack to allow the code object to be freed
        del space.fromcache(AppExecCache).content[src]
