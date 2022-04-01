# Run the _testcapi module tests (tests for the Python/C API):  by defn,
# these are all functions _testcapi exports whose name begins with 'test_'.

from collections import OrderedDict
import os
import pickle
import random
import re
import subprocess
import sys
import textwrap
import threading
import time
import unittest
import weakref
import importlib.machinery
import importlib.util
from test import support
from test.support import MISSING_C_DOCSTRINGS, refcount_test
from test.support.script_helper import assert_python_failure, assert_python_ok
try:
    import _posixsubprocess
except ImportError:
    _posixsubprocess = None

# Skip this test if the _testcapi module isn't available.
_testcapi = support.import_module('_testcapi')

# CPython internals
try:
    import _testinternalcapi
except ImportError:
    _testinternalcapi = None

# Were we compiled --with-pydebug or with #define Py_DEBUG?
Py_DEBUG = hasattr(sys, 'gettotalrefcount')

skips = []
if support.check_impl_detail(pypy=True):
    skips += [
        'test_lazy_hash_inheritance',
        'test_capsule',
    ]

def testfunction(self):
    """some doc"""
    return self


class InstanceMethod:
    id = _testcapi.instancemethod(id)
    testfunction = _testcapi.instancemethod(testfunction)

class CAPITest(unittest.TestCase):

    def test_instancemethod(self):
        inst = InstanceMethod()
        self.assertEqual(id(inst), inst.id())
        self.assertTrue(inst.testfunction() is inst)
        self.assertEqual(inst.testfunction.__doc__, testfunction.__doc__)
        self.assertEqual(InstanceMethod.testfunction.__doc__, testfunction.__doc__)

        InstanceMethod.testfunction.attribute = "test"
        self.assertEqual(testfunction.attribute, "test")
        self.assertRaises(AttributeError, setattr, inst.testfunction, "attribute", "test")

    @unittest.skipIf(support.check_impl_detail(pypy=True),
                    "doesn't crash on PyPy")
    def test_no_FatalError_infinite_loop(self):
        with support.SuppressCrashReport():
            p = subprocess.Popen([sys.executable, "-c",
                                  'import _testcapi;'
                                  '_testcapi.crash_no_current_thread()'],
                                 stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE)
        (out, err) = p.communicate()
        self.assertEqual(out, b'')
        # This used to cause an infinite loop.
        self.assertTrue(err.rstrip().startswith(
                         b'Fatal Python error: '
                         b'PyThreadState_Get: '
                         b'the function must be called with the GIL held, '
                         b'but the GIL is released '
                         b'(the current Python thread state is NULL)'),
                        err)

    def test_memoryview_from_NULL_pointer(self):
        self.assertRaises(ValueError, _testcapi.make_memoryview_from_NULL_pointer)

    def test_exc_info(self):
        raised_exception = ValueError("5")
        new_exc = TypeError("TEST")
        try:
            raise raised_exception
        except ValueError as e:
            tb = e.__traceback__
            orig_sys_exc_info = sys.exc_info()
            orig_exc_info = _testcapi.set_exc_info(new_exc.__class__, new_exc, None)
            new_sys_exc_info = sys.exc_info()
            new_exc_info = _testcapi.set_exc_info(*orig_exc_info)
            reset_sys_exc_info = sys.exc_info()

            self.assertEqual(orig_exc_info[1], e)

            self.assertSequenceEqual(orig_exc_info, (raised_exception.__class__, raised_exception, tb))
            self.assertSequenceEqual(orig_sys_exc_info, orig_exc_info)
            self.assertSequenceEqual(reset_sys_exc_info, orig_exc_info)
            self.assertSequenceEqual(new_exc_info, (new_exc.__class__, new_exc, None))
            self.assertSequenceEqual(new_sys_exc_info, new_exc_info)
        else:
            self.assertTrue(False)

    @unittest.skipUnless(_posixsubprocess, '_posixsubprocess required for this test.')
    def test_seq_bytes_to_charp_array(self):
        # Issue #15732: crash in _PySequence_BytesToCharpArray()
        class Z(object):
            def __len__(self):
                return 1
        self.assertRaises(TypeError, _posixsubprocess.fork_exec,
                          1,Z(),3,(1, 2),5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)
        # Issue #15736: overflow in _PySequence_BytesToCharpArray()
        class Z(object):
            def __len__(self):
                return sys.maxsize
            def __getitem__(self, i):
                return b'x'
        self.assertRaises(MemoryError, _posixsubprocess.fork_exec,
                          1,Z(),3,(1, 2),5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)

    @unittest.skipUnless(_posixsubprocess, '_posixsubprocess required for this test.')
    def test_subprocess_fork_exec(self):
        class Z(object):
            def __len__(self):
                return 1

        # Issue #15738: crash in subprocess_fork_exec()
        self.assertRaises(TypeError, _posixsubprocess.fork_exec,
                          Z(),[b'1'],3,(1, 2),5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)

    @unittest.skipIf(MISSING_C_DOCSTRINGS,
                     "Signature information for builtins requires docstrings")
    def test_docstring_signature_parsing(self):

        self.assertEqual(_testcapi.no_docstring.__doc__, None)
        self.assertEqual(_testcapi.no_docstring.__text_signature__, None)

        self.assertEqual(_testcapi.docstring_empty.__doc__, None)
        self.assertEqual(_testcapi.docstring_empty.__text_signature__, None)

        self.assertEqual(_testcapi.docstring_no_signature.__doc__,
            "This docstring has no signature.")
        self.assertEqual(_testcapi.docstring_no_signature.__text_signature__, None)

        self.assertEqual(_testcapi.docstring_with_invalid_signature.__doc__,
            "docstring_with_invalid_signature($module, /, boo)\n"
            "\n"
            "This docstring has an invalid signature."
            )
        self.assertEqual(_testcapi.docstring_with_invalid_signature.__text_signature__, None)

        self.assertEqual(_testcapi.docstring_with_invalid_signature2.__doc__,
            "docstring_with_invalid_signature2($module, /, boo)\n"
            "\n"
            "--\n"
            "\n"
            "This docstring also has an invalid signature."
            )
        self.assertEqual(_testcapi.docstring_with_invalid_signature2.__text_signature__, None)

        self.assertEqual(_testcapi.docstring_with_signature.__doc__,
            "This docstring has a valid signature.")
        self.assertEqual(_testcapi.docstring_with_signature.__text_signature__, "($module, /, sig)")

        self.assertEqual(_testcapi.docstring_with_signature_but_no_doc.__doc__, None)
        self.assertEqual(_testcapi.docstring_with_signature_but_no_doc.__text_signature__,
            "($module, /, sig)")

        self.assertEqual(_testcapi.docstring_with_signature_and_extra_newlines.__doc__,
            "\nThis docstring has a valid signature and some extra newlines.")
        self.assertEqual(_testcapi.docstring_with_signature_and_extra_newlines.__text_signature__,
            "($module, /, parameter)")

    def test_c_type_with_matrix_multiplication(self):
        M = _testcapi.matmulType
        m1 = M()
        m2 = M()
        self.assertEqual(m1 @ m2, ("matmul", m1, m2))
        self.assertEqual(m1 @ 42, ("matmul", m1, 42))
        self.assertEqual(42 @ m1, ("matmul", 42, m1))
        o = m1
        o @= m2
        self.assertEqual(o, ("imatmul", m1, m2))
        o = m1
        o @= 42
        self.assertEqual(o, ("imatmul", m1, 42))
        o = 42
        o @= m1
        self.assertEqual(o, ("matmul", 42, m1))

    def test_c_type_with_ipow(self):
        # When the __ipow__ method of a type was implemented in C, using the
        # modulo param would cause segfaults.
        o = _testcapi.ipowType()
        self.assertEqual(o.__ipow__(1), (1, None))
        self.assertEqual(o.__ipow__(2, 2), (2, 2))

    def test_return_null_without_error(self):
        # Issue #23571: A function must not return NULL without setting an
        # error
        if Py_DEBUG:
            code = textwrap.dedent("""
                import _testcapi
                from test import support

                with support.SuppressCrashReport():
                    _testcapi.return_null_without_error()
            """)
            rc, out, err = assert_python_failure('-c', code)
            self.assertRegex(err.replace(b'\r', b''),
                             br'Fatal Python error: _Py_CheckFunctionResult: '
                                br'a function returned NULL '
                                br'without setting an error\n'
                             br'Python runtime state: initialized\n'
                             br'SystemError: <built-in function '
                                 br'return_null_without_error> returned NULL '
                                 br'without setting an error\n'
                             br'\n'
                             br'Current thread.*:\n'
                             br'  File .*", line 6 in <module>')
        else:
            with self.assertRaises(SystemError) as cm:
                _testcapi.return_null_without_error()
            # PyPy change: different message
            self.assertRegex(str(cm.exception),
                'Function returned a NULL result without setting an exception')

    def test_return_result_with_error(self):
        # Issue #23571: A function must not return a result with an error set
        if Py_DEBUG:
            code = textwrap.dedent("""
                import _testcapi
                from test import support

                with support.SuppressCrashReport():
                    _testcapi.return_result_with_error()
            """)
            rc, out, err = assert_python_failure('-c', code)
            self.assertRegex(err.replace(b'\r', b''),
                             br'Fatal Python error: _Py_CheckFunctionResult: '
                                 br'a function returned a result '
                                 br'with an error set\n'
                             br'Python runtime state: initialized\n'
                             br'ValueError\n'
                             br'\n'
                             br'The above exception was the direct cause '
                                br'of the following exception:\n'
                             br'\n'
                             br'SystemError: <built-in '
                                br'function return_result_with_error> '
                                br'returned a result with an error set\n'
                             br'\n'
                             br'Current thread.*:\n'
                             br'  File .*, line 6 in <module>')
        else:
            with self.assertRaises(SystemError) as cm:
                _testcapi.return_result_with_error()
            # PyPy change: different message
            self.assertRegex(str(cm.exception),
                'An exception was set, but function returned a value')

    def test_buildvalue_N(self):
        _testcapi.test_buildvalue_N()

    @support.cpython_only
    def test_set_nomemory(self):
        code = """if 1:
            import _testcapi

            class C(): pass

            # The first loop tests both functions and that remove_mem_hooks()
            # can be called twice in a row. The second loop checks a call to
            # set_nomemory() after a call to remove_mem_hooks(). The third
            # loop checks the start and stop arguments of set_nomemory().
            for outer_cnt in range(1, 4):
                start = 10 * outer_cnt
                for j in range(100):
                    if j == 0:
                        if outer_cnt != 3:
                            _testcapi.set_nomemory(start)
                        else:
                            _testcapi.set_nomemory(start, start + 1)
                    try:
                        C()
                    except MemoryError as e:
                        if outer_cnt != 3:
                            _testcapi.remove_mem_hooks()
                        print('MemoryError', outer_cnt, j)
                        _testcapi.remove_mem_hooks()
                        break
        """
        rc, out, err = assert_python_ok('-c', code)
        self.assertIn(b'MemoryError 1 10', out)
        self.assertIn(b'MemoryError 2 20', out)
        self.assertIn(b'MemoryError 3 30', out)

    def test_mapping_keys_values_items(self):
        class Mapping1(dict):
            def keys(self):
                return list(super().keys())
            def values(self):
                return list(super().values())
            def items(self):
                return list(super().items())
        class Mapping2(dict):
            def keys(self):
                return tuple(super().keys())
            def values(self):
                return tuple(super().values())
            def items(self):
                return tuple(super().items())
        dict_obj = {'foo': 1, 'bar': 2, 'spam': 3}

        for mapping in [{}, OrderedDict(), Mapping1(), Mapping2(),
                        dict_obj, OrderedDict(dict_obj),
                        Mapping1(dict_obj), Mapping2(dict_obj)]:
            self.assertListEqual(_testcapi.get_mapping_keys(mapping),
                                 list(mapping.keys()))
            self.assertListEqual(_testcapi.get_mapping_values(mapping),
                                 list(mapping.values()))
            self.assertListEqual(_testcapi.get_mapping_items(mapping),
                                 list(mapping.items()))

    def test_mapping_keys_values_items_bad_arg(self):
        self.assertRaises(AttributeError, _testcapi.get_mapping_keys, None)
        self.assertRaises(AttributeError, _testcapi.get_mapping_values, None)
        self.assertRaises(AttributeError, _testcapi.get_mapping_items, None)

        class BadMapping:
            def keys(self):
                return None
            def values(self):
                return None
            def items(self):
                return None
        bad_mapping = BadMapping()
        self.assertRaises(TypeError, _testcapi.get_mapping_keys, bad_mapping)
        self.assertRaises(TypeError, _testcapi.get_mapping_values, bad_mapping)
        self.assertRaises(TypeError, _testcapi.get_mapping_items, bad_mapping)

    @unittest.skipUnless(hasattr(_testcapi, 'negative_refcount'),
                         'need _testcapi.negative_refcount')
    def test_negative_refcount(self):
        # bpo-35059: Check that Py_DECREF() reports the correct filename
        # when calling _Py_NegativeRefcount() to abort Python.
        code = textwrap.dedent("""
            import _testcapi
            from test import support

            with support.SuppressCrashReport():
                _testcapi.negative_refcount()
        """)
        rc, out, err = assert_python_failure('-c', code)
        self.assertRegex(err,
                         br'_testcapimodule\.c:[0-9]+: '
                         br'_Py_NegativeRefcount: Assertion failed: '
                         br'object has negative ref count')

    def test_trashcan_subclass(self):
        # bpo-35983: Check that the trashcan mechanism for "list" is NOT
        # activated when its tp_dealloc is being called by a subclass
        from _testcapi import MyList
        L = None
        for i in range(1000):
            L = MyList((L,))

    @support.requires_resource('cpu')
    def test_trashcan_python_class1(self):
        self.do_test_trashcan_python_class(list)

    @support.requires_resource('cpu')
    def test_trashcan_python_class2(self):
        from _testcapi import MyList
        self.do_test_trashcan_python_class(MyList)

    @support.cpython_only
    def do_test_trashcan_python_class(self, base):
        # Check that the trashcan mechanism works properly for a Python
        # subclass of a class using the trashcan (this specific test assumes
        # that the base class "base" behaves like list)
        class PyList(base):
            # Count the number of PyList instances to verify that there is
            # no memory leak
            num = 0
            def __init__(self, *args):
                __class__.num += 1
                super().__init__(*args)
            def __del__(self):
                __class__.num -= 1

        for parity in (0, 1):
            L = None
            # We need in the order of 2**20 iterations here such that a
            # typical 8MB stack would overflow without the trashcan.
            for i in range(2**20):
                L = PyList((L,))
                L.attr = i
            if parity:
                # Add one additional nesting layer
                L = (L,)
            self.assertGreater(PyList.num, 0)
            del L
            self.assertEqual(PyList.num, 0)

    @refcount_test
    def test_subclass_of_heap_gc_ctype_with_tpdealloc_decrefs_once(self):
        class HeapGcCTypeSubclass(_testcapi.HeapGcCType):
            def __init__(self):
                self.value2 = 20
                super().__init__()

        subclass_instance = HeapGcCTypeSubclass()
        type_refcnt = sys.getrefcount(HeapGcCTypeSubclass)

        # Test that subclass instance was fully created
        self.assertEqual(subclass_instance.value, 10)
        self.assertEqual(subclass_instance.value2, 20)

        # Test that the type reference count is only decremented once
        del subclass_instance
        self.assertEqual(type_refcnt - 1, sys.getrefcount(HeapGcCTypeSubclass))

    @refcount_test
    def test_subclass_of_heap_gc_ctype_with_del_modifying_dunder_class_only_decrefs_once(self):
        class A(_testcapi.HeapGcCType):
            def __init__(self):
                self.value2 = 20
                super().__init__()

        class B(A):
            def __init__(self):
                super().__init__()

            def __del__(self):
                self.__class__ = A
                A.refcnt_in_del = sys.getrefcount(A)
                B.refcnt_in_del = sys.getrefcount(B)

        subclass_instance = B()
        type_refcnt = sys.getrefcount(B)
        new_type_refcnt = sys.getrefcount(A)

        # Test that subclass instance was fully created
        self.assertEqual(subclass_instance.value, 10)
        self.assertEqual(subclass_instance.value2, 20)

        del subclass_instance

        # Test that setting __class__ modified the reference counts of the types
        self.assertEqual(type_refcnt - 1, B.refcnt_in_del)
        self.assertEqual(new_type_refcnt + 1, A.refcnt_in_del)

        # Test that the original type already has decreased its refcnt
        self.assertEqual(type_refcnt - 1, sys.getrefcount(B))

        # Test that subtype_dealloc decref the newly assigned __class__ only once
        self.assertEqual(new_type_refcnt, sys.getrefcount(A))

    def test_heaptype_with_dict(self):
        inst = _testcapi.HeapCTypeWithDict()
        inst.foo = 42
        self.assertEqual(inst.foo, 42)
        self.assertEqual(inst.dictobj, inst.__dict__)
        self.assertEqual(inst.dictobj, {"foo": 42})

        inst = _testcapi.HeapCTypeWithDict()
        self.assertEqual({}, inst.__dict__)

    def test_heaptype_with_negative_dict(self):
        inst = _testcapi.HeapCTypeWithNegativeDict()
        inst.foo = 42
        self.assertEqual(inst.foo, 42)
        self.assertEqual(inst.dictobj, inst.__dict__)
        self.assertEqual(inst.dictobj, {"foo": 42})

        inst = _testcapi.HeapCTypeWithNegativeDict()
        self.assertEqual({}, inst.__dict__)

    def test_heaptype_with_weakref(self):
        inst = _testcapi.HeapCTypeWithWeakref()
        ref = weakref.ref(inst)
        self.assertEqual(ref(), inst)
        self.assertEqual(inst.weakreflist, ref)

    def test_heaptype_with_buffer(self):
        inst = _testcapi.HeapCTypeWithBuffer()
        b = bytes(inst)
        self.assertEqual(b, b"1234")

    @refcount_test
    def test_c_subclass_of_heap_ctype_with_tpdealloc_decrefs_once(self):
        subclass_instance = _testcapi.HeapCTypeSubclass()
        type_refcnt = sys.getrefcount(_testcapi.HeapCTypeSubclass)

        # Test that subclass instance was fully created
        self.assertEqual(subclass_instance.value, 10)
        self.assertEqual(subclass_instance.value2, 20)

        # Test that the type reference count is only decremented once
        del subclass_instance
        self.assertEqual(type_refcnt - 1, sys.getrefcount(_testcapi.HeapCTypeSubclass))

    @refcount_test
    def test_c_subclass_of_heap_ctype_with_del_modifying_dunder_class_only_decrefs_once(self):
        subclass_instance = _testcapi.HeapCTypeSubclassWithFinalizer()
        type_refcnt = sys.getrefcount(_testcapi.HeapCTypeSubclassWithFinalizer)
        new_type_refcnt = sys.getrefcount(_testcapi.HeapCTypeSubclass)

        # Test that subclass instance was fully created
        self.assertEqual(subclass_instance.value, 10)
        self.assertEqual(subclass_instance.value2, 20)

        # The tp_finalize slot will set __class__ to HeapCTypeSubclass
        del subclass_instance

        # Test that setting __class__ modified the reference counts of the types
        self.assertEqual(type_refcnt - 1, _testcapi.HeapCTypeSubclassWithFinalizer.refcnt_in_del)
        self.assertEqual(new_type_refcnt + 1, _testcapi.HeapCTypeSubclass.refcnt_in_del)

        # Test that the original type already has decreased its refcnt
        self.assertEqual(type_refcnt - 1, sys.getrefcount(_testcapi.HeapCTypeSubclassWithFinalizer))

        # Test that subtype_dealloc decref the newly assigned __class__ only once
        self.assertEqual(new_type_refcnt, sys.getrefcount(_testcapi.HeapCTypeSubclass))

    def test_heaptype_with_setattro(self):
        obj = _testcapi.HeapCTypeSetattr()
        self.assertEqual(obj.pvalue, 10)
        obj.value = 12
        self.assertEqual(obj.pvalue, 12)
        del obj.value
        self.assertEqual(obj.pvalue, 0)

    def test_pynumber_tobase(self):
        from _testcapi import pynumber_tobase
        self.assertEqual(pynumber_tobase(123, 2), '0b1111011')
        self.assertEqual(pynumber_tobase(123, 8), '0o173')
        self.assertEqual(pynumber_tobase(123, 10), '123')
        self.assertEqual(pynumber_tobase(123, 16), '0x7b')
        self.assertEqual(pynumber_tobase(-123, 2), '-0b1111011')
        self.assertEqual(pynumber_tobase(-123, 8), '-0o173')
        self.assertEqual(pynumber_tobase(-123, 10), '-123')
        self.assertEqual(pynumber_tobase(-123, 16), '-0x7b')
        self.assertRaises(TypeError, pynumber_tobase, 123.0, 10)
        self.assertRaises(TypeError, pynumber_tobase, '123', 10)
        self.assertRaises(SystemError, pynumber_tobase, 123, 0)

    def test_pyobject_repr_from_null(self):
        s = _testcapi.pyobject_repr_from_null()
        self.assertEqual(s, '<NULL>')

    def test_pyobject_str_from_null(self):
        s = _testcapi.pyobject_str_from_null()
        self.assertEqual(s, '<NULL>')

    def test_pyobject_bytes_from_null(self):
        s = _testcapi.pyobject_bytes_from_null()
        self.assertEqual(s, b'<NULL>')

    def test_Py_CompileString(self):
        # Check that Py_CompileString respects the coding cookie
        _compile = _testcapi.Py_CompileString
        code = b"# -*- coding: latin1 -*-\nprint('\xc2\xa4')\n"
        result = _compile(code)
        expected = compile(code, "<string>", "exec")
        self.assertEqual(result.co_consts, expected.co_consts)


@unittest.skipIf(support.check_impl_detail(pypy=True),
                 'Py_AddPendingCall not currently supported.')
class TestPendingCalls(unittest.TestCase):

    def pendingcalls_submit(self, l, n):
        def callback():
            #this function can be interrupted by thread switching so let's
            #use an atomic operation
            l.append(None)

        for i in range(n):
            time.sleep(random.random()*0.02) #0.01 secs on average
            #try submitting callback until successful.
            #rely on regular interrupt to flush queue if we are
            #unsuccessful.
            while True:
                if _testcapi._pending_threadfunc(callback):
                    break

    def pendingcalls_wait(self, l, n, context = None):
        #now, stick around until l[0] has grown to 10
        count = 0
        while len(l) != n:
            #this busy loop is where we expect to be interrupted to
            #run our callbacks.  Note that callbacks are only run on the
            #main thread
            if False and support.verbose:
                print("(%i)"%(len(l),),)
            for i in range(1000):
                a = i*i
            if context and not context.event.is_set():
                continue
            count += 1
            self.assertTrue(count < 10000,
                "timeout waiting for %i callbacks, got %i"%(n, len(l)))
        if False and support.verbose:
            print("(%i)"%(len(l),))

    def test_pendingcalls_threaded(self):

        #do every callback on a separate thread
        n = 32 #total callbacks
        threads = []
        class foo(object):pass
        context = foo()
        context.l = []
        context.n = 2 #submits per thread
        context.nThreads = n // context.n
        context.nFinished = 0
        context.lock = threading.Lock()
        context.event = threading.Event()

        threads = [threading.Thread(target=self.pendingcalls_thread,
                                    args=(context,))
                   for i in range(context.nThreads)]
        with support.start_threads(threads):
            self.pendingcalls_wait(context.l, n, context)

    def pendingcalls_thread(self, context):
        try:
            self.pendingcalls_submit(context.l, context.n)
        finally:
            with context.lock:
                context.nFinished += 1
                nFinished = context.nFinished
                if False and support.verbose:
                    print("finished threads: ", nFinished)
            if nFinished == context.nThreads:
                context.event.set()

    def test_pendingcalls_non_threaded(self):
        #again, just using the main thread, likely they will all be dispatched at
        #once.  It is ok to ask for too many, because we loop until we find a slot.
        #the loop can be interrupted to dispatch.
        #there are only 32 dispatch slots, so we go for twice that!
        l = []
        n = 64
        self.pendingcalls_submit(l, n)
        self.pendingcalls_wait(l, n)


@unittest.skipIf(support.check_impl_detail(pypy=True),
                "subinterpreters not implemented on PyPy")
class SubinterpreterTest(unittest.TestCase):

    def test_subinterps(self):
        import builtins
        r, w = os.pipe()
        code = """if 1:
            import sys, builtins, pickle
            with open({:d}, "wb") as f:
                pickle.dump(id(sys.modules), f)
                pickle.dump(id(builtins), f)
            """.format(w)
        with open(r, "rb") as f:
            ret = support.run_in_subinterp(code)
            self.assertEqual(ret, 0)
            self.assertNotEqual(pickle.load(f), id(sys.modules))
            self.assertNotEqual(pickle.load(f), id(builtins))

    def test_subinterps_recent_language_features(self):
        r, w = os.pipe()
        code = """if 1:
            import pickle
            with open({:d}, "wb") as f:

                @(lambda x:x)  # Py 3.9
                def noop(x): return x

                a = (b := f'1{{2}}3') + noop('x')  # Py 3.8 (:=) / 3.6 (f'')

                async def foo(arg): return await arg  # Py 3.5

                pickle.dump(dict(a=a, b=b), f)
            """.format(w)

        with open(r, "rb") as f:
            ret = support.run_in_subinterp(code)
            self.assertEqual(ret, 0)
            self.assertEqual(pickle.load(f), {'a': '123x', 'b': '123'})

    def test_mutate_exception(self):
        """
        Exceptions saved in global module state get shared between
        individual module instances. This test checks whether or not
        a change in one interpreter's module gets reflected into the
        other ones.
        """
        import binascii

        support.run_in_subinterp("import binascii; binascii.Error.foobar = 'foobar'")

        self.assertFalse(hasattr(binascii.Error, "foobar"))

    def test_module_state_shared_in_global(self):
        """
        bpo-44050: Extension module state should be shared between interpreters
        when it doesn't support sub-interpreters.
        """
        r, w = os.pipe()
        self.addCleanup(os.close, r)
        self.addCleanup(os.close, w)

        script = textwrap.dedent(f"""
            import importlib.machinery
            import importlib.util
            import os

            fullname = '_test_module_state_shared'
            origin = importlib.util.find_spec('_testmultiphase').origin
            loader = importlib.machinery.ExtensionFileLoader(fullname, origin)
            spec = importlib.util.spec_from_loader(fullname, loader)
            module = importlib.util.module_from_spec(spec)
            attr_id = str(id(module.Error)).encode()

            os.write({w}, attr_id)
            """)
        exec(script)
        main_attr_id = os.read(r, 100)

        ret = support.run_in_subinterp(script)
        self.assertEqual(ret, 0)
        subinterp_attr_id = os.read(r, 100)
        self.assertEqual(main_attr_id, subinterp_attr_id)


class TestThreadState(unittest.TestCase):

    @support.reap_threads
    def test_thread_state(self):
        # some extra thread-state tests driven via _testcapi
        def target():
            idents = []

            def callback():
                idents.append(threading.get_ident())

            _testcapi._test_thread_state(callback)
            a = b = callback
            time.sleep(1)
            # Check our main thread is in the list exactly 3 times.
            self.assertEqual(idents.count(threading.get_ident()), 3,
                             "Couldn't find main thread correctly in the list")

        target()
        t = threading.Thread(target=target)
        t.start()
        t.join()


class Test_testcapi(unittest.TestCase):
    locals().update((name, getattr(_testcapi, name))
                    for name in dir(_testcapi)
                    if name.startswith('test_') and name not in skips and not name.endswith('_code'))


@unittest.skipIf(support.check_impl_detail(pypy=True),
    "_testinternalcapi is CPython only")
class Test_testinternalcapi(unittest.TestCase):
    locals().update((name, getattr(_testinternalcapi, name))
                    for name in dir(_testinternalcapi)
                    if name.startswith('test_'))


class PyMemDebugTests(unittest.TestCase):
    PYTHONMALLOC = 'debug'
    # '0x04c06e0' or '04C06E0'
    PTR_REGEX = r'(?:0x)?[0-9a-fA-F]+'

    def check(self, code):
        with support.SuppressCrashReport():
            out = assert_python_failure(
                '-c', code,
                PYTHONMALLOC=self.PYTHONMALLOC,
                # FreeBSD: instruct jemalloc to not fill freed() memory
                # with junk byte 0x5a, see JEMALLOC(3)
                MALLOC_CONF="junk:false",
            )
        stderr = out.err
        return stderr.decode('ascii', 'replace')

    @unittest.skipIf(support.check_impl_detail(pypy=True),
        "PyMem debugging not implemented on PyPy")
    def test_buffer_overflow(self):
        out = self.check('import _testcapi; _testcapi.pymem_buffer_overflow()')
        regex = (r"Debug memory block at address p={ptr}: API 'm'\n"
                 r"    16 bytes originally requested\n"
                 r"    The [0-9] pad bytes at p-[0-9] are FORBIDDENBYTE, as expected.\n"
                 r"    The [0-9] pad bytes at tail={ptr} are not all FORBIDDENBYTE \(0x[0-9a-f]{{2}}\):\n"
                 r"        at tail\+0: 0x78 \*\*\* OUCH\n"
                 r"        at tail\+1: 0xfd\n"
                 r"        at tail\+2: 0xfd\n"
                 r"        .*\n"
                 r"(    The block was made by call #[0-9]+ to debug malloc/realloc.\n)?"
                 r"    Data at p: cd cd cd .*\n"
                 r"\n"
                 r"Enable tracemalloc to get the memory block allocation traceback\n"
                 r"\n"
                 r"Fatal Python error: _PyMem_DebugRawFree: bad trailing pad byte")
        regex = regex.format(ptr=self.PTR_REGEX)
        regex = re.compile(regex, flags=re.DOTALL)
        self.assertRegex(out, regex)

    @unittest.skipIf(support.check_impl_detail(pypy=True),
        "PyMem debugging not implemented on PyPy")
    def test_api_misuse(self):
        out = self.check('import _testcapi; _testcapi.pymem_api_misuse()')
        regex = (r"Debug memory block at address p={ptr}: API 'm'\n"
                 r"    16 bytes originally requested\n"
                 r"    The [0-9] pad bytes at p-[0-9] are FORBIDDENBYTE, as expected.\n"
                 r"    The [0-9] pad bytes at tail={ptr} are FORBIDDENBYTE, as expected.\n"
                 r"(    The block was made by call #[0-9]+ to debug malloc/realloc.\n)?"
                 r"    Data at p: cd cd cd .*\n"
                 r"\n"
                 r"Enable tracemalloc to get the memory block allocation traceback\n"
                 r"\n"
                 r"Fatal Python error: _PyMem_DebugRawFree: bad ID: Allocated using API 'm', verified using API 'r'\n")
        regex = regex.format(ptr=self.PTR_REGEX)
        self.assertRegex(out, regex)

    def check_malloc_without_gil(self, code):
        out = self.check(code)
        expected = ('Fatal Python error: _PyMem_DebugMalloc: '
                    'Python memory allocator called without holding the GIL')
        self.assertIn(expected, out)

    @support.cpython_only
    def test_pymem_malloc_without_gil(self):
        # Debug hooks must raise an error if PyMem_Malloc() is called
        # without holding the GIL
        code = 'import _testcapi; _testcapi.pymem_malloc_without_gil()'
        self.check_malloc_without_gil(code)

    @support.cpython_only
    def test_pyobject_malloc_without_gil(self):
        # Debug hooks must raise an error if PyObject_Malloc() is called
        # without holding the GIL
        code = 'import _testcapi; _testcapi.pyobject_malloc_without_gil()'
        self.check_malloc_without_gil(code)

    def check_pyobject_is_freed(self, func_name):
        code = textwrap.dedent(f'''
            import gc, os, sys, _testcapi
            # Disable the GC to avoid crash on GC collection
            gc.disable()
            try:
                _testcapi.{func_name}()
                # Exit immediately to avoid a crash while deallocating
                # the invalid object
                os._exit(0)
            except _testcapi.error:
                os._exit(1)
        ''')
        assert_python_ok(
            '-c', code,
            PYTHONMALLOC=self.PYTHONMALLOC,
            MALLOC_CONF="junk:false",
        )

    @support.cpython_only
    def test_pyobject_null_is_freed(self):
        self.check_pyobject_is_freed('check_pyobject_null_is_freed')

    @support.cpython_only
    def test_pyobject_uninitialized_is_freed(self):
        self.check_pyobject_is_freed('check_pyobject_uninitialized_is_freed')

    @support.cpython_only
    def test_pyobject_forbidden_bytes_is_freed(self):
        self.check_pyobject_is_freed('check_pyobject_forbidden_bytes_is_freed')

    @support.cpython_only
    def test_pyobject_freed_is_freed(self):
        self.check_pyobject_is_freed('check_pyobject_freed_is_freed')


class PyMemMallocDebugTests(PyMemDebugTests):
    PYTHONMALLOC = 'malloc_debug'


@unittest.skipUnless(support.with_pymalloc(), 'need pymalloc')
class PyMemPymallocDebugTests(PyMemDebugTests):
    PYTHONMALLOC = 'pymalloc_debug'


@unittest.skipUnless(Py_DEBUG, 'need Py_DEBUG')
class PyMemDefaultTests(PyMemDebugTests):
    # test default allocator of Python compiled in debug mode
    PYTHONMALLOC = ''


class Test_ModuleStateAccess(unittest.TestCase):
    """Test access to module start (PEP 573)"""

    # The C part of the tests lives in _testmultiphase, in a module called
    # _testmultiphase_meth_state_access.
    # This module has multi-phase initialization, unlike _testcapi.

    def setUp(self):
        fullname = '_testmultiphase_meth_state_access'  # XXX
        origin = importlib.util.find_spec('_testmultiphase').origin
        loader = importlib.machinery.ExtensionFileLoader(fullname, origin)
        spec = importlib.util.spec_from_loader(fullname, loader)
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        self.module = module

    def test_subclass_get_module(self):
        """PyType_GetModule for defining_class"""
        class StateAccessType_Subclass(self.module.StateAccessType):
            pass

        instance = StateAccessType_Subclass()
        self.assertIs(instance.get_defining_module(), self.module)

    def test_subclass_get_module_with_super(self):
        class StateAccessType_Subclass(self.module.StateAccessType):
            def get_defining_module(self):
                return super().get_defining_module()

        instance = StateAccessType_Subclass()
        self.assertIs(instance.get_defining_module(), self.module)

    def test_state_access(self):
        """Checks methods defined with and without argument clinic

        This tests a no-arg method (get_count) and a method with
        both a positional and keyword argument.
        """

        a = self.module.StateAccessType()
        b = self.module.StateAccessType()

        methods = {
            'clinic': a.increment_count_clinic,
            'noclinic': a.increment_count_noclinic,
        }

        for name, increment_count in methods.items():
            with self.subTest(name):
                self.assertEqual(a.get_count(), b.get_count())
                self.assertEqual(a.get_count(), 0)

                increment_count()
                self.assertEqual(a.get_count(), b.get_count())
                self.assertEqual(a.get_count(), 1)

                increment_count(3)
                self.assertEqual(a.get_count(), b.get_count())
                self.assertEqual(a.get_count(), 4)

                increment_count(-2, twice=True)
                self.assertEqual(a.get_count(), b.get_count())
                self.assertEqual(a.get_count(), 0)

                with self.assertRaises(TypeError):
                    increment_count(thrice=3)

                with self.assertRaises(TypeError):
                    increment_count(1, 2, 3)


if __name__ == "__main__":
    unittest.main()
