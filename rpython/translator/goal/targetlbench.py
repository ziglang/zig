
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.llmemory import cast_ptr_to_adr, raw_memclear,\
     raw_memcopy, sizeof, itemoffsetof

TP = lltype.GcArray(lltype.Signed)

def longername(a, b, size):
    if 1:
        baseofs = itemoffsetof(TP, 0)
        onesize = sizeof(TP.OF)
        size = baseofs + onesize*(size - 1)
        raw_memcopy(cast_ptr_to_adr(b)+baseofs, cast_ptr_to_adr(a)+baseofs, size)
    else:
        a = []
        for i in range(x):
            a.append(i)
    return 0
longername._dont_inline_ = True

def entry_point(argv):
    size = int(argv[1])
    a = lltype.malloc(TP, size)
    b = lltype.malloc(TP, size, zero=False)
    for i in range(size):
        a[i] = i
    print longername(a, b, size)
    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None

if __name__ == '__main__':
    import sys
    entry_point(sys.argv)
