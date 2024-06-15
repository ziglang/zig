//! Markdown parsing and rendering support.
//!
//! A Markdown document consists of a series of blocks. Depending on its type,
//! each block may contain other blocks, inline content, or nothing. The
//! supported blocks are as follows:
//!
//! - **List** - a sequence of list items of the same type.
//!
//! - **List item** - unordered list items start with `-`, `*`, or `+` followed
//!   by a space. Ordered list items start with a number between 0 and
//!   999,999,999, followed by a `.` or `)` and a space. The number of an
//!   ordered list item only matters for the first item in the list (to
//!   determine the starting number of the list). All subsequent ordered list
//!   items will have sequentially increasing numbers.
//!
//!   All list items may contain block content. Any content indented at least as
//!   far as the end of the list item marker (including the space after it) is
//!   considered part of the list item.
//!
//!   Lists which have no blank lines between items or between direct children
//!   of items are considered _tight_, and direct child paragraphs of tight list
//!   items are rendered without `<p>` tags.
//!
//! - **Table** - a sequence of adjacent table row lines, where each line starts
//!   and ends with a `|`, and cells within the row are delimited by `|`s.
//!
//!   The first or second row of a table may be a _header delimiter row_, which
//!   is a row consisting of cells of the pattern `---` (for unset column
//!   alignment), `:--` (for left alignment), `:-:` (for center alignment), or
//!   `--:` (for right alignment). The number of `-`s must be at least one, but
//!   is otherwise arbitrary. If there is a row just before the header delimiter
//!   row, it becomes the header row for the table (a table need not have a
//!   header row at all).
//!
//! - **Heading** - a sequence of between 1 and 6 `#` characters, followed by a
//!   space and further inline content on the same line.
//!
//! - **Code block** - a sequence of at least 3 `` ` `` characters (a _fence_),
//!   optionally followed by a "tag" on the same line, and continuing until a
//!   line consisting only of a closing fence whose length matches the opening
//!   fence, or until the end of the containing block.
//!
//!   The content of a code block is not parsed as inline content. It is
//!   included verbatim in the output document (minus leading indentation up to
//!   the position of the opening fence).
//!
//! - **Blockquote** - a sequence of lines preceded by `>` characters.
//!
//! - **Paragraph** - ordinary text, parsed as inline content, ending with a
//!   blank line or the end of the containing block.
//!
//!   Paragraphs which are part of another block may be "lazily" continued by
//!   subsequent paragraph lines even if those lines would not ordinarily be
//!   considered part of the containing block. For example, this is a single
//!   list item, not a list item followed by a paragraph:
//!
//!   ```markdown
//!   - First line of content.
//!   This content is still part of the paragraph,
//!   even though it isn't indented far enough.
//!   ```
//!
//! - **Thematic break** - a line consisting of at least three matching `-`,
//!   `_`, or `*` characters and, optionally, spaces.
//!
//! Indentation may consist of spaces and tabs. The use of tabs is not
//! recommended: a tab is treated the same as a single space for the purpose of
//! determining the indentation level, and is not recognized as a space for
//! block starters which require one (for example, `-` followed by a tab is not
//! a valid list item).
//!
//! The supported inlines are as follows:
//!
//! - **Link** - of the format `[text](target)`. `text` may contain inline
//!   content. `target` may contain `\`-escaped characters and balanced
//!   parentheses.
//!
//! - **Autolink** - an abbreviated link, of the format `<target>`, where
//!   `target` serves as both the link target and text. `target` may not
//!   contain spaces or `<`, and any `\` in it are interpreted literally (not as
//!   escapes). `target` is expected to be an absolute URI: an autolink will not
//!   be recognized unless `target` starts with a URI scheme followed by a `:`.
//!
//!   For convenience, autolinks may also be recognized in plain text without
//!   any `<>` delimiters. Such autolinks are restricted to start with `http://`
//!   or `https://` followed by at least one other character, not including any
//!   trailing punctuation after the link.
//!
//! - **Image** - a link directly preceded by a `!`. The link text is
//!   interpreted as the alt text of the image.
//!
//! - **Emphasis** - a run of `*` or `_` characters may be an emphasis opener,
//!   closer, or both. For `*` characters, the run may be an opener as long as
//!   it is not directly followed by a whitespace character (or the end of the
//!   inline content) and a closer as long as it is not directly preceded by
//!   one. For `_` characters, this rule is strengthened by requiring that the
//!   run also be preceded by a whitespace or punctuation character (for
//!   openers) or followed by one (for closers), to avoid mangling `snake_case`
//!   words.
//!
//!   The rule for emphasis handling is greedy: any run that can close existing
//!   emphasis will do so, otherwise it will open emphasis. A single run may
//!   serve both functions: the middle `**` in the following example both closes
//!   the initial emphasis and opens a new one:
//!
//!   ```markdown
//!   *one**two*
//!   ```
//!
//!   A single `*` or `_` is used for normal emphasis (HTML `<em>`), and a
//!   double `**` or `__` is used for strong emphasis (HTML `<strong>`). Even
//!   longer runs may be used to produce further nested emphasis (though only
//!   `***` and `___` to produce `<em><strong>` is really useful).
//!
//! - **Code span** - a run of `` ` `` characters, terminated by a matching run
//!   or the end of inline content. The content of a code span is not parsed
//!   further.
//!
//! - **Text** - normal text is interpreted as-is, except that `\` may be used
//!   to escape any punctuation character, preventing it from being interpreted
//!   according to other syntax rules. A `\` followed by a line break within a
//!   paragraph is interpreted as a hard line break.
//!
//!   Any null bytes or invalid UTF-8 bytes within text are replaced with Unicode
//!   replacement characters, `U+FFFD`.

const std = @import("std");
const testing = std.testing;

pub const Document = @import("markdown/Document.zig");
pub const Parser = @import("markdown/Parser.zig");
pub const Renderer = @import("markdown/renderer.zig").Renderer;
pub const renderNodeInlineText = @import("markdown/renderer.zig").renderNodeInlineText;
pub const fmtHtml = @import("markdown/renderer.zig").fmtHtml;

// Avoid exposing main to other files merely importing this one.
pub const main = if (@import("root") == @This())
    mainImpl
else
    @compileError("only available as root source file");

fn mainImpl() !void {
    const gpa = std.heap.c_allocator;

    var parser = try Parser.init(gpa);
    defer parser.deinit();

    var stdin_buf = std.io.bufferedReader(std.io.getStdIn().reader());
    var line_buf = std.ArrayList(u8).init(gpa);
    defer line_buf.deinit();
    while (stdin_buf.reader().streamUntilDelimiter(line_buf.writer(), '\n', null)) {
        if (line_buf.getLastOrNull() == '\r') _ = line_buf.pop();
        try parser.feedLine(line_buf.items);
        line_buf.clearRetainingCapacity();
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => |e| return e,
    }

    var doc = try parser.endInput();
    defer doc.deinit(gpa);

    var stdout_buf = std.io.bufferedWriter(std.io.getStdOut().writer());
    try doc.render(stdout_buf.writer());
    try stdout_buf.flush();
}

test "empty document" {
    try testRender("", "");
    try testRender("   ", "");
    try testRender("\n \n\t\n   \n", "");
}

test "unordered lists" {
    try testRender(
        \\- Spam
        \\- Spam
        \\- Spam
        \\- Eggs
        \\- Bacon
        \\- Spam
        \\
        \\* Spam
        \\* Spam
        \\* Spam
        \\* Eggs
        \\* Bacon
        \\* Spam
        \\
        \\+ Spam
        \\+ Spam
        \\+ Spam
        \\+ Eggs
        \\+ Bacon
        \\+ Spam
        \\
    ,
        \\<ul>
        \\<li>Spam</li>
        \\<li>Spam</li>
        \\<li>Spam</li>
        \\<li>Eggs</li>
        \\<li>Bacon</li>
        \\<li>Spam</li>
        \\</ul>
        \\<ul>
        \\<li>Spam</li>
        \\<li>Spam</li>
        \\<li>Spam</li>
        \\<li>Eggs</li>
        \\<li>Bacon</li>
        \\<li>Spam</li>
        \\</ul>
        \\<ul>
        \\<li>Spam</li>
        \\<li>Spam</li>
        \\<li>Spam</li>
        \\<li>Eggs</li>
        \\<li>Bacon</li>
        \\<li>Spam</li>
        \\</ul>
        \\
    );
}

test "ordered lists" {
    try testRender(
        \\1. Breakfast
        \\2. Second breakfast
        \\3. Lunch
        \\2. Afternoon snack
        \\1. Dinner
        \\6. Dessert
        \\7. Midnight snack
        \\
        \\1) Breakfast
        \\2) Second breakfast
        \\3) Lunch
        \\2) Afternoon snack
        \\1) Dinner
        \\6) Dessert
        \\7) Midnight snack
        \\
        \\1001. Breakfast
        \\2. Second breakfast
        \\3. Lunch
        \\2. Afternoon snack
        \\1. Dinner
        \\6. Dessert
        \\7. Midnight snack
        \\
        \\1001) Breakfast
        \\2) Second breakfast
        \\3) Lunch
        \\2) Afternoon snack
        \\1) Dinner
        \\6) Dessert
        \\7) Midnight snack
        \\
    ,
        \\<ol>
        \\<li>Breakfast</li>
        \\<li>Second breakfast</li>
        \\<li>Lunch</li>
        \\<li>Afternoon snack</li>
        \\<li>Dinner</li>
        \\<li>Dessert</li>
        \\<li>Midnight snack</li>
        \\</ol>
        \\<ol>
        \\<li>Breakfast</li>
        \\<li>Second breakfast</li>
        \\<li>Lunch</li>
        \\<li>Afternoon snack</li>
        \\<li>Dinner</li>
        \\<li>Dessert</li>
        \\<li>Midnight snack</li>
        \\</ol>
        \\<ol start="1001">
        \\<li>Breakfast</li>
        \\<li>Second breakfast</li>
        \\<li>Lunch</li>
        \\<li>Afternoon snack</li>
        \\<li>Dinner</li>
        \\<li>Dessert</li>
        \\<li>Midnight snack</li>
        \\</ol>
        \\<ol start="1001">
        \\<li>Breakfast</li>
        \\<li>Second breakfast</li>
        \\<li>Lunch</li>
        \\<li>Afternoon snack</li>
        \\<li>Dinner</li>
        \\<li>Dessert</li>
        \\<li>Midnight snack</li>
        \\</ol>
        \\
    );
}

test "nested lists" {
    try testRender(
        \\- - Item 1.
        \\  - Item 2.
        \\Item 2 continued.
        \\  * New list.
        \\
    ,
        \\<ul>
        \\<li><ul>
        \\<li>Item 1.</li>
        \\<li>Item 2.
        \\Item 2 continued.</li>
        \\</ul>
        \\<ul>
        \\<li>New list.</li>
        \\</ul>
        \\</li>
        \\</ul>
        \\
    );
}

test "lists with block content" {
    try testRender(
        \\1. Item 1.
        \\2. Item 2.
        \\
        \\   This one has another paragraph.
        \\3. Item 3.
        \\
        \\- > Blockquote.
        \\- - Sub-list.
        \\  - Sub-list continued.
        \\  * Different sub-list.
        \\- ## Heading.
        \\
        \\  Some contents below the heading.
        \\  1. Item 1.
        \\  2. Item 2.
        \\  3. Item 3.
        \\
    ,
        \\<ol>
        \\<li><p>Item 1.</p>
        \\</li>
        \\<li><p>Item 2.</p>
        \\<p>This one has another paragraph.</p>
        \\</li>
        \\<li><p>Item 3.</p>
        \\</li>
        \\</ol>
        \\<ul>
        \\<li><blockquote>
        \\<p>Blockquote.</p>
        \\</blockquote>
        \\</li>
        \\<li><ul>
        \\<li>Sub-list.</li>
        \\<li>Sub-list continued.</li>
        \\</ul>
        \\<ul>
        \\<li>Different sub-list.</li>
        \\</ul>
        \\</li>
        \\<li><h2>Heading.</h2>
        \\<p>Some contents below the heading.</p>
        \\<ol>
        \\<li>Item 1.</li>
        \\<li>Item 2.</li>
        \\<li>Item 3.</li>
        \\</ol>
        \\</li>
        \\</ul>
        \\
    );
}

test "indented lists" {
    try testRender(
        \\Test:
        \\ * a1
        \\ * a2
        \\      * b1
        \\      * b2
        \\
        \\---
        \\
        \\    Test:
        \\  - One
        \\Two
        \\    - Three
        \\Four
        \\    Five
        \\Six
        \\
        \\---
        \\
        \\None of these items are indented far enough from the previous one to
        \\start a nested list:
        \\  - One
        \\   - Two
        \\    - Three
        \\     - Four
        \\      - Five
        \\     - Six
        \\    - Seven
        \\   - Eight
        \\  - Nine
        \\
        \\---
        \\
        \\   - One
        \\     - Two
        \\       - Three
        \\         - Four
        \\     - Five
        \\         - Six
        \\- Seven
        \\
    ,
        \\<p>Test:</p>
        \\<ul>
        \\<li>a1</li>
        \\<li>a2<ul>
        \\<li>b1</li>
        \\<li>b2</li>
        \\</ul>
        \\</li>
        \\</ul>
        \\<hr />
        \\<p>Test:</p>
        \\<ul>
        \\<li>One
        \\Two<ul>
        \\<li>Three
        \\Four
        \\Five
        \\Six</li>
        \\</ul>
        \\</li>
        \\</ul>
        \\<hr />
        \\<p>None of these items are indented far enough from the previous one to
        \\start a nested list:</p>
        \\<ul>
        \\<li>One</li>
        \\<li>Two</li>
        \\<li>Three</li>
        \\<li>Four</li>
        \\<li>Five</li>
        \\<li>Six</li>
        \\<li>Seven</li>
        \\<li>Eight</li>
        \\<li>Nine</li>
        \\</ul>
        \\<hr />
        \\<ul>
        \\<li>One<ul>
        \\<li>Two<ul>
        \\<li>Three<ul>
        \\<li>Four</li>
        \\</ul>
        \\</li>
        \\</ul>
        \\</li>
        \\<li>Five<ul>
        \\<li>Six</li>
        \\</ul>
        \\</li>
        \\</ul>
        \\</li>
        \\<li>Seven</li>
        \\</ul>
        \\
    );
}

test "tables" {
    try testRender(
        \\| Operator | Meaning          |
        \\| :------: | ---------------- |
        \\| `+`      | Add              |
        \\| `-`      | Subtract         |
        \\| `*`      | Multiply         |
        \\| `/`      | Divide           |
        \\| `??`     | **Not sure yet** |
        \\
        \\| Item 1 | Value 1 |
        \\| Item 2 | Value 2 |
        \\| Item 3 | Value 3 |
        \\| Item 4 | Value 4 |
        \\
        \\| :--- | :----: | ----: |
        \\| Left | Center | Right |
        \\
        \\   | One | Two |
        \\ | Three |     Four   |
        \\         | Five | Six |
        \\
    ,
        \\<table>
        \\<tr>
        \\<th style="text-align: center">Operator</th>
        \\<th>Meaning</th>
        \\</tr>
        \\<tr>
        \\<td style="text-align: center"><code>+</code></td>
        \\<td>Add</td>
        \\</tr>
        \\<tr>
        \\<td style="text-align: center"><code>-</code></td>
        \\<td>Subtract</td>
        \\</tr>
        \\<tr>
        \\<td style="text-align: center"><code>*</code></td>
        \\<td>Multiply</td>
        \\</tr>
        \\<tr>
        \\<td style="text-align: center"><code>/</code></td>
        \\<td>Divide</td>
        \\</tr>
        \\<tr>
        \\<td style="text-align: center"><code>??</code></td>
        \\<td><strong>Not sure yet</strong></td>
        \\</tr>
        \\</table>
        \\<table>
        \\<tr>
        \\<td>Item 1</td>
        \\<td>Value 1</td>
        \\</tr>
        \\<tr>
        \\<td>Item 2</td>
        \\<td>Value 2</td>
        \\</tr>
        \\<tr>
        \\<td>Item 3</td>
        \\<td>Value 3</td>
        \\</tr>
        \\<tr>
        \\<td>Item 4</td>
        \\<td>Value 4</td>
        \\</tr>
        \\</table>
        \\<table>
        \\<tr>
        \\<td style="text-align: left">Left</td>
        \\<td style="text-align: center">Center</td>
        \\<td style="text-align: right">Right</td>
        \\</tr>
        \\</table>
        \\<table>
        \\<tr>
        \\<td>One</td>
        \\<td>Two</td>
        \\</tr>
        \\<tr>
        \\<td>Three</td>
        \\<td>Four</td>
        \\</tr>
        \\<tr>
        \\<td>Five</td>
        \\<td>Six</td>
        \\</tr>
        \\</table>
        \\
    );
}

test "table with uneven number of columns" {
    try testRender(
        \\| One |
        \\| :-- | :--: |
        \\| One | Two | Three |
        \\
    ,
        \\<table>
        \\<tr>
        \\<th style="text-align: left">One</th>
        \\</tr>
        \\<tr>
        \\<td style="text-align: left">One</td>
        \\<td style="text-align: center">Two</td>
        \\<td>Three</td>
        \\</tr>
        \\</table>
        \\
    );
}

test "table with escaped pipes" {
    try testRender(
        \\| One \| Two |
        \\| --- | --- |
        \\| One \| Two |
        \\
    ,
        \\<table>
        \\<tr>
        \\<th>One | Two</th>
        \\</tr>
        \\<tr>
        \\<td>One | Two</td>
        \\</tr>
        \\</table>
        \\
    );
}

test "table with pipes in code spans" {
    try testRender(
        \\| `|` | Bitwise _OR_ |
        \\| `||` | Combines error sets |
        \\| `` `||` `` | Escaped version |
        \\| ` ``||`` ` | Another escaped version |
        \\| `Oops unterminated code span |
        \\
    ,
        \\<table>
        \\<tr>
        \\<td><code>|</code></td>
        \\<td>Bitwise <em>OR</em></td>
        \\</tr>
        \\<tr>
        \\<td><code>||</code></td>
        \\<td>Combines error sets</td>
        \\</tr>
        \\<tr>
        \\<td><code>`||`</code></td>
        \\<td>Escaped version</td>
        \\</tr>
        \\<tr>
        \\<td><code>``||``</code></td>
        \\<td>Another escaped version</td>
        \\</tr>
        \\</table>
        \\<p>| <code>Oops unterminated code span |</code></p>
        \\
    );
}

test "tables require leading and trailing pipes" {
    try testRender(
        \\Not | a | table
        \\
        \\| But | this | is |
        \\
        \\Also not a table:
        \\|
        \\     |
        \\
    ,
        \\<p>Not | a | table</p>
        \\<table>
        \\<tr>
        \\<td>But</td>
        \\<td>this</td>
        \\<td>is</td>
        \\</tr>
        \\</table>
        \\<p>Also not a table:
        \\|
        \\|</p>
        \\
    );
}

test "headings" {
    try testRender(
        \\# Level one
        \\## Level two
        \\### Level three
        \\#### Level four
        \\##### Level five
        \\###### Level six
        \\####### Not a heading
        \\
    ,
        \\<h1>Level one</h1>
        \\<h2>Level two</h2>
        \\<h3>Level three</h3>
        \\<h4>Level four</h4>
        \\<h5>Level five</h5>
        \\<h6>Level six</h6>
        \\<p>####### Not a heading</p>
        \\
    );
}

test "headings with inline content" {
    try testRender(
        \\# Outline of `std.zig`
        \\## **Important** notes
        \\### ***Nested* inline content**
        \\
    ,
        \\<h1>Outline of <code>std.zig</code></h1>
        \\<h2><strong>Important</strong> notes</h2>
        \\<h3><strong><em>Nested</em> inline content</strong></h3>
        \\
    );
}

test "code blocks" {
    try testRender(
        \\```
        \\Hello, world!
        \\This is some code.
        \\```
        \\``` zig test
        \\const std = @import("std");
        \\
        \\test {
        \\    try std.testing.expect(2 + 2 == 4);
        \\}
        \\```
        \\   ```
        \\   Indentation up to the fence is removed.
        \\        Like this.
        \\ Doesn't need to be fully indented.
        \\  ```
        \\```
        \\Overly indented closing fence is fine:
        \\    ```
        \\
    ,
        \\<pre><code>Hello, world!
        \\This is some code.
        \\</code></pre>
        \\<pre><code>const std = @import(&quot;std&quot;);
        \\
        \\test {
        \\    try std.testing.expect(2 + 2 == 4);
        \\}
        \\</code></pre>
        \\<pre><code>Indentation up to the fence is removed.
        \\     Like this.
        \\Doesn't need to be fully indented.
        \\</code></pre>
        \\<pre><code>Overly indented closing fence is fine:
        \\</code></pre>
        \\
    );
}

test "blockquotes" {
    try testRender(
        \\> > You miss 100% of the shots you don't take.
        \\> >
        \\> > ~ Wayne Gretzky
        \\>
        \\> ~ Michael Scott
        \\
    ,
        \\<blockquote>
        \\<blockquote>
        \\<p>You miss 100% of the shots you don't take.</p>
        \\<p>~ Wayne Gretzky</p>
        \\</blockquote>
        \\<p>~ Michael Scott</p>
        \\</blockquote>
        \\
    );
}

test "blockquote lazy continuation lines" {
    try testRender(
        \\>>>>Deeply nested blockquote
        \\>>which continues on another line
        \\and then yet another one.
        \\>>
        \\>> But now two of them have been closed.
        \\
        \\And then there were none.
        \\
    ,
        \\<blockquote>
        \\<blockquote>
        \\<blockquote>
        \\<blockquote>
        \\<p>Deeply nested blockquote
        \\which continues on another line
        \\and then yet another one.</p>
        \\</blockquote>
        \\</blockquote>
        \\<p>But now two of them have been closed.</p>
        \\</blockquote>
        \\</blockquote>
        \\<p>And then there were none.</p>
        \\
    );
}

test "paragraphs" {
    try testRender(
        \\Paragraph one.
        \\
        \\Paragraph two.
        \\Still in the paragraph.
        \\    So is this.
        \\
        \\
        \\
        \\
        \\ Last paragraph.
        \\
    ,
        \\<p>Paragraph one.</p>
        \\<p>Paragraph two.
        \\Still in the paragraph.
        \\So is this.</p>
        \\<p>Last paragraph.</p>
        \\
    );
}

test "thematic breaks" {
    try testRender(
        \\---
        \\***
        \\___
        \\          ---
        \\ - - - - - - - - - - -
        \\
    ,
        \\<hr />
        \\<hr />
        \\<hr />
        \\<hr />
        \\<hr />
        \\
    );
}

test "links" {
    try testRender(
        \\[Link](https://example.com)
        \\[Link *with inlines*](https://example.com)
        \\[Nested parens](https://example.com/nested(parens(inside)))
        \\[Escaped parens](https://example.com/\)escaped\()
        \\[Line break in target](test\
        \\target)
        \\
    ,
        \\<p><a href="https://example.com">Link</a>
        \\<a href="https://example.com">Link <em>with inlines</em></a>
        \\<a href="https://example.com/nested(parens(inside))">Nested parens</a>
        \\<a href="https://example.com/)escaped(">Escaped parens</a>
        \\<a href="test\
        \\target">Line break in target</a></p>
        \\
    );
}

test "autolinks" {
    try testRender(
        \\<https://example.com>
        \\**This is important: <https://example.com/strong>**
        \\<https://example.com?query=abc.123#page(parens)>
        \\<placeholder>
        \\<data:>
        \\1 < 2
        \\4 > 3
        \\Unclosed: <
        \\
    ,
        \\<p><a href="https://example.com">https://example.com</a>
        \\<strong>This is important: <a href="https://example.com/strong">https://example.com/strong</a></strong>
        \\<a href="https://example.com?query=abc.123#page(parens)">https://example.com?query=abc.123#page(parens)</a>
        \\&lt;placeholder&gt;
        \\<a href="data:">data:</a>
        \\1 &lt; 2
        \\4 &gt; 3
        \\Unclosed: &lt;</p>
        \\
    );
}

test "text autolinks" {
    try testRender(
        \\Text autolinks must start with http:// or https://.
        \\This doesn't count: ftp://example.com.
        \\Example: https://ziglang.org.
        \\Here is an important link: **http://example.com**
        \\(Links may be in parentheses: https://example.com/?q=(parens))
        \\Escaping a link so it's plain text: https\://example.com
        \\
    ,
        \\<p>Text autolinks must start with http:// or https://.
        \\This doesn't count: ftp://example.com.
        \\Example: <a href="https://ziglang.org">https://ziglang.org</a>.
        \\Here is an important link: <strong><a href="http://example.com">http://example.com</a></strong>
        \\(Links may be in parentheses: <a href="https://example.com/?q=(parens)">https://example.com/?q=(parens)</a>)
        \\Escaping a link so it's plain text: https://example.com</p>
        \\
    );
}

test "images" {
    try testRender(
        \\![Alt text](https://example.com/image.png)
        \\![Alt text *with inlines*](https://example.com/image.png)
        \\![Nested parens](https://example.com/nested(parens(inside)).png)
        \\![Escaped parens](https://example.com/\)escaped\(.png)
        \\![Line break in target](test\
        \\target)
        \\
    ,
        \\<p><img src="https://example.com/image.png" alt="Alt text" />
        \\<img src="https://example.com/image.png" alt="Alt text with inlines" />
        \\<img src="https://example.com/nested(parens(inside)).png" alt="Nested parens" />
        \\<img src="https://example.com/)escaped(.png" alt="Escaped parens" />
        \\<img src="test\
        \\target" alt="Line break in target" /></p>
        \\
    );
}

test "emphasis" {
    try testRender(
        \\*Emphasis.*
        \\**Strong.**
        \\***Strong emphasis.***
        \\****More...****
        \\*****MORE...*****
        \\******Even more...******
        \\*******OK, this is enough.*******
        \\
    ,
        \\<p><em>Emphasis.</em>
        \\<strong>Strong.</strong>
        \\<em><strong>Strong emphasis.</strong></em>
        \\<em><strong><em>More...</em></strong></em>
        \\<em><strong><strong>MORE...</strong></strong></em>
        \\<em><strong><em><strong>Even more...</strong></em></strong></em>
        \\<em><strong><em><strong><em>OK, this is enough.</em></strong></em></strong></em></p>
        \\
    );
    try testRender(
        \\_Emphasis._
        \\__Strong.__
        \\___Strong emphasis.___
        \\____More...____
        \\_____MORE..._____
        \\______Even more...______
        \\_______OK, this is enough._______
        \\
    ,
        \\<p><em>Emphasis.</em>
        \\<strong>Strong.</strong>
        \\<em><strong>Strong emphasis.</strong></em>
        \\<em><strong><em>More...</em></strong></em>
        \\<em><strong><strong>MORE...</strong></strong></em>
        \\<em><strong><em><strong>Even more...</strong></em></strong></em>
        \\<em><strong><em><strong><em>OK, this is enough.</em></strong></em></strong></em></p>
        \\
    );
}

test "nested emphasis" {
    try testRender(
        \\**Hello, *world!***
        \\*Hello, **world!***
        \\**Hello, _world!_**
        \\_Hello, **world!**_
        \\*Hello, **nested** *world!**
        \\***Hello,* world!**
        \\__**Hello, world!**__
        \\****Hello,** world!**
        \\__Hello,_ world!_
        \\*Test**123*
        \\__Test____123__
        \\
    ,
        \\<p><strong>Hello, <em>world!</em></strong>
        \\<em>Hello, <strong>world!</strong></em>
        \\<strong>Hello, <em>world!</em></strong>
        \\<em>Hello, <strong>world!</strong></em>
        \\<em>Hello, <strong>nested</strong> <em>world!</em></em>
        \\<strong><em>Hello,</em> world!</strong>
        \\<strong><strong>Hello, world!</strong></strong>
        \\<strong><strong>Hello,</strong> world!</strong>
        \\<em><em>Hello,</em> world!</em>
        \\<em>Test</em><em>123</em>
        \\<strong>Test____123</strong></p>
        \\
    );
}

test "emphasis precedence" {
    try testRender(
        \\*First one _wins*_.
        \\_*No other __rule matters.*_
        \\
    ,
        \\<p><em>First one _wins</em>_.
        \\<em><em>No other __rule matters.</em></em></p>
        \\
    );
}

test "emphasis open and close" {
    try testRender(
        \\Cannot open: *
        \\Cannot open: _
        \\*Cannot close: *
        \\_Cannot close: _
        \\
        \\foo*bar*baz
        \\foo_bar_baz
        \\foo**bar**baz
        \\foo__bar__baz
        \\
    ,
        \\<p>Cannot open: *
        \\Cannot open: _
        \\*Cannot close: *
        \\_Cannot close: _</p>
        \\<p>foo<em>bar</em>baz
        \\foo_bar_baz
        \\foo<strong>bar</strong>baz
        \\foo__bar__baz</p>
        \\
    );
}

test "code spans" {
    try testRender(
        \\`Hello, world!`
        \\```Multiple `backticks` can be used.```
        \\`**This** does not produce emphasis.`
        \\`` `Backtick enclosed string.` ``
        \\`Delimiter lengths ```must``` match.`
        \\
        \\Unterminated ``code...
        \\
        \\Weird empty code span: `
        \\
        \\**Very important code: `hi`**
        \\
    ,
        \\<p><code>Hello, world!</code>
        \\<code>Multiple `backticks` can be used.</code>
        \\<code>**This** does not produce emphasis.</code>
        \\<code>`Backtick enclosed string.`</code>
        \\<code>Delimiter lengths ```must``` match.</code></p>
        \\<p>Unterminated <code>code...</code></p>
        \\<p>Weird empty code span: <code></code></p>
        \\<p><strong>Very important code: <code>hi</code></strong></p>
        \\
    );
}

test "backslash escapes" {
    try testRender(
        \\Not \*emphasized\*.
        \\Literal \\backslashes\\.
        \\Not code: \`hi\`.
        \\\# Not a title.
        \\#\# Also not a title.
        \\\> Not a blockquote.
        \\\- Not a list item.
        \\\| Not a table. |
        \\| Also not a table. \|
        \\Any \punctuation\ characte\r can be escaped:
        \\\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~
        \\
    ,
        \\<p>Not *emphasized*.
        \\Literal \backslashes\.
        \\Not code: `hi`.
        \\# Not a title.
        \\## Also not a title.
        \\&gt; Not a blockquote.
        \\- Not a list item.
        \\| Not a table. |
        \\| Also not a table. |
        \\Any \punctuation\ characte\r can be escaped:
        \\!&quot;#$%&amp;'()*+,-./:;&lt;=&gt;?@[\]^_`{|}~</p>
        \\
    );
}

test "hard line breaks" {
    try testRender(
        \\The iguana sits\
        \\Perched atop a short desk chair\
        \\Writing code in Zig
        \\
    ,
        \\<p>The iguana sits<br />
        \\Perched atop a short desk chair<br />
        \\Writing code in Zig</p>
        \\
    );
}

test "Unicode handling" {
    // Null bytes must be replaced.
    try testRender("\x00\x00\x00", "<p>\u{FFFD}\u{FFFD}\u{FFFD}</p>\n");

    // Invalid UTF-8 must be replaced.
    try testRender("\xC0\x80\xE0\x80\x80\xF0\x80\x80\x80", "<p>\u{FFFD}\u{FFFD}\u{FFFD}</p>\n");
    try testRender("\xED\xA0\x80\xED\xBF\xBF", "<p>\u{FFFD}\u{FFFD}</p>\n");

    // Incomplete UTF-8 must be replaced.
    try testRender("\xE2\x82", "<p>\u{FFFD}</p>\n");
}

fn testRender(input: []const u8, expected: []const u8) !void {
    var parser = try Parser.init(testing.allocator);
    defer parser.deinit();

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        try parser.feedLine(line);
    }
    var doc = try parser.endInput();
    defer doc.deinit(testing.allocator);

    var actual = std.ArrayList(u8).init(testing.allocator);
    defer actual.deinit();
    try doc.render(actual.writer());

    try testing.expectEqualStrings(expected, actual.items);
}
