import py
import sys
import ctypes

try:
    import _rawffi
except ImportError:
    _rawffi = None

class WhiteBoxTests:

    def setup_class(cls):
        if _rawffi:
            py.test.skip("white-box tests for pypy _rawffi based ctypes impl")

def del_funcptr_refs_maybe(obj, attrname):
    dll = getattr(obj, attrname, None)
    if not dll:
        return
    _FuncPtr = dll._FuncPtr
    for name in dir(dll):
        obj = getattr(dll, name, None)
        if isinstance(obj, _FuncPtr):
            delattr(dll, name)

class BaseCTypesTestChecker:
    def setup_class(cls):
        if _rawffi:
            import gc
            for _ in range(4):
                gc.collect()
            try:
                cls.old_num = _rawffi._num_of_allocated_objects()
            except RuntimeError:
                pass

    def teardown_class(cls):
        if not hasattr(sys, 'pypy_translation_info'):
            return
        if sys.pypy_translation_info['translation.gc'] == 'boehm':
            return # it seems that boehm has problems with __del__, so not
                   # everything is freed
        #
        mod = sys.modules[cls.__module__]
        del_funcptr_refs_maybe(mod, 'dll')
        del_funcptr_refs_maybe(mod, 'dll2')
        del_funcptr_refs_maybe(mod, 'lib')
        del_funcptr_refs_maybe(mod, 'testdll')
        del_funcptr_refs_maybe(mod, 'ctdll')
        del_funcptr_refs_maybe(cls, '_dll')
        #
        if hasattr(cls, 'old_num'):
            import gc
            for _ in range(4):
                gc.collect()
            # there is one reference coming from the byref() above
            assert _rawffi._num_of_allocated_objects() == cls.old_num
