#!/bin/env bash
# # # # # # # # # # # # # # # #
# Reconnect to netctl profile #
# # # # # # # # # # # # # # # #

if [ $(id -u) != 0 ]; then
    echo "Must be root"
    exit 1;
fi

SCRIPT_NAME="$(basename "$0")"
usage()
{
echo "Uasge: $SCRIPT_NAME [ -p url ] PROFILE
     --help             show this help text.
  -p --ping=HOST        specify the ping target when checking connection.
"
}

echo_err()
{
    echo "$SCRIPT_NAME: $1" 1>&2
}

rfunblock() {
    blocks=$(rfkill list wlan --output HARD,SOFT | tail -n 1)

    if [ "${blocks[0]}" == "blocked" ]; then
        echo_err "wlan is blocked at hardware level, cannot connect to wifi"
        exit 1
    fi

    if [ "${blocks[1]}" == "blocked" ]; then
        rfkill unblock wlan
    fi

    # ensure that interface was unblocked
    rfkill list wlan | grep "yes" && echo_err "wlan interface could not be unblocked" && exit 1
}

# parse options and arguments
opts=$(getopt -qo "p" --long "help,ping" -- "$@")
eval set -- "${opts}"

ping_target="www.google.com"
while [ "$#" -gt 1 ]; do
    case "$1" in
        --help) usage
            exit 0
            ;;
        -p | --ping) ping_target="$2"
            shift
            ;;
    esac
    shift
done

echo "=== STOPPING ${1^^} ==="
netctl stop "$1"

echo "=== SETTING DOWN WIRELESS INTERFACES ==="
interfaces=($(iw dev | awk '$1=="Interface"{printf $2 " "}'))

for i in "${interfaces[@]}"; do
    if [ -z "$i" ]; then
        echo "warning: no interfaces found. recommend restart"
        exit
    fi
    ip link set "$i" down
done

echo "=== UNBLOCKING WLAN ==="
rfunblock

echo "=== STARTING ${1^^} ==="
netctl restart "$1"

echo "=== PINGING ${ping_target^^} ==="
until ping -c 1 "$ping_target"; do sleep 1; done
