# Lua Script Style Guide

- Document with [LDoc](https://stevedonovan.github.io/ldoc/).
- Use `snake_case` for variables and functions.
- Use `CamelCase` for OOP class names.
- Use `UPPER_CASE` for constants. Put top-level constants at the beginning of the file.
- Use `is_` when naming boolean functions, e.g. `is_between()`.
- Typecheck in critical places (`assert(type(myvar) == 'string')`).

## StyLua Formatter Config (`.stylua.toml`)

```toml
column_width = 120
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferSingle"
call_parentheses = "Always"
collapse_simple_statement = "Never"
```