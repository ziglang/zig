import cffi, thread, time, sys


ffi = cffi.FFI()

ffi.cdef("""
    long foobar(long a, long b, long c, long d, long e, long f,
                long a2, long b2, long c2, long d2, long e2, long f2,
                long a3, long b3, long c3, long d3, long e3, long f3,
                long a4, long b4, long c4, long d4, long e4, long f4);
""")

lib = ffi.verify("""
    long foobar(long a, long b, long c, long d, long e, long f,
                long a2, long b2, long c2, long d2, long e2, long f2,
                long a3, long b3, long c3, long d3, long e3, long f3,
                long a4, long b4, long c4, long d4, long e4, long f4)
    {
        return a * 1 + b * 2 + c * 3 + d * 4 + e * 5 + f * 6 +
               (a2 * 1 + b2 * 2 + c2 * 3 + d2 * 4 + e2 * 5 + f2 * 6) * (-3) +
               (a3 * 1 + b3 * 2 + c3 * 3 + d3 * 4 + e3 * 5 + f3 * 6) * (-5) +
               (a4 * 1 + b4 * 2 + c4 * 3 + d4 * 4 + e4 * 5 + f4 * 6) * (-7);
    }
""")


def runme():
    for j in range(10):
        for i in range(10000):
            args = [i-k for k in range(24)]
            x = lib.foobar(*args)
            (a,b,c,d,e,f,a2,b2,c2,d2,e2,f2,
             a3,b3,c3,d3,e3,f3,a4,b4,c4,d4,e4,f4) = args
            assert x == (
                a * 1 + b * 2 + c * 3 + d * 4 + e * 5 + f * 6 +
                (a2 * 1 + b2 * 2 + c2 * 3 + d2 * 4 + e2 * 5 + f2 * 6) * (-3) +
                (a3 * 1 + b3 * 2 + c3 * 3 + d3 * 4 + e3 * 5 + f3 * 6) * (-5) +
                (a4 * 1 + b4 * 2 + c4 * 3 + d4 * 4 + e4 * 5 + f4 * 6) * (-7))

done = []

def submain():
    try:
        runme()
        err = None
    except:
        err = sys.exc_info()
    done.append(err)

for i in range(2):
    thread.start_new_thread(submain, ())
while len(done) < 2:
    time.sleep(0.1)

for err in done:
    if err is not None:
        raise err[0], err[1], err[2]
