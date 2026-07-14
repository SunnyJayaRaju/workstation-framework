#!/usr/bin/env bats

@test "config directory exists" {
    source ./scripts/lib/config.sh

    run config_exists

    [ "$status" -eq 0 ]
}

@test "default configuration loads" {
    source ./scripts/lib/config.sh

    load_config

    [ "$INSTALL_DIR" = "$HOME/.local/bin" ]
    [ "$BACKUP_DIR" = "$HOME/.workstation/backups" ]
}