#!/usr/bin/env bash
# vim: set expandtab tabstop=4 shiftwidth=4 softtabstop=4:
# Copyright © 2023 Carl Bennett
# <https://github.com/carlbennett/carlbennett-infrastructure>
set -e -o pipefail

# Only display motd if tty and not sudoing as root
#[ "$PS1" ] && [ "$EUID" -ne 0 ] || return 0

# Run the entire function in its own subshell.
#
# The local keyword in functions prevents inheriting values.
# The subshell prevents exporting them.
#
# Technically, local prevents exporting too. Only the vars that
# could be used before initialized need to be declared local to
# prevent the parent env from leaking into it.
(
    MOTD_DEFAULT_VALUE='-'

    function show_motd() {

        local MOTD_PRIVATE_IP \
              MOTD_PUBLIC_IP

        MOTD_OS="$(cat /etc/system-release | sed 's/ release / /g' 2>/dev/null)"
        [ -z "${MOTD_OS}" ] && MOTD_OS="$(cat /etc/os-release | grep 'PRETTY_NAME' | cut -d\" -f2 2>/dev/null)"

        MOTD_OS_COLOR_B="$(cat /etc/os-release | grep 'ANSI_COLOR' | cut -d\" -f2 2>/dev/null)"

        MOTD_HOSTNAME="$(hostnamectl --static 2>/dev/null)"
        if [ -z "${MOTD_HOSTNAME}" ]; then
            MOTD_HOSTNAME="$(hostnamectl --transient 2>/dev/null)"
            if [ -z "${MOTD_HOSTNAME}" ]; then
                MOTD_HOSTNAME="$(hostname 2>/dev/null)"
            fi
        fi

        if [ -z "${MOTD_PRIVATE_IP}" ]; then
            MOTD_PRIVATE_IP="$(ip -o -4 addr show scope global primary | cut -d\  -f7 | cut -d/ -f1 2>/dev/null)"
        fi

        if [ -z "${MOTD_PUBLIC_IP}" ]; then
            MOTD_PUBLIC_IP="$(ip -o -6 addr show scope global primary | cut -d\  -f7 | cut -d/ -f1 | sed -n 1p 2>/dev/null)"
        fi

        MOTD_GATEWAY_IP="$(curl -fsL4 --connect-timeout 3 --max-time 3 -H'Accept:text/plain;q=0.9,text/*;q=0.1' 'http://tx-us-ping.vultr.com/' | grep -oP '\<a\shref=.+\sid="useripv4">(.+)\</a\>' | grep -oP '>(.+)<' | tr -d '><\n')"
        MOTD_TOTAL_CPUS="$(grep processor /proc/cpuinfo | wc -l 2>/dev/null)"
        MOTD_TOTAL_DISKS="$(df -h | grep '^\/dev\/' | wc -l 2>/dev/null)"
        MOTD_TOTAL_DISK_USED="$(df -h | grep '^\/dev/' | sed -n 1p | awk '{print $3, "/", $2, "(" $5 ")"}' 2>/dev/null)"
        MOTD_TOTAL_MEMORY="$(free -h | awk '{print $2}' | sed -n 2p 2>/dev/null)"

        if [ "${MOTD_PUBLIC_IP}" = "${MOTD_GATEWAY_IP}" ]; then
            MOTD_GATEWAY_IP=''
        fi

        [ -z "${MOTD_GATEWAY_IP}" ] && MOTD_GATEWAY_IP="${MOTD_DEFAULT_VALUE}"
        [ -z "${MOTD_HOSTNAME}" ] && MOTD_HOSTNAME="${MOTD_DEFAULT_VALUE}"
        [ -z "${MOTD_OS_COLOR_B}" ] && MOTD_OS_COLOR_B="0;32"
        [ -z "${MOTD_OS}" ] && MOTD_OS="${MOTD_DEFAULT_VALUE}"
        [ -z "${MOTD_PRIVATE_IP}" ] && MOTD_PRIVATE_IP="${MOTD_DEFAULT_VALUE}"
        [ -z "${MOTD_PUBLIC_IP}" ] && MOTD_PUBLIC_IP="${MOTD_DEFAULT_VALUE}"
        [ -z "${MOTD_TOTAL_CPUS}" ] && MOTD_TOTAL_CPUS="${MOTD_DEFAULT_VALUE}"
        [ -z "${MOTD_TOTAL_DISKS}" ] && MOTD_TOTAL_DISKS="${MOTD_DEFAULT_VALUE}"
        [ -z "${MOTD_TOTAL_DISK_USED}" ] && MOTD_TOTAL_DISK_USED="${MOTD_DEFAULT_VALUE}"
        [ -z "${MOTD_TOTAL_MEMORY}" ] && MOTD_TOTAL_MEMORY="${MOTD_DEFAULT_VALUE}"

        MOTD_OS_COLOR_A="1;${MOTD_OS_COLOR_B:2}"

        MOTD_PADDING='22' # Arbitrary length
        MOTD_PADDING_OS="$((${MOTD_PADDING}-${#MOTD_OS_COLOR_B}))"

        printf "$(tput sgr0;tput setaf 124)%-$(tput cols)s$(tput sgr0)\n$(tput sgr0;tput setaf 124)%-$(tput cols)s$(tput sgr0)\n%-$(tput cols)s\n" \
            "This system is operated and monitored by a private owner." "All unauthorized uses prohibited." ""
        printf "    %sTotal CPUs: %-${MOTD_PADDING}s  " "$(tput bold;tput setaf 48)" "$(tput sgr0;tput setaf 78;echo ${MOTD_TOTAL_CPUS})"
        printf "%sGateway IP: %s\n" "$(tput bold;tput setaf 250)" "$(tput sgr0;tput setaf 246;echo ${MOTD_GATEWAY_IP})"
        printf "    %sTotal Mem.: %-${MOTD_PADDING}s  " "$(tput bold;tput setaf 48)" "$(tput sgr0;tput setaf 78;echo ${MOTD_TOTAL_MEMORY})"
        printf " %sPublic IP: %s\n" "$(tput bold;tput setaf 250)" "$(tput sgr0;tput setaf 246;echo ${MOTD_PUBLIC_IP})"
        printf "   %sTotal Disks: %-${MOTD_PADDING}s  " "$(tput bold;tput setaf 48)" "$(tput sgr0;tput setaf 78;echo ${MOTD_TOTAL_DISKS})"
        printf "%sPrivate IP: %s\n" "$(tput bold;tput setaf 250)" "$(tput sgr0;tput setaf 246;echo ${MOTD_PRIVATE_IP})"
        printf "%sRoot Vol. Used: %s\n" "$(tput bold;tput setaf 48)" "$(tput sgr0;tput setaf 78;echo ${MOTD_TOTAL_DISK_USED})"
        printf "%sOS: %-${MOTD_PADDING_OS}s  " "$(echo -en "\033[${MOTD_OS_COLOR_A}m")" "$(echo -en "\033[${MOTD_OS_COLOR_B}m${MOTD_OS}")"
        printf "%sHostname: %-${MOTD_PADDING}s\n" "$(tput bold;tput setaf 216)" "$(tput sgr0;tput setaf 180;echo ${MOTD_HOSTNAME})"
        printf "$(tput sgr0)%-$(tput cols)s\n" ""
    }

    show_motd || true
)
