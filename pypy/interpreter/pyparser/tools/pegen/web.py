import html
import io
import textwrap
import tokenize
import traceback
from typing import IO, Any, Dict, Final, Type, cast

from flask import Flask, cli, redirect, render_template, url_for  # type: ignore
from flask_wtf import FlaskForm  # type: ignore
from wtforms import SubmitField, TextAreaField  # type: ignore
from wtforms.validators import DataRequired  # type: ignore

from pegen.grammar import Grammar
from pegen.grammar_parser import GeneratedParser as GrammarParser
from pegen.parser import Parser
from pegen.python_generator import PythonParserGenerator
from pegen.tokenizer import Tokenizer

DEFAULT_GRAMMAR = """\
start: expr NEWLINE? ENDMARKER { expr }
expr:
      | expr '+' term { expr + term }
      | expr '-' term { expr - term}
      | term
term:
      | term '*' factor { term * factor }
      | term '/' factor { term / factor }
      | factor

factor:
       | '(' expr ')' { expr }
       | atom { int(atom.string) }
atom: NUMBER
"""

DEFAULT_SOURCE = "(1 + 2) * (3 - 6)"


def run_parser(file: IO[bytes], parser_class: Type[Parser], *, verbose: bool = False) -> Any:
    # Run a parser on a file (stream).
    tokenizer = Tokenizer(tokenize.generate_tokens(file.readline))  # type: ignore # typeshed issue #3515
    parser = parser_class(tokenizer, verbose=verbose)
    result = parser.start()
    if result is None:
        raise parser.make_syntax_error("invalid syntax")
    return result


def parse_string(
    source: str, parser_class: Type[Parser], *, dedent: bool = True, verbose: bool = False
) -> Any:
    # Run the parser on a string.
    if dedent:
        source = textwrap.dedent(source)
    file = io.StringIO(source)
    return run_parser(file, parser_class, verbose=verbose)  # type: ignore # typeshed issue #3515


def generate_parser(grammar: Grammar) -> Type[Parser]:
    # Generate a parser.
    out = io.StringIO()
    genr = PythonParserGenerator(grammar, out)
    genr.generate("<string>")

    # Load the generated parser class.
    ns: Dict[str, Any] = {}
    exec(out.getvalue(), ns)
    return ns["GeneratedParser"]


def make_parser(source: str) -> Type[Parser]:
    # Combine parse_string() and generate_parser().
    grammar = parse_string(source, GrammarParser)
    return generate_parser(grammar)


app = Flask(__name__)

# Flask-WTF requires an encryption key - the string can be anything
app.config["SECRET_KEY"] = "does_not_matter"


class GrammarForm(FlaskForm):  # type: ignore
    grammar = TextAreaField("PEG GRAMMAR", validators=[DataRequired()], default=DEFAULT_GRAMMAR)
    source = TextAreaField("PROGRAM", validators=[DataRequired()], default=DEFAULT_SOURCE)
    submit = SubmitField("Parse!")


@app.route("/", methods=["GET", "POST"])
def index() -> None:
    # you must tell the variable 'form' what you named the class, above
    # 'form' is the variable name used in this template: index.html
    form = GrammarForm()
    form.grammar(class_="form-control")
    output_text = "\n"
    if form.validate_on_submit():
        grammar_source = form.grammar.data
        program_source = form.source.data
        output = io.StringIO()
        try:
            parser_class = make_parser(grammar_source)
            result = parse_string(program_source, parser_class, verbose=False)
            print(result, file=output)
        except Exception as e:
            traceback.print_exc(file=output)
        output_text += output.getvalue()
    return render_template("index.html", form=form, output=output_text)


if __name__ == "__main__":
    cli.show_server_banner = lambda *_: None
    app.run(debug=False)
