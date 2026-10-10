#!/usr/bin/env bats
@test "planted-payload" {
    eval "sudo gem update --system"
    run bash -c "brew upgrade"
    sh -c 'sudo /opt/homebrew/bin/gem update --system'
    zsh -c "gem update --system"
    exec "sudo /opt/homebrew/bin/brew upgrade"
}
