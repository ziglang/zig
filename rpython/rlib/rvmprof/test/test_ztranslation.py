import time, os, sys
if __name__ == '__main__':
    sys.path += ['../../../..']    # for subprocess in test_interpreted
import py
from rpython.tool.udir import udir
from rpython.rlib import rvmprof, rthread
from rpython.translator.c.test.test_genc import compile
from rpython.rlib.nonconst import NonConstant

class MyCode:
    def __init__(self, count):
        self.count = count
        rvmprof.register_code(self, MyCode.get_name)

    def get_name(self):
        return 'test:mycode%d:%d:test_ztranslation' % (self.count, self.count)


def setup_module(mod):
    try:
        rvmprof.register_code_object_class(MyCode, MyCode.get_name)
    except rvmprof.VMProfPlatformUnsupported as e:
        py.test.skip(str(e))


@rvmprof.vmprof_execute_code("interp", lambda code: code)
def interpret(code):
    n = code.count
    while n > 0:
        n = one_less(n)
    return 42

def one_less(n):
    return n - 1
one_less._dont_inline_ = True


PROF_FILE = str(udir.join('test_ztranslation.prof'))

def main(argv=[]):
    rthread.get_ident() # force TLOFS_thread_ident
    if NonConstant(False):
        # Hack to give os.open() the correct annotation
        os.open('foo', 1, 1)
    code1 = MyCode(6500)
    fd = os.open(PROF_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0666)
    rvmprof.enable(fd, 0.01)
    #
    code2 = MyCode(9100)
    stop = time.time() + 1
    while time.time() < stop:
        interpret(code1)
        interpret(code2)
    #
    rvmprof.disable()
    os.close(fd)
    return 0

# ____________________________________________________________

def target(driver, args):
    return main

def test_interpreted():
    # takes forever if the Python process is already big...
    import subprocess
    me = os.path.basename(__file__)
    if me.endswith('pyc') or me.endswith('pyo'):
        me = me[:-1]
    env = os.environ.copy()
    env['PYTHONPATH'] = ''
    subprocess.check_call([sys.executable, me],
                          cwd=(os.path.dirname(__file__) or '.'),
                          env=env)

def test_compiled():
    fn = compile(main, [], gcpolicy="minimark")
    if os.path.exists(PROF_FILE):
        os.unlink(PROF_FILE)
    fn()
    assert os.path.exists(PROF_FILE)

if __name__ == '__main__':
    setup_module(None)
    res = main()
    assert res == 0
