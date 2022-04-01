#! /usr/bin/env python

import sys
from time import time
from rpython.rlib.rbigint import rbigint

# __________  Entry point  __________

def entry_point(argv):
    """
        All benchmarks are run using --opt=2 and minimark gc (default).
        
        Benchmark changes:
        2**N is a VERY heavy operation in default pypy, default to 10 million instead of 500,000 used like an hour to finish.
        
        A cutout with some benchmarks.
        Pypy default:
        mod by 2:  7.978181
        mod by 10000:  4.016121
        mod by 1024 (power of two):  3.966439
        Div huge number by 2**128: 2.906821
        rshift: 2.444589
        lshift: 2.500746
        Floordiv by 2: 4.431134
        Floordiv by 3 (not power of two): 4.404396
        2**500000: 23.206724
        (2**N)**5000000 (power of two): 13.886118
        10000 ** BIGNUM % 100 8.464378
        i = i * i: 10.121505
        n**10000 (not power of two): 16.296989
        Power of two ** power of two: 2.224125
        v = v * power of two 12.228391
        v = v * v 17.119933
        v = v + v 6.489957
        Sum:  142.686547
        
        Pypy with improvements:
        mod by 2:  0.007059
        mod by 10000:  3.204295
        mod by 1024 (power of two):  0.009401
        Div huge number by 2**128: 1.368511
        rshift: 2.345295
        lshift: 1.339761
        Floordiv by 2: 1.532028
        Floordiv by 3 (not power of two): 4.005607
        2**500000: 0.033466
        (2**N)**5000000 (power of two): 0.047093
        10000 ** BIGNUM % 100 1.207310
        i = i * i: 3.998161
        n**10000 (not power of two): 6.323250
        Power of two ** power of two: 0.013258
        v = v * power of two 3.567459
        v = v * v 6.316683
        v = v + v 2.757308
        Sum:  38.075946

        # Notice: This is slightly old!
        With SUPPORT_INT128 set to False
        mod by 2:  0.004103
        mod by 10000:  3.237434
        mod by 1024 (power of two):  0.016363
        Div huge number by 2**128: 2.836237
        rshift: 2.343860
        lshift: 1.172665
        Floordiv by 2: 1.537474
        Floordiv by 3 (not power of two): 3.796015
        2**500000: 0.327269
        (2**N)**5000000 (power of two): 0.084709
        10000 ** BIGNUM % 100 2.063215
        i = i * i: 8.109634
        n**10000 (not power of two): 11.243292
        Power of two ** power of two: 0.072559
        v = v * power of two 9.753532
        v = v * v 13.569841
        v = v + v 5.760466
        Sum:  65.928667

    """
    sumTime = 0.0

    V2 = rbigint.fromint(2)
    num = rbigint.pow(rbigint.fromint(100000000), rbigint.fromint(1024))
    t = time()
    for n in xrange(600000):
        rbigint.mod(num, V2)
        
    _time = time() - t
    sumTime += _time
    print "mod by 2: ", _time
    
    by = rbigint.fromint(10000)
    t = time()
    for n in xrange(300000):
        rbigint.mod(num, by)
        
    _time = time() - t
    sumTime += _time
    print "mod by 10000: ", _time
    
    V1024 = rbigint.fromint(1024)
    t = time()
    for n in xrange(300000):
        rbigint.mod(num, V1024)
        
    _time = time() - t
    sumTime += _time
    print "mod by 1024 (power of two): ", _time
    
    t = time()
    num = rbigint.pow(rbigint.fromint(100000000), rbigint.fromint(1024))
    by = rbigint.pow(rbigint.fromint(2), rbigint.fromint(128))
    for n in xrange(80000):
        rbigint.divmod(num, by)
        

    _time = time() - t
    sumTime += _time
    print "Div huge number by 2**128:", _time
    
    t = time()
    num = rbigint.fromint(1000000000)
    for n in xrange(160000000):
        rbigint.rshift(num, 16)
        

    _time = time() - t
    sumTime += _time
    print "rshift:", _time
    
    t = time()
    num = rbigint.fromint(1000000000)
    for n in xrange(160000000):
        rbigint.lshift(num, 4)
        

    _time = time() - t
    sumTime += _time
    print "lshift:", _time
    
    t = time()
    num = rbigint.fromint(100000000)
    for n in xrange(80000000):
        rbigint.floordiv(num, V2)
        

    _time = time() - t
    sumTime += _time
    print "Floordiv by 2:", _time
    
    t = time()
    num = rbigint.fromint(100000000)
    V3 = rbigint.fromint(3)
    for n in xrange(80000000):
        rbigint.floordiv(num, V3)
        

    _time = time() - t
    sumTime += _time
    print "Floordiv by 3 (not power of two):",_time
    
    t = time()
    num = rbigint.fromint(500000)
    for n in xrange(10000):
        rbigint.pow(V2, num)
        

    _time = time() - t
    sumTime += _time
    print "2**500000:",_time

    t = time()
    num = rbigint.fromint(5000000)
    for n in xrange(31):
        rbigint.pow(rbigint.pow(V2, rbigint.fromint(n)), num)
        

    _time = time() - t
    sumTime += _time
    print "(2**N)**5000000 (power of two):",_time
    
    t = time()
    num = rbigint.pow(rbigint.fromint(10000), rbigint.fromint(2 ** 8))
    P10_4 = rbigint.fromint(10**4)
    V100 = rbigint.fromint(100)
    for n in xrange(60000):
        rbigint.pow(P10_4, num, V100)
        

    _time = time() - t
    sumTime += _time
    print "10000 ** BIGNUM % 100", _time
    
    t = time()
    i = rbigint.fromint(2**31)
    i2 = rbigint.fromint(2**31)
    for n in xrange(75000):
        i = i.mul(i2)

    _time = time() - t
    sumTime += _time
    print "i = i * i:", _time
    
    t = time()
    
    for n in xrange(10000):
        rbigint.pow(rbigint.fromint(n), P10_4)
        

    _time = time() - t
    sumTime += _time
    print "n**10000 (not power of two):",_time
    
    t = time()
    for n in xrange(100000):
        rbigint.pow(V1024, V1024)
        

    _time = time() - t
    sumTime += _time
    print "Power of two ** power of two:", _time
    
    
    t = time()
    v = rbigint.fromint(2)
    P62 = rbigint.fromint(2**62)
    for n in xrange(50000):
        v = v.mul(P62)
        

    _time = time() - t
    sumTime += _time
    print "v = v * power of two", _time
    
    t = time()
    v2 = rbigint.fromint(2**8)
    for n in xrange(28):
        v2 = v2.mul(v2)
        

    _time = time() - t
    sumTime += _time
    print "v = v * v", _time
    
    t = time()
    v3 = rbigint.fromint(2**62)
    for n in xrange(500000):
        v3 = v3.add(v3)
        

    _time = time() - t
    sumTime += _time
    print "v = v + v", _time
    
    x = rbigint.fromstr("13579246801357924680135792468013579246801")
    y = rbigint.fromstr("112233445566778899112233445566778899112233445566778899")
    t = time()
    for i in range(5000):
        x.gcd(y)
        x = x.int_mul(2).int_add(1)
    _time = time() - t
    print "gcd", _time

    sumTime += _time

    print "Sum: ", sumTime

    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None

if __name__ == '__main__':
    res = entry_point(sys.argv)
    sys.exit(res)
