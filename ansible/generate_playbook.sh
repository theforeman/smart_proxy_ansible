#!/bin/sh

ANSIBLE_OPTIONS=""

function die() {
    echo "ERROR: $1" >&2
    exit 1
}

function generate_header() {
    cat >"$1"<<-END
---
- hosts: all
  roles:
END
}

function generate_roles() {
    local playbook="$1"
    local roles=""
    for role in $(find /etc/ansible/roles/* roles/* -maxdepth 0 -type d); do
        roles="$roles $(basename "$role")"
    done

    [ "$roles" = "" ] && die "No roles found"

    for role in $(echo "$roles" | tr ' ' '\n' | sort | uniq); do
        cat >> "$playbook" <<-END
    - role: $role
      when: '"$role" in foreman_roles'
END
    done
}

function generate_playbook() {
    generate_header "$1"
    generate_roles "$1"
}

function run_playbook() {
    ansible-playbook $ANSIBLE_OPTIONS "$1"
}

RUN=0

while getopts Ro: opt; do
    case $opt in
        R)
            RUN=1
            ;;
        o)
            ANSIBLE_OPTIONS="$OPTARG"
            ;;
        *)
            die "Unknown option '-$OPTARG'"
            ;;
    esac
done
shift $((OPTIND-1))

[ $# -eq 0 ] && die "Playbook name is required"

generate_playbook "$1"

[ $RUN -eq 1 ] && run_playbook "$1"
