import os, sys, py, subprocess

localdir = os.path.dirname(os.path.abspath(__file__))


def test_bug1():
    if not sys.platform.startswith('linux'):
        py.test.skip("linux-only test")
    if '__pypy__' not in sys.builtin_module_names:
        try:
            import cffi
        except ImportError as e:
            py.test.skip(str(e))

    cmdline = ['taskset', '-c', '0',
               sys.executable, os.path.join(localdir, 'bug1.py')]
    popen = subprocess.Popen(cmdline, stderr=subprocess.PIPE)
    errmsg = popen.stderr.read()
    err = popen.wait()
    assert err == 0, "err = %r, errmsg:\n%s" % (err, errmsg)
