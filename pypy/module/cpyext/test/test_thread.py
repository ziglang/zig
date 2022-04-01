import sys

import pytest

from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase

only_pypy ="config.option.runappdirect and '__pypy__' not in sys.builtin_module_names"

class AppTestThread(AppTestCpythonExtensionBase):
    @pytest.mark.skipif(only_pypy, reason='pypy only test')
    @pytest.mark.xfail(reason='segfaults', run=False)
    def test_get_thread_ident(self):
        module = self.import_extension('foo', [
            ("get_thread_ident", "METH_NOARGS",
             """
#ifndef PyThread_get_thread_ident
#error "seems we are not accessing PyPy's functions"
#endif
                 return PyLong_FromLong(PyThread_get_thread_ident());
             """),
            ])
        import threading
        results = []
        def some_thread():
            res = module.get_thread_ident()
            results.append((res, threading.get_ident()))

        some_thread()
        assert results[0][0] == results[0][1]

        th = threading.Thread(target=some_thread, args=())
        th.start()
        th.join()
        assert results[1][0] == results[1][1]

        assert results[0][0] != results[1][0]

    @pytest.mark.skipif(only_pypy, reason='pypy only test')
    def test_acquire_lock(self):
        module = self.import_extension('foo', [
            ("test_acquire_lock", "METH_NOARGS",
             """
#ifndef PyThread_allocate_lock
#error "seems we are not accessing PyPy's functions"
#endif
                 PyThread_type_lock lock = PyThread_allocate_lock();
                 if (PyThread_acquire_lock(lock, 1) != 1) {
                     PyErr_SetString(PyExc_AssertionError, "first acquire");
                     return NULL;
                 }
                 if (PyThread_acquire_lock(lock, 0) != 0) {
                     PyErr_SetString(PyExc_AssertionError, "second acquire");
                     return NULL;
                 }
                 PyThread_free_lock(lock);

                 Py_RETURN_NONE;
             """),
            ])
        module.test_acquire_lock()

    @pytest.mark.skipif(only_pypy, reason='pypy only test')
    def test_release_lock(self):
        module = self.import_extension('foo', [
            ("test_release_lock", "METH_NOARGS",
             """
#ifndef PyThread_release_lock
#error "seems we are not accessing PyPy's functions"
#endif
                 PyThread_type_lock lock = PyThread_allocate_lock();
                 PyThread_acquire_lock(lock, 1);
                 PyThread_release_lock(lock);
                 if (PyThread_acquire_lock(lock, 0) != 1) {
                     PyErr_SetString(PyExc_AssertionError, "first acquire");
                     return NULL;
                 }
                 PyThread_free_lock(lock);

                 Py_RETURN_NONE;
             """),
            ])
        module.test_release_lock()

    @pytest.mark.skipif(only_pypy, reason='pypy only test')
    @pytest.mark.xfail(reason='segfaults', run=False)
    def test_tls(self):
        module = self.import_extension('foo', [
            ("create_key", "METH_NOARGS",
             """
                 return PyLong_FromLong(PyThread_create_key());
             """),
            ("test_key", "METH_O",
             """
                 int key = PyLong_AsLong(args);
                 if (PyThread_get_key_value(key) != NULL) {
                     PyErr_SetNone(PyExc_ValueError);
                     return NULL;
                 }
                 if (PyThread_set_key_value(key, (void*)123) < 0) {
                     PyErr_SetNone(PyExc_ValueError);
                     return NULL;
                 }
                 if (PyThread_get_key_value(key) != (void*)123) {
                     PyErr_SetNone(PyExc_ValueError);
                     return NULL;
                 }
                 Py_RETURN_NONE;
             """),
            ])
        key = module.create_key()
        assert key > 0
        # Test value in main thread.
        module.test_key(key)
        raises(ValueError, module.test_key, key)
        # Same test, in another thread.
        result = []
        import _thread, time
        def in_thread():
            try:
                module.test_key(key)
                raises(ValueError, module.test_key, key)
            except Exception as e:
                result.append(e)
            else:
                result.append(True)
        _thread.start_new_thread(in_thread, ())
        while not result:
            print(".")
            time.sleep(.5)
        assert result == [True]

    def test_tss(self):
        module = self.import_extension('foo', [
            ("tss", "METH_NOARGS",
             """
                void *tss_key = NULL;
                /* non-Py_LIMITED_API */
                Py_tss_t _tss_key = Py_tss_NEEDS_INIT;
                int the_value = 1;
                if ( PyThread_tss_is_created(&_tss_key) ) {
                     PyErr_SetString(PyExc_AssertionError,
                         "tss_is_created should not succeed yet");
                     return NULL;
                }
                /* This should be a no-op */
                PyThread_tss_delete(&_tss_key);
                /* Py_LIMITED_API */
                tss_key = PyThread_tss_alloc();
                if ( PyThread_tss_is_created(tss_key) ) {
                     PyErr_SetString(PyExc_AssertionError,
                         "tss_is_created should not succeed yet");
                     return NULL;
                }
                if (PyThread_tss_create(tss_key)) {
                    return NULL;
                }
                if (! PyThread_tss_is_created(tss_key)) {
                    return NULL;
                }
                /* Be sure additional calls succeed */
                if (PyThread_tss_create(tss_key)) {
                    return NULL;
                }
                if (PyThread_tss_get(tss_key) != NULL) {
                     PyErr_SetString(PyExc_AssertionError,
                         "tss_get should not succeed yet");
                    return NULL;
                }
                
                if (PyThread_tss_set(tss_key, (void *)&the_value)) {
                     PyErr_SetString(PyExc_AssertionError,
                         "tss_set failed");
                    return NULL;
                }
                void *val = PyThread_tss_get(tss_key);
                if (val == NULL) {
                     PyErr_SetString(PyExc_AssertionError,
                         "tss_get failed");
                    return NULL;
                }
                if (the_value != *(int*)val) {
                     PyErr_SetString(PyExc_AssertionError,
                         "retrieved value is wrong");
                    return NULL;
                }
                PyThread_tss_free(tss_key);
                Py_RETURN_NONE;
             """),
            ])
        module.tss()
