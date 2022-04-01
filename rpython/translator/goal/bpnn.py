#!/usr/bin/env python
"""
    Translator Demo

    To analyse and type-annotate the functions and class defined in
    this module, starting from the entry point function demo(),
    use the following command line:

        ../pypy/translator/goal/translate.py bpnn.py

    Insert '--help' before 'bpnn.py' for a list of translation options,
    or see the Overview of Command Line Options for translation at
    http://codespeak.net/pypy/dist/pypy/doc/config/commandline.html
"""
# Back-Propagation Neural Networks
# 
# Written in Python.  See http://www.python.org/
#
# Neil Schemenauer <nascheme@enme.ucalgary.ca>
#
# Modifications to the original (Armin Rigo):
#   * import random from PyPy's lib, which is Python 2.2's plain
#     Python implementation
#   * print a doc about how to start the Translator

import sys
import math
import time

from rpython.rlib import rrandom

PRINT_IT = True

random = rrandom.Random(1)

# calculate a random number where:  a <= rand < b
def rand(a, b):
    return (b-a)*random.random() + a

# Make a matrix (we could use NumPy to speed this up)
def makeMatrix(I, J, fill=0.0):
    m = []
    for i in range(I):
        m.append([fill]*J)
    return m

class NN:
    
    def __init__(self, ni, nh, no):
        # number of input, hidden, and output nodes
        self.ni = ni + 1 # +1 for bias node
        self.nh = nh
        self.no = no

        # activations for nodes
        self.ai = [1.0]*self.ni
        self.ah = [1.0]*self.nh
        self.ao = [1.0]*self.no
        
        # create weights
        self.wi = makeMatrix(self.ni, self.nh)
        self.wo = makeMatrix(self.nh, self.no)
        # set them to random values
        for i in range(self.ni):
            for j in range(self.nh):
                self.wi[i][j] = rand(-2.0, 2.0)
        for j in range(self.nh):
            for k in range(self.no):
                self.wo[j][k] = rand(-2.0, 2.0)

        # last change in weights for momentum   
        self.ci = makeMatrix(self.ni, self.nh)
        self.co = makeMatrix(self.nh, self.no)

    def update(self, inputs):
        if len(inputs) != self.ni-1:
            raise ValueError('wrong number of inputs')

        # input activations
        for i in range(self.ni-1):
            #self.ai[i] = 1.0/(1.0+math.exp(-inputs[i]))
            self.ai[i] = inputs[i]

        # hidden activations
        for j in range(self.nh):
            sum = 0.0
            for i in range(self.ni):
                sum = sum + self.ai[i] * self.wi[i][j]
            self.ah[j] = 1.0/(1.0+math.exp(-sum))

        # output activations
        for k in range(self.no):
            sum = 0.0
            for j in range(self.nh):
                sum = sum + self.ah[j] * self.wo[j][k]
            self.ao[k] = 1.0/(1.0+math.exp(-sum))

        return self.ao[:]


    def backPropagate(self, targets, N, M):
        if len(targets) != self.no:
            raise ValueError('wrong number of target values')

        # calculate error terms for output
        output_deltas = [0.0] * self.no
        for k in range(self.no):
            ao = self.ao[k]
            output_deltas[k] = ao*(1-ao)*(targets[k]-ao)

        # calculate error terms for hidden
        hidden_deltas = [0.0] * self.nh
        for j in range(self.nh):
            sum = 0.0
            for k in range(self.no):
                sum = sum + output_deltas[k]*self.wo[j][k]
            hidden_deltas[j] = self.ah[j]*(1-self.ah[j])*sum

        # update output weights
        for j in range(self.nh):
            for k in range(self.no):
                change = output_deltas[k]*self.ah[j]
                self.wo[j][k] = self.wo[j][k] + N*change + M*self.co[j][k]
                self.co[j][k] = change
                #print N*change, M*self.co[j][k]

        # update input weights
        for i in range(self.ni):
            for j in range(self.nh):
                change = hidden_deltas[j]*self.ai[i]
                self.wi[i][j] = self.wi[i][j] + N*change + M*self.ci[i][j]
                self.ci[i][j] = change

        # calculate error
        error = 0.0
        for k in range(len(targets)):
            delta = targets[k]-self.ao[k]
            error = error + 0.5*delta*delta
        return error


    def test(self, patterns):
        for p in patterns:
            if PRINT_IT:
                print p[0], '->', self.update(p[0])

    def weights(self):
        if PRINT_IT:
            print 'Input weights:'
            for i in range(self.ni):
                print self.wi[i]
            print
            print 'Output weights:'
            for j in range(self.nh):
                print self.wo[j]

    def train(self, patterns, iterations=2000, N=0.5, M=0.1):
        # N: learning rate
        # M: momentum factor
        for i in xrange(iterations):
            error = 0.0
            for p in patterns:
                inputs = p[0]
                targets = p[1]
                self.update(inputs)
                error = error + self.backPropagate(targets, N, M)
            if PRINT_IT and i % 100 == 0:
                print 'error', error


def demo():
    # Teach network XOR function
    pat = [
        [[0,0], [0]],
        [[0,1], [1]],
        [[1,0], [1]],
        [[1,1], [0]]
    ]

    # create a network with two input, three hidden, and one output nodes
    n = NN(2, 3, 1)
    # train it with some patterns
    n.train(pat, 2000)
    # test it
    n.test(pat)


# __________  Entry point for stand-alone builds __________

def entry_point(argv):
    if len(argv) > 1:
        N = int(argv[1])
    else:
        N = 200
    T = time.time()
    for i in range(N):
        demo()
    t1 = time.time() - T
    print "%d iterations, %s milliseconds per iteration" % (N, 1000.0*t1/N)
    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None

if __name__ == '__main__':
    if len(sys.argv) == 1:
        sys.argv.append('1')
    entry_point(sys.argv)
    print __doc__
