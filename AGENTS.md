# Repository conventions

- Branches: `<type>/<name>` (for example, `feat/fantasy-main-menu`).
- Use Conventional Commits: `<type>(<scope>): <summary>`.
- Before a PR: rebase on `origin/main`, run `git diff --check`, run the Godot menu smoke test, push, then open the PR against `main`.

## Godot

- Keep `.godot/` ignored; commit source assets and their `.import` sidecars.
- Smoke test: `Godot --headless --path . --quit-after 3 scenes/MainMenu.tscn`.
