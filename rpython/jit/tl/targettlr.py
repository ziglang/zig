import py
py.path.local(__file__)
from rpython.jit.tl.tlr import interpret
from rpython.jit.backend.hlinfo import highleveljitinfo


def entry_point(args):
    """Main entry point of the stand-alone executable:
    takes a list of strings and returns the exit code.
    """
    # store args[0] in a place where the JIT log can find it (used by
    # viewcode.py to know the executable whose symbols it should display)
    highleveljitinfo.sys_executable = args[0]
    if len(args) < 3:
        print "Usage: %s filename x" % (args[0],)
        return 2
    filename = args[1]
    x = int(args[2])
    bytecode = load_bytecode(filename)
    res = interpret(bytecode, x)
    print res
    return 0

def load_bytecode(filename):
    from rpython.rlib.streamio import open_file_as_stream
    f = open_file_as_stream(filename)
    bytecode = f.readall()
    f.close()
    return bytecode

def target(driver, args):
    return entry_point

# ____________________________________________________________

if __name__ == '__main__':
    import sys
    sys.exit(entry_point(sys.argv))
