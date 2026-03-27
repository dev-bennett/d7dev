---
name: Python Standards
paths: ["scripts/**/*.py", "tests/**/*.py"]
---

# Python Coding Standards

- Type hints required on all function signatures and return types
- Docstrings: Google style, required on public functions and classes
- Imports ordered: stdlib, third-party, local (isort compatible)
- Use `pathlib.Path` over `os.path`
- Use dataclasses or Pydantic for structured data, not raw dicts
- No bare `except:` -- always catch specific exceptions
- f-strings over `.format()` or `%` formatting
- Functions should aim for under 30 lines; extract helpers when exceeding
- Constants in UPPER_SNAKE_CASE at module level
- Private functions/methods prefixed with `_`
- Avoid mutable default arguments (use `None` + assignment pattern)
