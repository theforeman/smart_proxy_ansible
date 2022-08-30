#!/bin/sh

[ -f "$ANSIBLE_ENVIRONMENT_FILE" ] && source "$ANSIBLE_ENVIRONMENT_FILE"
exec "$@"
