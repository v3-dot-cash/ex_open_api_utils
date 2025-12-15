# CLAUDE.md

This file provides coding standards and best practices for Claude Code when working with this repository.

---

## Git Conventions

```bash
# Use conventional commits with sign-off
git commit -s -m "feat(schema): add new validation

- Add validation for required fields
- Update tests
- Update documentation

Fixes #123"
```

**Commit Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `refactor:` - Code restructuring
- `test:` - Adding tests
- `chore:` - Maintenance
- `deps:` - Dependency updates

**Always use `-s` flag for sign-off**

---

## Development Commands

**Testing**
```bash
mix test                     # Run all tests
mix test --cover             # Run tests with coverage
```

**Dependencies**
```bash
mix deps.get                 # Get dependencies
mix deps.update --all        # Update all dependencies
```

**Code Quality**
```bash
mix format                   # Format code
mix credo                    # Code quality checks
mix docs                     # Generate documentation
```

---

## Publishing to Hex

```bash
mix hex.publish              # Publish package to Hex.pm
```