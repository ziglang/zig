
""" some simple benchmarikng stuff
"""

import random, time

def sample(population, num):
    l = len(population)
    retval = []
    for i in xrange(num):
        retval.append(population[random.randrange(l)])
    return retval

random.sample = sample

def get_random_string(l):
    strings = 'qwertyuiopasdfghjklzxcvbm,./;QWERTYUIOPASDFGHJKLZXCVBNM!@#$%^&*()_+1234567890-='
    return str(random.sample(strings, l))

def count_operation(name, function):
    print name
    t0 = time.time()
    retval = function()
    tk = time.time()
    print name, " takes: %f" % (tk - t0)
    return retval

def bench_simple_dict(SIZE = 10000):
    keys = [get_random_string(20) for i in xrange(SIZE)]
    values = [random.random() for i in xrange(SIZE)]

    lookup_keys = random.sample(keys, 1000)
    random_keys = [get_random_string(20) for i in xrange(1000)]
    
    test_d = count_operation("Creation", lambda : dict(zip(keys, values)))

    def rand_keys(keys):
        for key in keys:
            try:
                test_d[key]
            except KeyError:
                pass
    
    count_operation("Random key access", lambda : rand_keys(random_keys))
    count_operation("Existing key access", lambda : rand_keys(lookup_keys))
    return test_d

if __name__ == '__main__':
    test_d = bench_simple_dict()
    import __pypy__
    print __pypy__.internal_repr(test_d)
    print __pypy__.internal_repr(test_d.iterkeys())
