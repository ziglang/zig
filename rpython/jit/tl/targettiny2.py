from rpython.annotator.policy import AnnotatorPolicy
from rpython.jit.tl import tiny2
from rpython.jit.backend.hlinfo import highleveljitinfo


def entry_point(args):
    """Main entry point of the stand-alone executable:
    takes a list of strings and returns the exit code.
    """
    # store args[0] in a place where the JIT log can find it (used by
    # viewcode.py to know the executable whose symbols it should display)
    highleveljitinfo.sys_executable = args[0]
    if len(args) < 2:
        print "Invalid command line arguments."
        print args[0] + " 'tiny2 program string' arg0 [arg1 [arg2 [...]]]"
        return 1
    bytecode = [s for s in args[1].split(' ') if s != '']
    args = [tiny2.StrBox(arg) for arg in args[2:]]
    res = tiny2.interpret(bytecode, args)
    print tiny2.repr(res)
    return 0

def target(driver, args):
    return entry_point, None
