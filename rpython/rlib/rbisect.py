
def bisect_left(a, x, hi):
    """Return the index in the sorted list 'a' of 'x'.  If 'x' is not in 'a',
    return the index where it can be inserted."""
    lo = 0
    while lo < hi:
        mid = (lo+hi)//2
        if a[mid] < x: lo = mid+1
        else: hi = mid
    return lo

def bisect_right(a, x, hi):
    lo = 0
    while lo < hi:
        mid = (lo+hi)//2
        if x < a[mid]: hi = mid
        else: lo = mid+1
    return lo

# a copy of the above, but compares the item called 'addr' only
def bisect_left_addr(a, x, hi):
    lo = 0
    while lo < hi:
        mid = (lo+hi)//2
        if a[mid].addr < x: lo = mid+1
        else: hi = mid
    return lo

def bisect_right_addr(a, x, hi):
    lo = 0
    while lo < hi:
        mid = (lo+hi)//2
        if x < a[mid].addr: hi = mid
        else: lo = mid+1
    return lo
