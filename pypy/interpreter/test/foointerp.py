w_foo2 = space.wrap("hello")
foo2 = "never mind"   # should be hidden by w_foo2

def foobuilder(w_name):
    name = space.unwrap(w_name)
    return space.wrap("hi, %s!" % name)

from __applevel__ import bar
fortytwo = bar(space.wrap(6), space.wrap(7))
