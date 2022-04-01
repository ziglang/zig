def getitem(list, index):
    return list[index]

def entry_point(i):
    return getitem([i, 2, 3, 4], 2) + getitem(None, i)

def target(*args):
    return entry_point, [int]

def get_llinterp_args():
    return [1]

# _____ Run translated _____
def run(c_entry_point):
    c_entry_point(0)
