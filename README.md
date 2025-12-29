# Retriever

🐕 Fetches your repos like a good dog. Clone, sync, and rebase all your GitHub repos with one command.

## What it does

- **Clone**: Two-phase selection — first pick NEW repos to clone, then optionally remove existing ones
- **Fetch**: Select which repos to fetch and rebase (interactive)
- **List**: Shows all repos with their current branch and status
- **Install**: Adds retriever to your PATH automatically

## Dependencies

- `gh` — GitHub CLI
- `fzf` — fuzzy finder for interactive selection
- `git`

```bash
brew install gh fzf git
gh auth login
```

## Installation

```bash
# Clone this repo
gh repo clone darrenbuse/Retriever ~/Retriever

# Run install to add to PATH
~/Retriever/retriever install

# Source your shell config (or restart terminal)
source ~/.zshrc  # or ~/.bashrc
```

## Usage

```bash
# Select repos to clone + optionally remove existing
retriever clone

# Select repos to fetch and rebase
retriever fetch

# List all repos with status
retriever list

# Clone to a specific directory
retriever clone -d ~/projects
```

## Configuration

Set `RETRIEVER_REPOS_DIR` to change the default directory for repos:

```bash
export RETRIEVER_REPOS_DIR="$HOME/projects"
```

Default is `~/repos`.

## How clone works

1. **Phase 1**: Shows repos you DON'T have locally — select which to clone
2. **Phase 2**: Shows repos you DO have locally — select any to remove (with confirmation)

## How fetch works

1. Shows all local repos with branch and status
2. Select which ones to fetch (Ctrl-A for all)
3. Fetches and rebases each one
4. Skips repos with uncommitted changes (won't touch your work)
5. Reports conflicts for manual handling

## Testing

Tests use [Bats](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

```bash
# Install bats
brew install bats-core

# Run tests
bats test/

# Or use the test runner
./test/run_tests.sh
```

CI runs on every push via GitHub Actions (Ubuntu + macOS).
