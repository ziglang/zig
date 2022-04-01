from rpython.jit.tl import tiny2_hotpath as tiny2
from rpython.jit.backend.hlinfo import highleveljitinfo
from rpython.rlib.jit import set_user_param


def help(err="Invalid command line arguments."):
    print err
    print highleveljitinfo.sys_executable,
    print "[-j param=value,...]",
    print "'tiny2 program string' arg0 [arg1 [arg2 [...]]]"
    return 1

def entry_point(args):
    """Main entry point of the stand-alone executable:
    takes a list of strings and returns the exit code.
    """
    # store args[0] in a place where the JIT log can find it (used by
    # viewcode.py to know the executable whose symbols it should display)
    highleveljitinfo.sys_executable = args.pop(0)
    if len(args) < 1:
        return help()
    if args[0] == '-j':
        if len(args) < 3:
            return help()
        try:
            set_user_param(tiny2.tinyjitdriver, args[1])
        except ValueError:
            return help("Bad argument to -j.")
        args = args[2:]
    bytecode = [s for s in args[0].split(' ') if s != '']
    args = [tiny2.StrBox(arg) for arg in args[1:]]
    res = tiny2.interpret(bytecode, args)
    print tiny2.repr(res)
    return 0

def target(driver, args):
    return entry_point, None

