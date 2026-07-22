# Godot Jam Starter Template

Fast-start template for a Godot game jam team using Git.

## What this template includes

- `.gitignore` tuned for Godot 4.1+ (`.godot/`, `*.translation`).
- `.gitattributes` with:
  - LF line endings for consistency across Windows/macOS/Linux.
  - Text-friendly handling for Godot scene/resource text files.
  - Optional commented Git LFS patterns for large binary assets.
- `.github/ISSUE_TEMPLATE/jam-task.md` to standardize jam tasks/bugs/features.
- `.github/ISSUE_TEMPLATE/config.yml` with blank issues disabled so the team uses the template.

## Host setup

1. Create a remote repo from this template (or push this folder as a new repo).
2. Confirm these files exist in the root:
   - `.gitignore`
   - `.gitattributes`
  - `.github/ISSUE_TEMPLATE/jam-task.md`
  - `.github/ISSUE_TEMPLATE/config.yml`
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

## Jam start flow (fork and rename)

When the jam starts, create a new repo from this template and name it after your actual jam game/team.

Option A (GitHub website):

1. Open this template repo.
2. Click **Fork**.
3. Rename the fork to your jam project name.
4. Make sure the fork visibility/settings are what your team needs.

Option B (GitHub CLI):

```bash
gh repo fork <template-owner>/godot-proj-git-template --clone=false --remote=false
```

Then rename the fork in GitHub settings, or create a new repo and push this template into it.

## First-time setup in the new fork

Do these once in the newly forked/renamed repo.

1. Ensure required label exists in the new fork:

```bash
gh label create jam-task --color 0E8A16 --description "Game jam task" || true
```

2. Clone the new fork and enter it:

```bash
git clone <your-new-fork-url>
cd <your-new-fork-folder>
```

3. Set line endings once (Windows):

```bash
git config --global core.autocrlf input
```

4. If the repo uses LFS:

```bash
git lfs install
git lfs pull
```

5. Open the forked project in Godot 4.7.1 LTS.
6. Let Godot initialize project-local data.
7. Run `git status`.
8. Commit only intentional starter project files for the team (scenes, scripts, assets, project settings).
9. Do not commit generated local cache under `.godot/` (already ignored).
10. Push `main` so everyone else starts from the same baseline:

```bash
git add .
git commit -m "Initialize jam project baseline"
git push -u origin main
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
