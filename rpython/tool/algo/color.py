
class DependencyGraph(object):

    def __init__(self):
        self._all_nodes = []
        self.neighbours = {}

    def add_node(self, v):
        if v not in self.neighbours:
            self._all_nodes.append(v)
            self.neighbours[v] = set()

    def add_edge(self, v1, v2):
        assert v1 != v2
        self.neighbours[v1].add(v2)
        self.neighbours[v2].add(v1)

    def coalesce(self, vold, vnew):
        """Remove vold from the graph, and attach all its edges to vnew."""
        for n in self.neighbours.pop(vold):
            self.neighbours[n].remove(vold)
            assert vnew != n
            self.neighbours[n].add(vnew)
            self.neighbours[vnew].add(n)
        # we should remove vold from self._all_nodes, but it's too costly
        # so we rely on getnodes() to filter self._all_nodes.

    def getnodes(self):
        return [v for v in self._all_nodes if v in self.neighbours]

    def lexicographic_order(self):
        """Enumerate a lexicographic breadth-first ordering of the nodes."""
        sigma = [self.getnodes()[::-1]]
        if not sigma[0]:
            return
        while sigma:
            v = sigma[0].pop()
            yield v
            newsigma = []
            neighb = self.neighbours[v]
            for s in sigma:
                s1 = []
                s2 = []
                for x in s:
                    if x in neighb:
                        s1.append(x)
                    else:
                        s2.append(x)
                if s1:
                    newsigma.append(s1)
                if s2:
                    newsigma.append(s2)
            sigma = newsigma

    def size_of_largest_clique(self):
        """Assuming that the graph is chordal, compute the size of
        the largest clique in it."""
        result = 0
        seen = set()
        for v in self.lexicographic_order():
            num = 1
            for n in self.neighbours[v]:
                if n in seen:
                    num += 1
            if num > result:
                result = num
            seen.add(v)
        return result

    def find_node_coloring(self):
        """Return a random minimal node coloring, assuming that
        the graph is chordal.  For non-chordal graphs this is just
        an approximately good answer (but still a valid one)."""
        result = {}
        for v in self.lexicographic_order():
            forbidden = 0      # bitset
            for n in self.neighbours[v]:
                if n in result:
                    forbidden |= (1 << result[n])
            # find the lowest 0 bit
            num = 0
            while forbidden & (1 << num):
                num += 1
            result[v] = num
        return result
