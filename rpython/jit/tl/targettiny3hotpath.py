from rpython.jit.tl import tiny3_hotpath as tiny3
from rpython.jit.backend.hlinfo import highleveljitinfo
from rpython.rlib.jit import set_user_param

def help(err="Invalid command line arguments."):
    print err
    print highleveljitinfo.sys_executable,
    print "[-j param=value,...]",
    print "'tiny3 program string' arg0 [arg1 [arg2 [...]]]"
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
            set_user_param(tiny3.tinyjitdriver, args[1])
        except ValueError:
            return help("Bad argument to -j.")
        args = args[2:]
    bytecode = [s for s in args[0].split(' ') if s != '']
    real_args = []
    for arg in args[1:]:
        try:
            real_args.append(tiny3.IntBox(int(arg)))
        except ValueError:
            real_args.append(tiny3.FloatBox(tiny3.myfloat(arg)))
    res = tiny3.interpret(bytecode, real_args)
    print tiny3.repr(res)
    return 0

def target(driver, args):
    return entry_point, None

if __name__ == '__main__':
    import sys
    entry_point(sys.argv)
