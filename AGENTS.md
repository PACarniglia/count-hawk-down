# Repository conventions

- Branches: `feat/<name>`, `fix/<name>`, `chore/<name>`, or `hotfix/<name>`.
- Use Conventional Commits: `<type>(<scope>): <summary>`.

## Standard delivery process

For every change:

1. Start from the current `main` branch and create a dedicated feature branch.
2. Make one commit containing the completed change.
3. Rebase on `origin/main`, run `git diff --check` and the Godot menu smoke test, then push and open a PR against `main`.
4. Merge the pull request into `main`.

## Godot

- Keep `.godot/` ignored; commit source assets and their `.import` sidecars.
- Smoke test: `Godot --headless --path . --quit-after 3 scenes/MainMenu.tscn`.
