# Tests

pytest test suite for Python scripts in scripts/.

## Conventions

- Test files: `tests/test_<script_name>.py`
- Test naming: `test_<function>_<scenario>_<expected>`
- Use `assert` statements, not unittest-style methods
- Fixtures for shared setup; `conftest.py` for shared fixtures
- Mock external dependencies (Snowflake connections, file I/O)
