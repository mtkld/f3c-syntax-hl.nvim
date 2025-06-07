# F3C Syntax Highlighting

Very simple line by line regex based syntax highlighting for _[F3C](https://github.com/mtkld/f3c)_ files.

_F3c_ supporting dynamic terminators, HERE-docs, is difficult to implement a highlighter based on _Tree-sitter_ for. A simple line by line regex based highlighter is surprisingly effective and covers most of the cases.

## TODO

Move the hard coded color theme to be dynamically set by the user in the plugin spec.
