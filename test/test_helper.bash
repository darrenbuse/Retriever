# Test helper functions for Retriever tests

# Get the directory containing the retriever script
RETRIEVER_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
RETRIEVER="$RETRIEVER_DIR/retriever"

# Create a temporary directory for test fixtures
setup_test_env() {
    export TEST_DIR="$(mktemp -d)"
    export TEST_REPOS_DIR="$TEST_DIR/repos"
    export RETRIEVER_REPOS_DIR="$TEST_REPOS_DIR"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"
    mkdir -p "$TEST_REPOS_DIR"

    # Create mock bin directory
    export MOCK_BIN="$TEST_DIR/mock_bin"
    mkdir -p "$MOCK_BIN"

    # Save original PATH
    export ORIGINAL_PATH="$PATH"
}

teardown_test_env() {
    # Restore PATH
    export PATH="$ORIGINAL_PATH"

    # Clean up temp directory
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Create a mock command that succeeds
create_mock() {
    local cmd="$1"
    local output="${2:-}"
    local exit_code="${3:-0}"

    cat > "$MOCK_BIN/$cmd" <<EOF
#!/usr/bin/env bash
echo "$output"
exit $exit_code
EOF
    chmod +x "$MOCK_BIN/$cmd"
}

# Create a mock command that fails
create_failing_mock() {
    local cmd="$1"
    local output="${2:-}"

    create_mock "$cmd" "$output" 1
}

# Remove a mock (simulate missing dependency)
remove_mock() {
    local cmd="$1"
    rm -f "$MOCK_BIN/$cmd"
}

# Create a fake git repo in test repos dir
create_fake_repo() {
    local name="$1"
    local branch="${2:-main}"
    local dir="$TEST_REPOS_DIR/$name"

    mkdir -p "$dir"
    cd "$dir"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > README.md
    git add .
    git commit -m "Initial commit" --quiet

    if [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
        git checkout -b "$branch" --quiet
    fi

    cd - > /dev/null
}

# Create a fake repo with uncommitted changes
create_dirty_repo() {
    local name="$1"
    create_fake_repo "$name"
    echo "dirty" >> "$TEST_REPOS_DIR/$name/README.md"
}

# Create a worktree from an existing repo
create_fake_worktree() {
    local main_repo="$1"
    local wt_name="$2"
    local branch="${3:-feature-test}"
    local main_dir="$TEST_REPOS_DIR/$main_repo"
    local wt_dir="$TEST_REPOS_DIR/$wt_name"

    cd "$main_dir"
    git worktree add "$wt_dir" -b "$branch" --quiet
    cd - > /dev/null
}
