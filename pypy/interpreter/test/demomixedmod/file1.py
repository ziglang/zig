
def somefunc(space): 
    return space.w_True 

def initpath(space): 
    print "got to initpath", space
    return space.wrap(3) 
