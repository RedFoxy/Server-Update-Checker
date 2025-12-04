#!/usr/bin/env bash

set -Eeuo pipefail

VERSION="1.2.2"
SSH_OPT="-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
SUBJ="Servers with available updates"
VERBOSE=0

REPO_URL="https://github.com/RedFoxy/Server-Update-Checker"
RAW_SCRIPT_URL="https://raw.githubusercontent.com/RedFoxy/Server-Update-Checker/main/server-update-check.sh"

hosts=(
  host1
  host2
  host3
  hostN
)

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [HOST ...]
  -h, --help           Show this help message and exit
  -v, --verbose        Verbose output
  -l, --list           List configured hosts and exit
  -a, --all            Check all configured hosts
  -n, --dry-run        Do not clean caches or send notifications, just simulate
      --no-clean       Do not run remote cache cleanup
      --strict         Fail if an unknown host is specified
  -V, --check-version  Check local version against GitHub and exit

  HOST [HOST2 ...]     Check only the given hosts (implies -v, host or user@host)

Examples:
  $(basename "$0")                # check all hosts silently
  $(basename "$0") -v             # check all hosts with verbose output
  $(basename "$0") -l             # show configured hosts and exit
  $(basename "$0") host1          # check only 'host1'
  $(basename "$0") user@host1     # check using explicit user
  $(basename "$0") host1 host2    # check only 'host1' and 'host2'
  $(basename "$0") -n -a          # dry-run on all hosts (no notification)
  $(basename "$0") -V             # show local vs remote version
EOF
}

log() {
  if [ "${VERBOSE:-0}" -eq 1 ]; then
    printf '%s\n' "$*"
  fi
  return 0
}

log_error() {
  [[ $# -eq 0 ]] && return
  local msg="$*"
  if [[ -n "${ERRORS:-}" ]]; then
    ERRORS+=$'\n'"$msg"
  else
    ERRORS="$msg"
  fi
}

ssh_ok() {
  local host="$1"
  ssh $SSH_OPT "$host" true >/dev/null 2>&1
}

remote_manager='
detect_pm() {
  command -v apt-get >/dev/null 2>&1 && { echo apt;    return; }
  command -v dnf     >/dev/null 2>&1 && { echo dnf;    return; }
  command -v yum     >/dev/null 2>&1 && { echo yum;    return; }
  command -v apk     >/dev/null 2>&1 && { echo apk;    return; }
  command -v zypper  >/dev/null 2>&1 && { echo zypper; return; }
  command -v pacman  >/dev/null 2>&1 && { echo pacman; return; }
  echo unknown
}
pm=$(detect_pm)
case "$pm" in
  apt)
    apt-get update >/dev/null 2>&1 || true
    c=$(apt-get -s -o Debug::NoLocking=true upgrade 2>/dev/null | awk "/^Inst /{c++} END{print c+0}")
    ;;
  dnf)
    out=$(dnf -q --refresh check-update 2>/dev/null || true)
    c=$(printf "%s\n" "$out" | awk "NF && \$1 !~ /^(Last|Obsoleting|Security|Upgrading)$/ && \$0 !~ /^$/ {print \$1}" | wc -l)
    ;;
  yum)
    out=$(yum -q check-update 2>/dev/null || true)
    c=$(printf "%s\n" "$out" | awk "NF && \$1 !~ /^(Loaded|Obsoleting|Security)$/ && \$0 !~ /^$/ {print \$1}" | wc -l)
    ;;
  apk)
    apk update >/dev/null 2>&1 || true
    c=$(apk version -l "<" 2>/dev/null | wc -l | awk "{print \$1+0}")
    ;;
  zypper)
    zypper -q refresh >/dev/null 2>&1 || true
    c=$(zypper -q lu 2>/dev/null | awk "NR>2{print}" | wc -l)
    ;;
  pacman)
    if command -v checkupdates >/dev/null 2>&1; then
      c=$(checkupdates 2>/dev/null | wc -l)
    else
      pacman -Sy >/dev/null 2>&1 || true
      c=$(pacman -Sup --noconfirm 2>/dev/null | grep -E "^[[:space:]]*http" | wc -l)
    fi
    ;;
  *)
    c=-1
    ;;
esac
printf "%s %s\n" "$pm" "$c"
'

remote_cleanup='
pm="$1"
case "$pm" in
  apt)
    apt-get clean >/dev/null 2>&1 || true
    apt-get autoclean >/dev/null 2>&1 || true
    ;;
  dnf)
    dnf -q clean all >/dev/null 2>&1 || true
    ;;
  yum)
    yum -q clean all >/dev/null 2>&1 || true
    ;;
  apk)
    :
    ;;
  zypper)
    zypper -q clean --all >/dev/null 2>&1 || true
    ;;
  pacman)
    pacman -Scc --noconfirm >/dev/null 2>&1 || true
    ;;
esac
'

fetch_url() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    return 1
  fi
}

get_remote_version() {
  local content
  if ! content="$(fetch_url "$RAW_SCRIPT_URL")"; then
    return 1
  fi
  printf '%s\n' "$content" | awk -F'"' '/^VERSION=/{print $2; exit}'
}

check_version() {
  printf 'Local version:  %s\n' "$VERSION"
  local remote_v
  if ! remote_v="$(get_remote_version)"; then
    printf 'Remote version: unknown (failed to fetch)\n'
    printf 'You can check manually at: %s\n' "$REPO_URL"
    exit 1
  fi
  if [[ -z "$remote_v" ]]; then
    printf 'Remote version: not found in remote script.\n'
    printf 'You can check manually at: %s\n' "$REPO_URL"
    exit 1
  fi
  printf 'Remote version: %s\n' "$remote_v"

  local cmp
  if [[ -z "$VERSION" || -z "$remote_v" ]]; then
    cmp=2
  else
    if [[ "$VERSION" == "$remote_v" ]]; then
      cmp=0
    else
      local max_v
      max_v="$(printf '%s\n' "$VERSION" "$remote_v" | sort -V | tail -n1)"

      if [[ "$max_v" == "$remote_v" ]]; then
        cmp=1
      else
        cmp=0
      fi
    fi
  fi

  if [[ $cmp -eq 0 && "$VERSION" == "$remote_v" ]]; then
    printf 'Status: up to date.\n'
  elif [[ $cmp -eq 1 ]]; then
    printf 'Status: update available.\n'
    printf 'Download the latest version from: %s\n' "$REPO_URL"
  else
    printf 'Status: unable to determine.\n'
    printf 'Check manually at: %s\n' "$REPO_URL"
  fi
  exit 0
}

declare -a positional_hosts=()
SHOW_HOSTS=0
STRICT=0
DO_CLEAN=1
DRY_RUN=0
CHECK_VERSION_FLAG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--verbose)
      VERBOSE=1
      ;;
    -l|--list)
      SHOW_HOSTS=1
      ;;
    -a|--all)
      positional_hosts=("${hosts[@]}")
      ;;
    -n|--dry-run)
      DRY_RUN=1
      DO_CLEAN=0
      VERBOSE=1
      ;;
    --no-clean)
      DO_CLEAN=0
      ;;
    --strict)
      STRICT=1
      ;;
    -V|--check-version)
      CHECK_VERSION_FLAG=1
      ;;
    --)
      shift
      positional_hosts+=("$@")
      break
      ;;
    -*)
      printf 'Unknown option: %s\n' "$1" >&2
      usage
      exit 2
      ;;
    *)
      positional_hosts+=("$1")
      ;;
  esac
  shift
done

if [[ $CHECK_VERSION_FLAG -eq 1 ]]; then
  check_version
fi

if [[ $SHOW_HOSTS -eq 1 ]]; then
  printf 'Configured hosts:\n'
  for h in "${hosts[@]}"; do
    printf '  %s\n' "$h"
  done
  exit 0
fi

if [ "${#positional_hosts[@]}" -gt 0 ]; then
  VERBOSE=1
fi

declare -a target_hosts=()
if [ "${#positional_hosts[@]}" -gt 0 ]; then
  target_hosts=("${positional_hosts[@]}")
else
  target_hosts=("${hosts[@]}")
fi

declare -a UPD_LINES=()
ERRORS=""
TOTAL_UPDATES=0

if [ "$VERBOSE" -eq 1 ]; then
  log "Hosts to check: ${#target_hosts[@]}"
  if [[ $DRY_RUN -eq 1 ]]; then
    log "*** DRY-RUN ENABLED: no caches will be cleaned, no notifications will be sent. ***"
  fi
fi

for host in "${target_hosts[@]}"; do
  if [[ $STRICT -eq 1 && ! " ${hosts[*]} " =~ " ${host} " ]]; then
    printf "Error: '%s' is not in the configured host list (strict mode).\n" "$host" >&2
    exit 1
  fi

  if ssh_ok "$host"; then
    log ">> $host: connection OK, detecting package manager..."
    result="$(ssh $SSH_OPT "$host" "$remote_manager" 2>/dev/null || true)"
    pm="${result%% *}"
    count_str="${result#* }"

    if [[ -z "${pm:-}" || -z "${count_str:-}" || ! "$count_str" =~ ^-?[0-9]+$ || "$pm" == "unknown" || "$count_str" -lt 0 ]]; then
      log "!! $host: count not available (pm=$pm, count=$count_str)"
      log_error "!! $host: count not available (pm=$pm, count=$count_str)"
      continue
    fi

    if [ "$count_str" -gt 0 ]; then
      log "-- $host: updates = $count_str (pm: $pm)"
      UPD_LINES+=("$host (${count_str})")
      TOTAL_UPDATES=$((TOTAL_UPDATES + count_str))
    else
      log "-- $host: no updates (pm: $pm)"
    fi

    if [[ $DO_CLEAN -eq 1 && $DRY_RUN -eq 0 ]]; then
      ssh $SSH_OPT "$host" "$remote_cleanup" "$pm" >/dev/null 2>&1 || true
    fi
  else
    log "!! $host: connection failed"
    log_error "!! $host: connection failed"
  fi
done

if [ "${#UPD_LINES[@]}" -gt 0 ]; then
  BODY=""
  for line in "${UPD_LINES[@]}"; do
    BODY+="- ${line}"$'\n'
  done
  BODY+="Total upgradable packages: ${TOTAL_UPDATES}"$'\n'

  if [[ -n "$ERRORS" ]]; then
    BODY+=$'\n'"$ERRORS"
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    printf '*** DRY-RUN: no notification sent. This is what would be sent: ***\n'
    printf '%s\n' "$BODY"
  else
#    Here you can integrate your own notification system. I use another project of mine called Send-Notify, which you can find in my GitHub repository.
#    Example: /opt/bin/sendnotify.sh "${BODY}" -s "${SUBJ}" -t telegram
  fi
else
  if [[ $DRY_RUN -eq 1 ]]; then
    log "DRY-RUN: no updates found, no notification would be sent."
  else
    log "No updates available. No notification sent."
  fi
fi   Example: /opt/bin/sendnotify.sh "${BODY}" -s "${SUBJ}" -t telegram
