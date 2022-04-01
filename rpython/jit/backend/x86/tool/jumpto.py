"""Find where there are jumps to a given target.
Syntax:
    python jumpto.py  file.log  b0123456
"""
import sys, struct
from viewcode import World


def find_target(coderange, target):
    addr = coderange.addr
    data = coderange.data
    for i in range(len(data)-3):
        jtarg = addr + (struct.unpack("i", data[i:i+4])[0] + i + 4)
        if not ((jtarg - target) & 0xFFFFFFFFL):
            print hex(addr + i + 4)


if __name__ == '__main__':
    target = int(sys.argv[2], 16)
    f = open(sys.argv[1], 'r')
    world = World()
    world.parse(f, textonly=True)
    for coderange in world.ranges:
        find_target(coderange, target)
