from rpython.translator.goal import richards

entry_point = richards.entry_point

# _____ Define and setup target ___

def target(*args):
    return entry_point, [int]

def get_llinterp_args():
    return [1]

# _____ Run translated _____
def run(c_entry_point):
    print "Translated:"
    richards.main(c_entry_point, iterations=500)
    print "CPython:"
    richards.main(iterations=5)

    
