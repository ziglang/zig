"""Run a subprocess.  Wrapper around the 'subprocess' module
with a hack to prevent bogus out-of-memory conditions in os.fork()
if the current process already grew very large.
"""

import sys
import gc
import os
from subprocess import PIPE, Popen

PY2 = (sys.version_info.major == 2)
if PY2:
    text = unicode
else:
    text = str

def run_subprocess(executable, args, env=None, cwd=None):
    if isinstance(args, list) and sys.platform != 'win32':
        args = [a.encode('latin1') if isinstance(a, text) else a
                for a in args]
    return _run(executable, args, env, cwd)

shell_default = False
if sys.platform == 'win32':
    shell_default = True

def _run(executable, args, env, cwd):
    # note that this function can be *overridden* below
    # in some cases!
    if sys.platform == 'win32':
        executable = executable.replace('/','\\')
    if isinstance(args, str):
        args = str(executable) + ' ' + args
        shell = True
    else:
        if args is None:
            args = [str(executable)]
        else:
            args = [str(executable)] + args
        # shell=True on unix-like is a known security vulnerability, but
        # on windows shell=True does not properly propogate the env dict
        shell = shell_default

    # Just before spawning the subprocess, do a gc.collect().  This
    # should help if we are running on top of PyPy, if the subprocess
    # is going to need a lot of RAM and we are using a lot too.
    gc.collect()

    pipe = Popen(args, stdout=PIPE, stderr=PIPE, shell=shell, env=env, cwd=cwd)
    stdout, stderr = pipe.communicate()
    if (sys.platform == 'win32' and pipe.returncode == 1 and 
        b'is not recognized' in stderr):
        # Setting shell=True on windows messes up expected exceptions
        raise EnvironmentError(stderr)
    return pipe.returncode, stdout, stderr


if __name__ == '__main__':
    while True:
        gc.collect()
        operation = sys.stdin.readline()
        if not operation:
            sys.exit()
        assert operation.startswith('(')
        args = eval(operation)
        try:
            results = _run(*args)
        except EnvironmentError as e:
            results = (None, str(e))
        sys.stdout.write('%r\n' % (results,))
        sys.stdout.flush()


if sys.platform != 'win32' and hasattr(os, 'fork') and not os.getenv("PYPY_DONT_RUN_SUBPROCESS", None):
    # do this at import-time, when the process is still tiny
    _source = os.path.dirname(os.path.abspath(__file__))
    _source = os.path.join(_source, 'runsubprocess.py')   # and not e.g. '.pyc'

    def spawn_subprocess():
        global _child, child_stdin, child_stdout
        _child = Popen([sys.executable, _source], bufsize=0,
                       stdin=PIPE, stdout=PIPE, close_fds=True)
        if PY2:
            child_stdin = _child.stdin
            child_stdout = _child.stdout
        else:
            # create TextIOWrappers which (hopefully) have the same newline
            # behavior as the child's stdin / stdout
            from io import TextIOWrapper
            child_stdin = TextIOWrapper(_child.stdin,
                                        newline=sys.stdin.newlines,
                                        write_through=True)
            child_stdout = TextIOWrapper(_child.stdout,
                                         newline=sys.stdout.newlines)
    spawn_subprocess()

    def cleanup_subprocess():
        global _child, child_stdin, child_stdout
        _child = None
        child_stdin = None
        child_stdout = None
    import atexit; atexit.register(cleanup_subprocess)

    def _run(*args):
        try:
            child_stdin.write('%r\n' % (args,))
        except (OSError, IOError):
            # lost the child.  Try again...
            spawn_subprocess()
            child_stdin.write('%r\n' % (args,))
        results = child_stdout.readline()
        assert results.startswith('(')
        results = eval(results)
        if results[0] is None:
            raise OSError('%s: %s\nargs=%r' % (args[0], results[1], args))
        return results
