
from rpython.jit.tl.tinyframe.tinyframe import main
from rpython.jit.codewriter.policy import JitPolicy

def jitpolicy(driver):
    return JitPolicy()

def entry_point(argv):
    main(argv[1], argv[2:])
    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None
