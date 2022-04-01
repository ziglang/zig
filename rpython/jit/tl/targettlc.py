import time
import py
py.path.local(__file__)
from rpython.jit.tl.tlc import interp, interp_nonjit, ConstantPool
from rpython.jit.backend.hlinfo import highleveljitinfo


def entry_point(args):
    """Main entry point of the stand-alone executable:
    takes a list of strings and returns the exit code.
    """
    # store args[0] in a place where the JIT log can find it (used by
    # viewcode.py to know the executable whose symbols it should display)
    exe = args[0]
    args = args[1:]
    highleveljitinfo.sys_executable = exe
    if len(args) < 2:
        print "Usage: %s [--onlyjit] filename x" % (exe,)
        return 2

    onlyjit = False
    if args[0] == '--onlyjit':
        onlyjit = True
        args = args[1:]
        
    filename = args[0]
    x = int(args[1])
    bytecode, pool = load_bytecode(filename)

    if not onlyjit:
        start = time.clock()
        res = interp_nonjit(bytecode, inputarg=x, pool=pool)
        stop = time.clock()
        print 'Non jitted:    %d (%f seconds)' % (res, stop-start)

    start = time.clock()
    res = interp(bytecode, inputarg=x, pool=pool)
    stop = time.clock()
    print 'Warmup jitted: %d (%f seconds)' % (res, stop-start)

    start = time.clock()
    res = interp(bytecode, inputarg=x, pool=pool)
    stop = time.clock()
    print 'Warmed jitted: %d (%f seconds)' % (res, stop-start)

    return 0


def load_bytecode(filename):
    from rpython.rlib.streamio import open_file_as_stream
    from rpython.jit.tl.tlopcode import decode_program
    f = open_file_as_stream(filename)
    return decode_program(f.readall())

def target(driver, args):
    return entry_point

# ____________________________________________________________

if __name__ == '__main__':
    import sys
    sys.exit(entry_point(sys.argv))
