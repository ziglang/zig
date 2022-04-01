from __future__ import division

EPSILON = 1E-12


class SparseMatrix:

    def __init__(self, height):
        self.lines = [{} for row in range(height)]

    def __getitem__(self, (row, col)):
        return self.lines[row].get(col, 0)

    def __setitem__(self, (row, col), value):
        if abs(value) > EPSILON:
            self.lines[row][col] = value
        else:
            try:
                del self.lines[row][col]
            except KeyError:
                pass

    def copy(self):
        m = SparseMatrix(len(self.lines))
        for line1, line2 in zip(self.lines, m.lines):
            line2.update(line1)
        return m

    def solve(self, vector):
        """Solves  'self * [x1...xn] == vector'; returns the list [x1...xn].
        Raises ValueError if no solution or indeterminate.
        """
        vector = list(vector)
        lines = [line.copy() for line in self.lines]
        columns = [{} for i in range(len(vector))]
        for i, line in enumerate(lines):
            for j, a in line.items():
                columns[j][i] = a
        lines_left = dict.fromkeys(range(len(self.lines)))
        nrows = []
        for ncol in range(len(vector)):
            currentcolumn = columns[ncol]
            lst = [(abs(a), i) for (i, a) in currentcolumn.items()
                               if i in lines_left]
            _, nrow = max(lst)    # ValueError -> no solution
            nrows.append(nrow)
            del lines_left[nrow]
            line1 = lines[nrow]
            maxa = line1[ncol]
            for _, i in lst:
                if i != nrow:
                    line2 = lines[i]
                    a = line2.pop(ncol)
                    #del currentcolumn[i]  -- but currentcolumn no longer used
                    factor = a / maxa
                    vector[i] -= factor*vector[nrow]
                    for col in line1:
                        if col > ncol:
                            value = line2.get(col, 0) - factor*line1[col]
                            if abs(value) > EPSILON:
                                line2[col] = columns[col][i] = value
                            else:
                                line2.pop(col, 0)
                                columns[col].pop(i, 0)
        solution = [None] * len(vector)
        for i in range(len(vector)-1, -1, -1):
            row = nrows[i]
            line = lines[row]
            total = vector[row]
            for j, a in line.items():
                if j != i:
                    total -= a * solution[j]
            solution[i] = total / line[i]
        return solution
