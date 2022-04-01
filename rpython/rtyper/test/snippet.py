# generic

def simple1():
    return 1


def simple2():
    return False


def not1(n):
    return not n

    
def not2(n):
    t = not n
    if not n:
        t += 1
    return t


# bools

def bool1(n):
    if n:
        return 3
    return 5


def bool_cast1(n):
    n += bool(False)
    n += bool(True)
    n += bool(0)
    n += bool(1)
    n += bool(6)
    n += bool(7.8)
    n += bool(n)
    return n


#ints

def int1(n):
    i = 0
    
    i  += n<<3
    i <<= 3

    i  += n>>3
    i >>= 3

    i  += n%3
    i  %= n

    i  += n^3
    i  ^= n

    i  += n&3
    i  &= n

    i  += n^3
    i  ^= n

    i  += n|3
    i  |= n
    
    i  += ~n

    n += False
    n += True
    n += bool(False)
    n += bool(True)

    i += abs(i)
    i &= 255

    #i **= n
    #i += n**3

    i += -n
    i += +n
    i += not n

    if n < 12.5:
        n += 666

    while n:
        i = i + n
        n = n - 1
    return i


def int_cast1(n):
    n += int(False)
    n += int(True)
    n += int(0)
    n += int(1)
    n += int(8)
    n += int(5.7)
    n += int(n)
    return n


# floats

def float1(n):
    i = 0
    
    n += False
    n += True
    n += bool(False)
    n += bool(True)

    i += abs(i)
    i &= 255

    i += -n
    i += +n
    i += not n

    if n < 12.5:
        n += 666

    while n >= 0:
        i = i + n
        n = n - 1
    return i


def float_cast1(n):
    n += float(False)
    n += float(True)
    n += float(0)
    n += float(1)
    n += float(6)
    n += float(7.8)
    n += float(n)
    return n


def main(args=[]):
    b = True
    i = 23
    f = 45.6
    b1 = bool1(b)
    i1 = int1(i)
    f1 = float1(f)
    return 0


if __name__ == '__main__':
    main()
