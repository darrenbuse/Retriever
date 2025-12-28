# Retriever

🐕 Fetches your repos like a good dog. Clone, sync, and rebase all your GitHub repos with one command.

## What it does

- **Clone**: Presents all your GitHub repos in an interactive list (using fzf) — select which ones to clone
- **Fetch**: Fetches all repos and rebases cleanly where possible, reports conflicts for manual handling
- **List**: Shows all repos with their current branch and status

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
gh repo clone darrenbuse/Retriever

# Add to your PATH (or symlink to somewhere in your PATH)
export PATH="$PATH:$HOME/path/to/Retriever"
```

## Usage

```bash
# Select repos to clone (interactive)
retriever clone

# Fetch and rebase all repos
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

## How fetch works

1. Iterates through all git repos in the repos directory
2. Skips repos with uncommitted changes (won't touch your work)
3. Fetches from origin
4. Attempts rebase — if conflicts occur, aborts and reports them
5. Gives you a summary at the end

Repos with conflicts are listed so you can handle them manually.
