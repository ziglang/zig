from pypy.module.cpyext.api import cts

@cts.decl("PyObject * _PyNamespace_New(PyObject *kwds)")
def _PyNamespace_new(space, w_kwds):
    return space.appexec([w_kwds], """(kwds):
        from _structseq import SimpleNamespace
        return SimpleNamespace(**kwds)
        """)
