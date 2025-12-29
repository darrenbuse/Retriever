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
    # Use mock bin without gh
    create_mock "git"
    create_mock "fzf"
    export PATH="$MOCK_BIN"

    run "$RETRIEVER" clone
    [ "$status" -eq 1 ]
    [[ "$output" == *"gh (GitHub CLI)"* ]]
}

@test "fails when fzf is missing" {
    create_mock "git"
    create_mock "gh"
    # gh auth status needs to succeed
    cat > "$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
    exit 0
fi
echo "mock gh"
EOF
    chmod +x "$MOCK_BIN/gh"
    export PATH="$MOCK_BIN"

    run "$RETRIEVER" clone
    [ "$status" -eq 1 ]
    [[ "$output" == *"fzf (fuzzy finder)"* ]]
}

@test "fails when git is missing" {
    create_mock "fzf"
    create_mock "gh"
    export PATH="$MOCK_BIN"

    run "$RETRIEVER" clone
    [ "$status" -eq 1 ]
    [[ "$output" == *"git"* ]]
}

@test "fails when gh is not authenticated" {
    create_mock "git"
    create_mock "fzf"
    create_failing_mock "gh" "not logged in"
    export PATH="$MOCK_BIN"

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

    run "$RETRIEVER" install
    [ "$status" -eq 0 ]

    grep -q "Retriever" "$HOME/.bashrc"
}

@test "install prefers bash_profile over bashrc when it exists" {
    export SHELL="/bin/bash"
    touch "$HOME/.bash_profile"
    touch "$HOME/.bashrc"

    run "$RETRIEVER" install
    [ "$status" -eq 0 ]

    grep -q "Retriever" "$HOME/.bash_profile"
    ! grep -q "Retriever" "$HOME/.bashrc"
}

@test "install is idempotent - doesn't duplicate entries" {
    export SHELL="/bin/zsh"
    touch "$HOME/.zshrc"

    # Run install twice
    run "$RETRIEVER" install
    [ "$status" -eq 0 ]

    run "$RETRIEVER" install
    [ "$status" -eq 0 ]
    [[ "$output" == *"already exists"* ]]

    # Count occurrences - should only be 1
    count=$(grep -c "Retriever" "$HOME/.zshrc")
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
