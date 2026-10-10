#!/usr/bin/env bats
@test "planted-abspath" {
    run /opt/homebrew/bin/gem update --system
    run /usr/local/bin/brew upgrade
    run sudo /opt/homebrew/bin/gem install foo
    run sudo /opt/homebrew/bin/brew update
}
