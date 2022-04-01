import os
#from rpython.translator.goal import richards

modfilename = os.path.join(os.path.dirname(__file__), 'richards.py')


# Number of times richards is imported in parallel.
# Can be changed on the command line, e.g.
#
#     translate.py targetvarsized.py 20
#
DEFAULT_CODE_SIZE_FACTOR   = 10
take_options = True


# __________  Entry point  __________

def richards_main(fn, iterations):
    s = "Richards benchmark (RPython) starting...\n"
    os.write(1, s)
    result, startTime, endTime = fn(iterations)
    if not result:
        os.write(2, "Incorrect results!\n")
        return False
    os.write(1, "finished.\n")
    total_s = endTime - startTime
    avg = total_s * 1000 / iterations
    os.write(1, "Total time for %d iterations: %f secs\n" %(iterations, total_s))
    os.write(1, "Average time per iteration: %f ms\n" %(avg))
    return True


def entry_point(argv):
    for fn in functions:
        if not richards_main(fn, 10):
            return 1
    return 0

# _____ Define and setup target ___

def target(driver, args, config):
    global modules, functions
    if len(args) == 0:
        N = DEFAULT_CODE_SIZE_FACTOR
    elif len(args) == 1:
        N = int(args[0])
    else:
        raise ValueError("too many command-line arguments")

    modules = []
    functions = []
    f = open(modfilename)
    source = f.read()
    f.close()
    for i in range(N):
        d = {'__name__': 'richards%d' % i}
        exec(source, d)
        modules.append(d)
        functions.append(d['entry_point'])

    return entry_point, None
