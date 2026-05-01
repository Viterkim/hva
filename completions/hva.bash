# bash completion for hva
# Source this file or drop it in /etc/bash_completion.d/hva
# e.g. in ~/.bashrc: source /path/to/hva/completions/hva.bash

_hva_complete() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"

  # Flags that take a value — suppress further flag completion after them
  case "$prev" in
    --msg|--prompt)          return ;;
    --prompt-file)           COMPREPLY=($(compgen -f -- "$cur")); return ;;
    --diff-review)           return ;;
    --diff-review-branch)    return ;;
    --loop|--loop-init|--loop-stop|--loop-status) return ;;
    --runtime-state)         return ;;
  esac

  local flags=(
    --local
    --bash
    --new
    --new-hard
    --new-nuke-ws
    --msg
    --prompt
    --prompt-file
    --diff-review
    --diff-review-branch
    --diff-review-main
    --diff-review-staged
    --diff-review-unstaged
    --diff-review-all
    --stop
    --start-searxng
    --stop-searxng
    --update
    --reset-pi-cache
    --cleanup-docker
    --runtime-state
    --daemon
    --healthcheck
    --llama-cpp-update
    --llama-cpp-logs-full
    --build-docker-prison
    --check-versions
    --loop
    --loop-init
    --loop-stop
    --loop-status
    --help
  )

  COMPREPLY=($(compgen -W "${flags[*]}" -- "$cur"))
}

complete -F _hva_complete hva
