# fish completion for hva
# Drop this file in ~/.config/fish/completions/hva.fish
# or symlink: ln -s /path/to/hva/completions/hva.fish ~/.config/fish/completions/hva.fish

complete -c hva -f

# General
complete -c hva -l local              -d "Start/reuse llama, open host Pi"
complete -c hva -l bash               -d "Shell in dev container (no llama wait)"
complete -c hva -l new                -d "Fresh Pi session (clears resume state)"
complete -c hva -l new-hard           -d "Fresh Pi session and recreate dev container"
complete -c hva -l new-nuke-ws        -d "Fresh Pi session and wipe workspace state"
complete -c hva -l msg            -r  -d "One-shot Pi message"
complete -c hva -l prompt         -r  -d "One-shot Pi prompt (alias for --msg)"
complete -c hva -l prompt-file    -rF -d "One-shot Pi prompt from file"

# Diff review
complete -c hva -l diff-review         -r -d "Review git diff from REV..HEAD"
complete -c hva -l diff-review-branch  -r -d "Review diff from merge-base(BRANCH, HEAD)..HEAD"
complete -c hva -l diff-review-main       -d "Review diff vs merge-base of main/master"
complete -c hva -l diff-review-staged     -d "Review staged git diff"
complete -c hva -l diff-review-unstaged   -d "Review unstaged git diff"
complete -c hva -l diff-review-all        -d "Review tracked + untracked diff"

# Services
complete -c hva -l stop            -d "Stop llama, searxng, and dev container"
complete -c hva -l start-searxng   -d "Start SearXNG helper container"
complete -c hva -l stop-searxng    -d "Stop SearXNG helper container"

# Maintenance
complete -c hva -l update             -d "Pull latest hva, refresh Pi config"
complete -c hva -l reset-pi-cache     -d "Clear cached Pi config/home"
complete -c hva -l cleanup-docker     -d "Show/prune Docker storage (--apply --volumes --global-build-cache)"
complete -c hva -l runtime-state  -r  -d "Print HVA state paths for workspace"
complete -c hva -l daemon             -d "Start llama server as background daemon"
complete -c hva -l healthcheck        -d "Compact llama health verdict"
complete -c hva -l llama-cpp-update   -d "Update pinned llama.cpp image digest"
complete -c hva -l llama-cpp-logs-full -d "Print full llama container logs"
complete -c hva -l build-docker-prison -d "Build dev image (--force to rebuild)"
complete -c hva -l check-versions     -d "Check pinned vs latest upstream versions"

# Loop
complete -c hva -l loop            -r -d "Run Pi loop mode using WORKSPACE/tasks.md"
complete -c hva -l loop-init       -r -d "Create tasks.md template in workspace root"
complete -c hva -l loop-stop       -r -d "Ask running loop to stop after this iteration"
complete -c hva -l loop-status     -r -d "Print current loop status"

# Help
complete -c hva -l help               -d "Show usage"
