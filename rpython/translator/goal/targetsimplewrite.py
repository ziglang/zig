import os

def main(iterations=1):
    dest = os.open('/dev/null', os.O_RDWR, 0777)
    payload = 'x' * 1024

    for x in xrange(1024 * 1024 * iterations):
        os.write(dest, payload)

    os.close(dest)
    
def entry_point(argv):
    if len(argv) > 1:
        n = int(argv[1])
    else:
        n = 1
    main(n)
    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None

if __name__ == '__main__':
    import sys
    if len(sys.argv) >= 2:
        main(iterations = int(sys.argv[1]))
    else:
        main()
