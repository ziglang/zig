import sys
sys.setcheckinterval(1<<20)

from array import array
class Circular(array):
    def __new__(cls):
        self = array.__new__(cls, 'd', range(65536))
        return self
    def __getitem__(self, i):
        assert len(self) == 65536 
        return array.__getitem__(self, i & 65535)

import sys
def main():
    buf = Circular()
    i = 10
    sa = 0
    while i < 200000000:
        sa += buf[i-2] + buf[i-1] + buf[i] + buf[i+1] + buf[i+2]
        i += 1
    return sa

print main()
