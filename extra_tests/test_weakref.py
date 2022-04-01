import sys
import textwrap
import subprocess

def test_WeakValueDictionary_len(tmpdir):
    src = textwrap.dedent("""
        from weakref import WeakValueDictionary
        class Foo:
            pass
        N = 1000
        D = WeakValueDictionary()
        for i in range(N):
            D[i] = Foo()

        for i in range(10):
            x = len(D)
        print('OK')
    """)
    testfile = tmpdir.join('testfile.py')
    testfile.write(src)
    #
    # by setting a very small PYPY_GC_NURSERY value, we force running a minor
    # collection inside WeakValueDictionary.__len__. We just check that the
    # snippet above completes correctly, instead of raising "dictionary
    # changed size during iteration"
    env = {'PYPY_GC_NURSERY': '1k'}
    subprocess.run([sys.executable, str(testfile)], env=env, check=True)


def test_WeakKeyDictionary_len(tmpdir):
    src = textwrap.dedent("""
        from weakref import WeakKeyDictionary
        class Foo:
            pass
        N = 1000
        D = WeakKeyDictionary()
        for i in range(N):
            D[Foo()] = i

        for i in range(10):
            x = len(D)
        print('OK')
    """)
    testfile = tmpdir.join('testfile.py')
    testfile.write(src)
    #
    # by setting a very small PYPY_GC_NURSERY value, we force running a minor
    # collection inside WeakValueDictionary.__len__. We just check that the
    # snippet above completes correctly, instead of raising "dictionary
    # changed size during iteration"
    env = {'PYPY_GC_NURSERY': '1k'}
    subprocess.run([sys.executable, str(testfile)], env=env, check=True)
