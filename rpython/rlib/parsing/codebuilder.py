import contextlib

class Codebuilder(object):
    def __init__(self):
        self.blocks = []
        self.code = []

    def get_code(self):
        assert not self.blocks
        return "\n".join(["    " * depth + line for depth, line in self.code])

    def make_parser(self):
        m = {'Status': Status,
             'Nonterminal': Nonterminal,
             'Symbol': Symbol,}
        exec(py.code.Source(self.get_code()).compile(), m)
        return m['Parser']

    def emit(self, line):
        for line in line.split("\n"):
            if line:
                self.code.append((len(self.blocks),  line))

    def emit_initcode(self, line):
        for line in line.split("\n"):
            self.initcode.append(line)

    def start_block(self, blockstarter):
        assert blockstarter.endswith(":")
        self.emit(blockstarter)
        self.blocks.append(blockstarter)

    @contextlib.contextmanager
    def block(self, blockstarter):
        self.start_block(blockstarter)
        yield None
        self.end_block(blockstarter)

    def end_block(self, starterpart=""):
        block = self.blocks.pop()
        assert starterpart in block, "ended wrong block %s with %s" % (
            block, starterpart)

    def store_code_away(self):
        result = self.blocks, self.code
        self.code = []
        self.blocks = []
        return result

    def restore_code(self, (blocks, code)):
        result = self.blocks, self.code
        self.code = code
        self.blocks = blocks
        return result

    def add_code(self, (blocks, code)):
        self.code += [(depth + len(self.blocks), line) for depth, line in code]
        self.blocks += blocks
 
