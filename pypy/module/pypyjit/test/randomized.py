#!/usr/bin/python

import random, inspect, os

class RandomCode(object):

    maxifdepth = 10
    maxopdepth = 20

    def __init__(self):
        self.vars = set()

    def sample(self, population):
        return random.sample(population, 1)[0]

    def chose(self, *args):
        return self.sample(args)()

    def expression(self):
        if len(self.vars) == 0:
            return self.constant()
        elif self.depth() > self.maxopdepth:
            return self.chose(self.variable, self.constant)
        else:
            return self.chose(self.variable, self.opperation, self.constant)
        
    def variable(self):
        return self.sample(self.vars)

    def opperation(self):
        return self.expression() + ' ' + self.sample(self.opperators) + \
               ' ' + self.expression()

    def test(self):
        tst = self.sample(self.tests)
        if tst:
            return self.expression() + ' ' + tst + \
                   ' ' + self.expression()
        else:
            return self.expression()

    def constant(self):
        return str(self.sample(self.constants))

    def depth(self):
        return len(inspect.getouterframes(inspect.currentframe()))
        
    def statement(self):
        if self.depth() > self.maxifdepth:
            return self.assignment()
        else:
            return self.chose(self.assignment, self.ifstatement)

    def assignment(self):
        v = self.sample(self.varnames)
        s = v + ' = ' + self.expression() + '\n'
        self.vars.add(v)
        return s

    def indent(self, s):
        lines = s.split('\n')
        lines = ['    ' + l for l in lines[:-1]]
        return '\n'.join(lines) + '\n'
    
    def ifstatement(self):
        return 'if ' + self.test() + ':\n' + self.indent(self.block(5))

    def block(self, n):
        s = ''
        for i in range(random.randrange(1,n)):
            s += self.statement()
        return s

    def whileloop(self):
        self.vars.add('i')
        return 'i = 0\nwhile i < 10:\n' + \
               self.indent(self.block(5) + 'i += 1\n')

    def setupvars(self):
        return ', '.join(self.vars) + ' = ' + \
               ', '.join('0' * len(self.vars)) + '\n'

    def return_statement(self):
        return 'return (' + ', '.join(self.vars) + ')\n'
        

class IntBounds(RandomCode):
    opperators = ('+', '-', '*', '/', '>>', '<<')
    tests = ('<', '>', '<=', '>=', '==', '!=', None)
    constants = range(-3,4) 
    varnames = 'abcd'

    def function(self, name='f'):
        body = self.block(3) + self.whileloop() + self.return_statement()
        body = self.setupvars() + body
        return 'def %s():\n' % name + self.indent(body)


def run(python, code):
    (s,r,e) = os.popen3(python)
    s.write(code)
    s.close()
    res = r.read()
    err = e.read()
    r.close()
    return res, err

fcnt = 0
while True:
    code = '''
try: # make the file runnable by CPython
    import pypyjit
    pypyjit.set_param(threshold=3)
except ImportError:
    pass

%s
print f()
''' % IntBounds().function('f')

    r1,e1 = run('/usr/bin/python', code)
    r2,e2 = run('../../../translator/goal/pypy-c', code)
    if r1 != r2:
        rapport = '******************** FAILED ******************\n' + \
                  code + "\n" + \
                  'cpython: %s %s\n' % (r1, e1) + \
                  'pypy: %s %s\n' % (r2, e2)
        fcnt += 1
        f = open('failures/%d' % fcnt, "w")
        f.write(rapport)
        f.close()
        print rapport
        

