from rpython.translator.backendopt import graphanalyze        

# This is not an optimization. It checks for possible releases of the
# GIL in all graphs starting from rgc.no_release_gil.


class GilAnalyzer(graphanalyze.BoolGraphAnalyzer):
    
    def analyze_direct_call(self, graph, seen=None):
        try:
            func = graph.func
        except AttributeError:
            pass
        else:
            if getattr(func, '_gctransformer_hint_close_stack_', False):
                return True
            if getattr(func, '_transaction_break_', False):
                return True
      
        return graphanalyze.BoolGraphAnalyzer.analyze_direct_call(
            self, graph, seen)

    def analyze_external_call(self, op, seen=None):
        return False

    def analyze_simple_operation(self, op, graphinfo):
        return False

def analyze(graphs, translator):
    gilanalyzer = GilAnalyzer(translator)
    for graph in graphs:
        func = getattr(graph, 'func', None)
        if func and getattr(func, '_no_release_gil_', False):
            if gilanalyzer.analyze_direct_call(graph):
                # 'no_release_gil' function can release the gil
                import cStringIO
                err = cStringIO.StringIO()
                import sys
                prev = sys.stdout
                try:
                    sys.stdout = err
                    ca = GilAnalyzer(translator)
                    ca.verbose = True
                    ca.analyze_direct_call(graph)  # print the "traceback" here
                    sys.stdout = prev
                except:
                    sys.stdout = prev
                # ^^^ for the dump of which operation in which graph actually
                # causes it to return True
                raise Exception("'no_release_gil' function can release the GIL:"
                                " %s\n%s" % (func, err.getvalue()))

        
