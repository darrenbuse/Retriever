#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# =============================================================================
# Help / Usage Tests
# =============================================================================

@test "no arguments shows usage" {
    run "$RETRIEVER"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Retriever - Fetches your repos like a good dog"* ]]
    [[ "$output" == *"clone"* ]]
    [[ "$output" == *"fetch"* ]]
    [[ "$output" == *"list"* ]]
    [[ "$output" == *"install"* ]]
}

@test "help command shows usage" {
    run "$RETRIEVER" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: retriever"* ]]
}

@test "unknown command shows error" {
    run "$RETRIEVER" foobar
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

# =============================================================================
# Dependency Check Tests
# =============================================================================

@test "fails when gh is missing" {
    # Use mock bin without gh - include system paths for basic utilities
    create_mock "git"
    create_mock "fzf"
    export PATH="$MOCK_BIN:/usr/bin:/bin"

    run "$RETRIEVER" clone
    [ "$status" -eq 1 ]
    [[ "$output" == *"gh (GitHub CLI)"* ]]
}

@test "fails when fzf is missing" {
    create_mock "git"
    # gh auth status needs to succeed
    cat > "$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
    exit 0
fi
echo "mock gh"
EOF
    chmod +x "$MOCK_BIN/gh"
    export PATH="$MOCK_BIN:/usr/bin:/bin"

    run "$RETRIEVER" clone
    [ "$status" -eq 1 ]
    [[ "$output" == *"fzf (fuzzy finder)"* ]]
}

@test "fails when git is missing" {
    # Skip if system git exists in base paths (can't hide it)
    if PATH="/usr/bin:/bin" command -v git &>/dev/null; then
        skip "Cannot hide system git - test requires environment without git"
    fi

    create_mock "fzf"
    create_mock "gh"
    export PATH="$MOCK_BIN:/usr/bin:/bin"

    run "$RETRIEVER" clone
    [ "$status" -eq 1 ]
    [[ "$output" == *"git"* ]]
}

@test "fails when gh is not authenticated" {
    create_mock "git"
    create_mock "fzf"
    create_failing_mock "gh" "not logged in"
    export PATH="$MOCK_BIN:/usr/bin:/bin"

    run "$RETRIEVER" clone
    [ "$status" -eq 1 ]
    [[ "$output" == *"Not authenticated"* ]]
}

# =============================================================================
# List Command Tests
# =============================================================================

@test "list fails when repos dir doesn't exist" {
    export RETRIEVER_REPOS_DIR="/nonexistent/path"
    run "$RETRIEVER" list
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "list shows repos with branch info" {
    create_fake_repo "test-repo" "main"
    create_fake_repo "another-repo" "develop"

    run "$RETRIEVER" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-repo"* ]]
    [[ "$output" == *"[main]"* ]]
    [[ "$output" == *"another-repo"* ]]
    [[ "$output" == *"[develop]"* ]]
    [[ "$output" == *"Total: 2 repos"* ]]
}

@test "list shows modified status for dirty repos" {
    create_dirty_repo "dirty-repo"

    run "$RETRIEVER" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"dirty-repo"* ]]
    [[ "$output" == *"(modified)"* ]]
}

@test "list works with empty repos directory" {
    run "$RETRIEVER" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total: 0 repos"* ]]
}

@test "list ignores non-git directories" {
    mkdir -p "$TEST_REPOS_DIR/not-a-repo"
    create_fake_repo "real-repo"

    run "$RETRIEVER" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"real-repo"* ]]
    [[ "$output" == *"not-a-repo"* ]]
    [[ "$output" == *"(not a git repo)"* ]]
}

# =============================================================================
# Install Command Tests
# =============================================================================

@test "install creates zshrc entry for zsh users" {
    export SHELL="/bin/zsh"
    touch "$HOME/.zshrc"

    # Remove script dir from PATH so install doesn't think it's already there
    local script_dir
    script_dir="$(cd "$(dirname "$RETRIEVER")" && pwd)"
    export PATH="${PATH//$script_dir:/}"
    export PATH="${PATH//:$script_dir/}"

    run "$RETRIEVER" install
    [ "$status" -eq 0 ]
    [[ "$output" == *"Added to"* ]]

    # Check that PATH export was added
    grep -q "Retriever" "$HOME/.zshrc"
    grep -q "export PATH" "$HOME/.zshrc"
}

@test "install creates bashrc entry for bash users" {
    export SHELL="/bin/bash"
    touch "$HOME/.bashrc"

    # Remove script dir from PATH
    local script_dir
    script_dir="$(cd "$(dirname "$RETRIEVER")" && pwd)"
    export PATH="${PATH//$script_dir:/}"
    export PATH="${PATH//:$script_dir/}"

    run "$RETRIEVER" install
    [ "$status" -eq 0 ]

    grep -q "Retriever" "$HOME/.bashrc"
}

@test "install prefers bash_profile over bashrc when it exists" {
    export SHELL="/bin/bash"
    touch "$HOME/.bash_profile"
    touch "$HOME/.bashrc"

    # Remove script dir from PATH
    local script_dir
    script_dir="$(cd "$(dirname "$RETRIEVER")" && pwd)"
    export PATH="${PATH//$script_dir:/}"
    export PATH="${PATH//:$script_dir/}"

    run "$RETRIEVER" install
    [ "$status" -eq 0 ]

    grep -q "Retriever" "$HOME/.bash_profile"
    ! grep -q "Retriever" "$HOME/.bashrc"
}

@test "install is idempotent - doesn't duplicate entries" {
    export SHELL="/bin/zsh"
    touch "$HOME/.zshrc"

    # Remove script dir from PATH
    local script_dir
    script_dir="$(cd "$(dirname "$RETRIEVER")" && pwd)"
    export PATH="${PATH//$script_dir:/}"
    export PATH="${PATH//:$script_dir/}"

    # Run install twice
    run "$RETRIEVER" install
    [ "$status" -eq 0 ]

    run "$RETRIEVER" install
    [ "$status" -eq 0 ]
    [[ "$output" == *"already exists"* ]]

    # Count export PATH lines - should only be 1
    count=$(grep -c "export PATH" "$HOME/.zshrc")
    [ "$count" -eq 1 ]
}

# =============================================================================
# Directory Option Tests
# =============================================================================

@test "-d option changes repos directory" {
    local custom_dir="$TEST_DIR/custom_repos"
    mkdir -p "$custom_dir"

    run "$RETRIEVER" -d "$custom_dir" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"$custom_dir"* ]]
}

@test "--dir option changes repos directory" {
    local custom_dir="$TEST_DIR/custom_repos"
    mkdir -p "$custom_dir"

    run "$RETRIEVER" --dir "$custom_dir" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"$custom_dir"* ]]
}

# =============================================================================
# Fetch Command Tests (with repos, no fzf interaction)
# =============================================================================

@test "fetch fails when repos dir doesn't exist" {
    export RETRIEVER_REPOS_DIR="/nonexistent/path"

    # Need mocks for dependency check
    create_mock "git"
    create_mock "fzf"
    cat > "$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then exit 0; fi
EOF
    chmod +x "$MOCK_BIN/gh"
    export PATH="$MOCK_BIN:$PATH"

    run "$RETRIEVER" fetch
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "fetch fails when no git repos found" {
    mkdir -p "$TEST_REPOS_DIR/not-a-repo"

    # Need mocks for dependency check
    cat > "$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then exit 0; fi
EOF
    chmod +x "$MOCK_BIN/gh"
    create_mock "fzf"
    export PATH="$MOCK_BIN:$PATH"

    run "$RETRIEVER" fetch
    [ "$status" -eq 1 ]
    [[ "$output" == *"No git repos found"* ]]
}

# =============================================================================
# Multi-Selection Clone Tests
# =============================================================================

@test "clone processes all selected repos not just one" {
    # Create mock gh that returns repos and tracks clone calls
    cat > "$MOCK_BIN/gh" <<'GHEOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
    exit 0
fi
if [[ "$1" == "repo" && "$2" == "list" ]]; then
    echo -e "user/repo1\tDescription 1"
    echo -e "user/repo2\tDescription 2"
    echo -e "user/repo3\tDescription 3"
    exit 0
fi
if [[ "$1" == "repo" && "$2" == "clone" ]]; then
    # Track which repos were cloned
    echo "$3" >> "$MOCK_BIN/cloned_repos.log"
    mkdir -p "$3"
    exit 0
fi
exit 1
GHEOF
    chmod +x "$MOCK_BIN/gh"

    # Create mock fzf that returns multiple selections
    cat > "$MOCK_BIN/fzf" <<'FZFEOF'
#!/usr/bin/env bash
# Simulate selecting all 3 repos
echo -e "user/repo1\tDescription 1"
echo -e "user/repo2\tDescription 2"
echo -e "user/repo3\tDescription 3"
FZFEOF
    chmod +x "$MOCK_BIN/fzf"

    create_mock "git" ""
    export PATH="$MOCK_BIN:$PATH"

    # Clear any previous log
    rm -f "$MOCK_BIN/cloned_repos.log"

    run "$RETRIEVER" clone

    # Check that all 3 repos were cloned
    [ -f "$MOCK_BIN/cloned_repos.log" ]
    local clone_count
    clone_count=$(wc -l < "$MOCK_BIN/cloned_repos.log" | tr -d ' ')
    [ "$clone_count" -eq 3 ]
}

# =============================================================================
# Worktree Detection Tests
# =============================================================================

@test "list recognizes worktrees as git repos" {
    create_fake_repo "main-repo"
    create_fake_worktree "main-repo" "main-repo-feature" "feature-branch"

    run "$RETRIEVER" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"main-repo"* ]]
    [[ "$output" == *"main-repo-feature"* ]]
    [[ "$output" == *"[feature-branch]"* ]]
    [[ "$output" == *"(worktree)"* ]]
}

@test "list shows worktree count in total" {
    create_fake_repo "main-repo"
    create_fake_worktree "main-repo" "main-repo-feature"

    run "$RETRIEVER" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 repos (1 worktrees)"* ]]
}

@test "list does not mark main repos as worktrees" {
    create_fake_repo "main-repo"

    run "$RETRIEVER" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"main-repo"* ]]
    [[ "$output" != *"(worktree)"* ]]
}

# =============================================================================
# Worktree Subcommand Tests
# =============================================================================

@test "worktree command shows usage" {
    run "$RETRIEVER" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"worktree"* ]]
    [[ "$output" == *"list"* ]]
    [[ "$output" == *"add"* ]]
    [[ "$output" == *"remove"* ]]
}

@test "worktree list shows no worktrees when none exist" {
    create_fake_repo "main-repo"

    run "$RETRIEVER" worktree list
    [ "$status" -eq 0 ]
    [[ "$output" == *"No worktrees found"* ]]
}

@test "worktree list shows existing worktrees" {
    create_fake_repo "main-repo"
    create_fake_worktree "main-repo" "main-repo-feature" "feature-xyz"

    run "$RETRIEVER" worktree list
    [ "$status" -eq 0 ]
    [[ "$output" == *"main-repo"* ]]
    [[ "$output" == *"main-repo-feature"* ]]
    [[ "$output" == *"[feature-xyz]"* ]]
}

@test "worktree unknown subcommand shows error" {
    run "$RETRIEVER" worktree foobar
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown worktree subcommand"* ]]
}

@test "worktree defaults to list" {
    create_fake_repo "main-repo"

    run "$RETRIEVER" worktree
    [ "$status" -eq 0 ]
    [[ "$output" == *"Worktrees in"* ]]
}
