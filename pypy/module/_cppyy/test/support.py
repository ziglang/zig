import py, sys, subprocess

currpath = py.path.local(__file__).dirpath()


def setup_make(targetname):
    if sys.platform == 'win32':
        popen = subprocess.Popen([sys.executable, "make_dict_win32.py", targetname], cwd=str(currpath),
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    else:
        popen = subprocess.Popen(["make", targetname+"Dict.so"], cwd=str(currpath),
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    stdout, _ = popen.communicate()
    if popen.returncode:
        raise OSError("'make' failed:\n%s" % (stdout,))

if sys.hexversion >= 0x3000000:
    maxvalue = sys.maxsize
else:
    maxvalue = sys.maxint

IS_WINDOWS = 0
if 'win32' in sys.platform:
    soext = '.dll'
    import platform
    if '64' in platform.architecture()[0]:
        IS_WINDOWS = 64
        maxvalue = 2**31-1
    else:
        IS_WINDOWS = 32
else:
    soext = '.so'
