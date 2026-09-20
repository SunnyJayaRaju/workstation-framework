#!/usr/bin/env bats

load test_helper

@test "config directory exists" {
    source "${SCRIPTS_DIR}/lib/config.sh"

    run config_exists

    [ "$status" -eq 0 ]
}

@test "default configuration loads" {
    source "${SCRIPTS_DIR}/lib/config.sh"

    load_config

    [ "$INSTALL_DIR" = '$HOME/.local/bin' ]
    [ "$BACKUP_DIR" = '$HOME/.workstation/backups' ]
}