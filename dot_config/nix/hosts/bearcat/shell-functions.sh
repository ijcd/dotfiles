# convenient shell functions

# quick navigation to git repo root
function cdroot() {
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ $? -eq 0 ]; then
        cd "$root"
    else
        echo "Not in a git repository"
        return 1
    fi
}
