import os, sys
from rpython.translator.test import rpystone
from rpython.translator.goal import richards

# __________  Entry point  __________

# note that we have %f but no length specifiers in RPython

def pystones_main(loops):
    benchtime, stones = rpystone.pystones(abs(loops))
    s = '' # annotator happiness
    if loops >= 0:
        s = ("RPystone time for %d passes = %f" %
             (loops, benchtime) + '\n' + (
             "This machine benchmarks at %f pystones/second\n" % stones))
    os.write(1, s)
    if loops == 12345:
        pystones_main(loops-1)

def richards_main(iterations):
    s = "Richards benchmark (RPython) starting...\n"
    os.write(1, s)
    result, startTime, endTime = richards.entry_point(iterations)
    if not result:
        os.write(2, "Incorrect results!\n")
        return
    os.write(1, "finished.\n")
    total_s = endTime - startTime
    avg = total_s * 1000 / iterations
    os.write(1, "Total time for %d iterations: %f secs\n" %(iterations, total_s))
    os.write(1, "Average time per iteration: %f ms\n" %(avg))

DEF_PYSTONE = 10000000
DEF_RICHARDS = 1000

def entry_point(argv):
    proc = pystones_main
    default = DEF_PYSTONE
    n = 0
    for s in argv[1:]:
        s = s.lower()
        if 'pystone'.startswith(s):
            proc = pystones_main
            default = DEF_PYSTONE
        elif 'richards'.startswith(s):
            proc = richards_main
            default = DEF_RICHARDS
        else:
            try:
                n = abs(int(s))
            except ValueError:
                os.write(2, '"%s" is neither a valid option (pystone, richards)'
                            ' nor an integer\n' % s)
                return 1
    if not n:
        n = default
    proc(n)
    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point

"""
Why is this a stand-alone target?

The above target specifies no argument types list.
This is a case treated specially in the driver.py . The only argument is meant
to be a list of strings, actually implementing argv of the executable.
"""
