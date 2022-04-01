import os

def main(iterations=1):
    source = os.open('/dev/zero', os.O_RDWR, 0777)
    
    for x in xrange(1024 * 1024 * iterations):
        payload = os.read(source, 1024)

    os.close(source)
    
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
