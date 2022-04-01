
from rpython.rlib.streamio import open_file_as_stream

def target(*args):
    return main, None

def main(args):
    search = args[1]
    fname = args[2]
    s = open_file_as_stream(fname, 'r', 1024)
    while True:
        next_line = s.readline()
        if not next_line:
            break
        if search in next_line:
            print next_line
    return 0

def cpy_main(args):
    s = args[1]
    f = open(args[2])
    while True:
        x = f.readline()
        if not x:
            break
        if s in x:
            print x

if __name__ == '__main__':
    import sys
    main(sys.argv)
