# AGENTS.md

## Build & Test Commands
- **Build**: `python setup.py build`
- **Install deps**: `pip install -r requirements.txt`
- **Run all tests**: `pytest`
- **Run single test**: `pytest tests/test_file.py::TestClass::test_method`
- **Run by keyword**: `pytest -k 'test_name'`
- **Lint**: `flake8 . --ignore=E501,W503`
- **Format**: `black .`
- **Type check**: `mypy .`

## Code Style Guidelines

### Imports
- **Order**: Standard library → Third-party → Local (blank lines between groups)
- **No wildcard imports** (`from module import *`)
- Example:
```python
import os
import sys

from flask import Flask
from myapp.utils import log_error
```

### Formatting
- **Black-compliant**: No manual line breaks/indentation
- **Max line length**: 100 chars
- **Trailing commas** required in multi-line structures

### Types
- **Mandatory type hints** for all public functions/methods
- **Use `Optional`** for nullable values
- Example:
```python
from typing import Optional

def get_user(id: int) -> Optional[dict]:
    # ...
```

### Naming
- **Variables/functions**: `snake_case`
- **Classes**: `PascalCase`
- **Constants**: `UPPER_SNAKE_CASE`

### Error Handling
- **Specific exceptions** (e.g., `ValueError`, not `Exception`)
- **Log context** with `logging.error`
- **No bare `except`**
Example:
```python
try:
    response = requests.get(url)
except requests.exceptions.RequestException as e:
    logging.error(f"Request failed: {str(e)}")
```

## Critical Rules
1. **No secrets in code** (use environment variables)
2. **All new features require tests**
3. **PRs must pass CI checks** (lint, test, type check)
4. **Commit messages**: `feat: add X`, `fix: Y`, max 50 chars
5. **Plans**: Store all project plans in `plans/` as markdown files (e.g., `plans/multi_file_support_plan_v0.md`).

