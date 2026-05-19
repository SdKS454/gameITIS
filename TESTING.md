# Testing

## Local checks

Run all local checks with:

```bash
./scripts/dev/run_checks.sh
```

This runs:

1. `godot --headless --path . --quit`
2. `godot --headless --path . --script res://tests/smoke_test.gd`

If your system uses `godot4` instead of `godot`, the script auto-detects it.

## CI

GitHub Actions workflow `.github/workflows/godot-checks.yml` runs the same headless checks in a Godot 4.2.2 container.
