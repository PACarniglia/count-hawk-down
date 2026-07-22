# Godot Jam Starter Template

Fast-start template for a Godot game jam team using Git.

## What this template includes

- `.gitignore` tuned for Godot 4.1+ (`.godot/`, `*.translation`).
- `.gitattributes` with:
  - LF line endings for consistency across Windows/macOS/Linux.
  - Text-friendly handling for Godot scene/resource text files.
  - Optional commented Git LFS patterns for large binary assets.

## Host setup (do this before 1pm)

1. Create a remote repo from this template (or push this folder as a new repo).
2. Confirm these files exist in the root:
   - `.gitignore`
   - `.gitattributes`
3. On your machine, set Git line endings (recommended on Windows):

```bash
git config --global core.autocrlf input
```

4. If you plan to use large binary assets, enable Git LFS now (before first asset commit):

```bash
git lfs install
```

5. If using LFS, uncomment the file types you need in `.gitattributes`, then commit.
6. Push `main` and protect it if your host supports branch protection.
7. In GitHub, create a repository label named `jam-task` so the issue template label resolves correctly.

If you use GitHub CLI, you can create it quickly:

```bash
gh label create jam-task --color 0E8A16 --description "Game jam task"
```

## Team member setup (5 minutes)

1. Install:
  - Git
  - Godot 4.7.1 LTS (same exact version for everyone)
  - Git LFS (if the project uses it)
2. Clone the repo:

```bash
git clone <your-repo-url>
cd <repo-folder>
```

3. Set line endings once (Windows):

```bash
git config --global core.autocrlf input
```

4. If project uses LFS:

```bash
git lfs install
git lfs pull
```

5. Open the project in Godot.
6. First run may generate local cache under `.godot/` (already ignored).

## Jam workflow (recommended)

- Create short-lived branches per feature/fix:
  - `feat/player-dash`
  - `fix/menu-audio`
- Keep commits small and descriptive.
- Open pull requests into `main` instead of direct pushes.
- Pull latest `main` before opening Godot each day.

## Quick command cheat sheet

```bash
# Start a branch
git checkout -b feat/my-change

# See what changed
git status

# Stage + commit
git add .
git commit -m "Add basic enemy patrol"

# Push branch
git push -u origin feat/my-change
```

## Notes for Godot versions

- This template targets Godot 4.1+ VCS behavior.
- For this jam, the pinned engine version is Godot 4.7.1 LTS for all teammates.
- If someone has a different Godot version installed, switch to 4.7.1 before opening the project.
