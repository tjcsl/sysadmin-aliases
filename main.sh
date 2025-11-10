if [ -z "$KEYBASE_PASSCARD_DIR" ]; then
  echo "Error: KEYBASE_PASSCARD_DIR is not set." >&2
  return 1
fi

if [ -z "$CSL_ANSIBLE_DIR" ]; then
  echo "Error: CSL_ANSIBLE_DIR is not set." >&2
  return 1
fi

PASSCARD_DIR="${KEYBASE_PASSCARD_DIR%/}/passwords"
CSL_ANSIBLE_DIR="${CSL_ANSIBLE_DIR%/}"

TEMP_RUNNER_FILE_DIR="${TEMP_RUNNER_FILE_DIR:-$HOME}"

raw-passcard() {
  if [ $# -ne 1 ]; then
    echo "Usage: raw-passcard <passcard-name>" >&2
    return 1
  fi
  output="${1%.txt.gpg}"
  gpg -d "$PASSCARD_DIR/$output.txt.gpg" 2>/dev/null
}

pp() {
  if [[ "$1" =~ ^(-h|--help)?$ ]]; then
    echo "Usage: pp <passcard-name>"
    echo "Copy a passcard to clipboard"
    return 0
  fi
  passcard="$(raw-passcard "$1")"
  # shellcheck disable=SC2181
  if [ $? -ne 0 ]; then
    echo "Error: Unable to decrypt passcard '$1'" >&2
    return 1
  fi
  copy <<< "$passcard"
}

p() {
  if [[ "$1" =~ ^(-h|--help)$ ]]; then
    echo "Fuzzy search for a passcard and copy it"
    return 0
  fi
  cd "$PASSCARD_DIR" || return 1
  passcard="$(fd | fzf)"
  [ -n "$passcard" ] && pp "$passcard"
}

j() {
  if [[ -z "$1" ]]; then
    cat <<EOF
Usage: j <hostname> <ssh args>
Copies the passcard for the given hostname and SSHes into it as root.
EOF
    return 0
  fi
  base="${1%.csl.tjhsst.edu}"
  base="${base%.tjhsst.edu}"
  if [[ "$base" == "borg"* || "$base" == "hpc"* ]]; then
    password="$(raw-passcard cluster)"
  elif [[ "$base" == "smith" || "$base" == "casey" ]]; then
    password="$(raw-passcard mail)"
  else
    password="$(raw-passcard "$base")"
  fi
  # shellcheck disable=SC2181
  if [[ "$?" -ne 0 ]]; then
    echo "Error: Unable to retrieve passcard for '$base'" >&2
    return 1
  fi
  if [[ "$1" != *".tjhsst.edu" ]]; then
    if [[ "$base" =~ ^(www|ipa|casey|smith) ]]; then
      set -- "$1.tjhsst.edu"
    else
      set -- "$1.csl.tjhsst.edu"
    fi
  fi
  url="$1"
  shift
  sshpass -p "$password" ssh "root@$url" "$@"
}


tjans() {
    NUM_FORKS="100"
    CONNECT_USER="root"
    PLAY="$1"
    SSH_PASS_NAME=""
    VAULT_PASS_NAME="ansible"

    CONN_FILE=$(printf "${TEMP_RUNNER_FILE_DIR%/}/.ansible-playbook-runner-%s.sh" "conn")
    VAULT_FILE=$(printf "${TEMP_RUNNER_FILE_DIR%/}/.ansible-playbook-runner-%s.sh" "vault")

    if [[ "$PLAY" == "" ]]
    then
        echo "Usage: tjans (playbook) [options]..."
        return
    fi

    if [[ "$PLAY" != "-h" ]] && [[ "$PLAY" != "--help" ]]
    then
        shift
    fi

    other_args=()

    while [[ $# -gt 0 ]]
    do
        case $1 in
            -h | --help)
                echo "Usage: tjans (playbook) [options]..."
                echo Run a tjCSL ansible play intelligently
                echo
                echo "  -p, --pass PASS                 Specify the name of the passcard file to use when connecting"
                echo "  -v, --vault, --vault-pass PASS  Specify the name of the vault passcard file (excluding \"_vault\") to use"
                echo "  -u, --user USERNAME             Specify the username to connect with"
                echo "  -f, --forks N                   Set the number of concurrent processes to use at once"
                echo
                echo "  ...any other valid ansible-playbook options are also permitted and will be passed to ansible"
                return
                ;;
            -p | --pass)
                SSH_PASS_NAME="$2"
                shift
                shift
                ;;
            -v | --vault | --vault-pass)
                VAULT_PASS_NAME="$2"
                shift
                shift
                ;;
            -u | --user)
                CONNECT_USER="$2"
                shift
                shift
                ;;
            -f | --forks)
                NUM_FORKS="$2"
                shift
                shift
                ;;
            --* | -*)
                other_args+=("$1")
                shift
                ;;
            *)
                other_args+=("$1")
                shift
                ;;
        esac
    done

    set -- "${other_args[@]}"

    sshpass=$(raw-passcard "$SSH_PASS_NAME")
    echo "#!/usr/bin/env bash" > "$CONN_FILE"
    echo "echo $sshpass" >> "$CONN_FILE"
    chmod +x "$CONN_FILE"

    vaultpass=$(raw-passcard "$VAULT_PASS_NAME"_vault)
    echo "#!/usr/bin/env bash" > "$VAULT_FILE"
    echo "echo $vaultpass" >> "$VAULT_FILE"
    chmod +x "$VAULT_FILE"

    echo "RUNNING COMMAND:"
    echo "    " ansible-playbook "$CSL_ANSIBLE_DIR"/"$PLAY".yml -i "$CSL_ANSIBLE_DIR"/hosts -f "$NUM_FORKS" -u "$CONNECT_USER" "$@"
    git -C "$CSL_ANSIBLE_DIR" pull
    ansible-playbook "$CSL_ANSIBLE_DIR"/"$PLAY".yml -i "$CSL_ANSIBLE_DIR"/hosts --connection-password-file "$CONN_FILE" \
      --vault-password-file "$VAULT_FILE" -f "$NUM_FORKS" -u "$CONNECT_USER" "$@"
}
