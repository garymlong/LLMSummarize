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
- **No secrets in code** (use environment variables)
- **All new features require tests**
- **PRs must pass CI checks** (lint, test, type check)
- **Plans**: Store all project plans in `plans/` as markdown files (e.g., `plans/multi_file_support_plan_v0.md`), use task lists (- [ ] / — [x]), todo tracking, and cross-link related docs.
- Always think step-by-step before writing any code or making suggestions.
- Explain your reasoning in detail before proposing changes or code.
- Never output code without a clear, preceding explanation and plan.
- Prioritize clean, readable, maintainable code over clever shortcuts.
- Follow existing project style, conventions, and patterns exactly.
- If anything is ambiguous, ask for clarification instead of assuming.
- Output complete code blocks – no placeholders, ellipses, or "rest unchanged".
- Be concise but thorough – no unnecessary verbosity unless asked.
- Self-documenting code‒expressive identifiers, minimal explanatory comments.
- Explicit error handling‒no uncaught exceptions.
- No dummy data‒remove placeholders; tests use real fixtures, not mocks.
- Docstrings on every public symbol.
- Rule upkeep‒if ./cursor/rules is missing or stale, propose updates; flag any legacy .cursorrules file at once.
- Dev-friendly scripts‒shell scripts must print clear, colourised output.
- Python env‒ensure a local venv; create it if absent.
- When showing the summary of changes, always provide a markdown compatible block of text that the user can copy in addition to showing the summary of changes
