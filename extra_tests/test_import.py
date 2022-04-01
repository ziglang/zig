import pytest
import sys
import time
from _thread import start_new_thread

@pytest.mark.xfail('__pypy__' not in sys.builtin_module_names,
                   reason='Fails on CPython')
def test_multithreaded_import(tmpdir):
    tmpfile = tmpdir.join('multithreaded_import_test.py')
    tmpfile.write('''if 1:
        x = 666
        import time
        for i in range(1000): time.sleep(0.001)
        x = 42
    ''')

    oldpath = sys.path[:]
    try:
        sys.path.insert(0, str(tmpdir))
        got = []

        def check():
            import multithreaded_import_test
            got.append(getattr(multithreaded_import_test, 'x', '?'))

        for i in range(5):
            start_new_thread(check, ())

        for n in range(100):
            for i in range(105):
                time.sleep(0.001)
            if len(got) == 5:
                break
        else:
            raise AssertionError("got %r so far but still waiting" %
                                    (got,))

        assert got == [42] * 5

    finally:
        sys.path[:] = oldpath
