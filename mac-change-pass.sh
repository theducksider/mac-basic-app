#!/bin/bash

# Get all normal users (UID >= 500)
DYNAMIC_USERS=($(dscl . -list /Users UniqueID | awk '$2 >= 500 {print $1}'))

DEFAULT_PASS="Password12345"

# ---- Prompt for Administrator password with confirmation ----
MAX_RETRIES=3

for ((i=1; i<=MAX_RETRIES; i++)); do
  read -s -p "Enter NEW password for Administrator: " ADMINISTRATOR_PASS < /dev/tty
  echo
  read -s -p "Confirm NEW password for Administrator: " ADMINISTRATOR_PASS_CONFIRM < /dev/tty
  echo
  if [[ "$ADMINISTRATOR_PASS" == "$ADMINISTRATOR_PASS_CONFIRM" ]]; then
    break
  fi
  echo "âŒ Passwords do not match. Attempt $i of $MAX_RETRIES."
  if [[ $i -eq $MAX_RETRIES ]]; then
    echo "Too many failed attempts. Exiting."
    exit 1
  fi
done

# ---- Prompt for tempadmin password with confirmation ----
for ((i=1; i<=MAX_RETRIES; i++)); do
  read -s -p "Enter NEW password for tempadmin: " TEMPADMIN_PASS < /dev/tty
  echo
  read -s -p "Confirm NEW password for tempadmin: " TEMPADMIN_PASS_CONFIRM < /dev/tty
  echo
  if [[ "$TEMPADMIN_PASS" == "$TEMPADMIN_PASS_CONFIRM" ]]; then
    break
  fi
  echo "âŒ Passwords do not match. Attempt $i of $MAX_RETRIES."
  if [[ $i -eq $MAX_RETRIES ]]; then
    echo "Too many failed attempts. Exiting."
    unset ADMINISTRATOR_PASS ADMINISTRATOR_PASS_CONFIRM
    exit 1
  fi
done
unset ADMINISTRATOR_PASS_CONFIRM TEMPADMIN_PASS_CONFIRM

echo "Updating passwords..."

for USER in "${DYNAMIC_USERS[@]}"; do

  [[ "$USER" == "_"* ]] && continue

  case "$USER" in
    "administrator")
      PASSWORD="$ADMINISTRATOR_PASS"
      ;;
    "tempadmin")
      PASSWORD="$TEMPADMIN_PASS"
      ;;
    *)
      PASSWORD="$DEFAULT_PASS"
      ;;
  esac

  if id "$USER" &>/dev/null; then
    echo "Updating password for $USER..."
    sudo dscl . -passwd /Users/"$USER" "$PASSWORD"

    if [[ $? -eq 0 ]]; then
      echo "âœ… Password updated: $USER"
    else
      echo "âŒ Password failed: $USER"
    fi

    # Demote to standard only users matching first.last pattern
    if [[ "$USER" =~ ^[a-zA-Z]+\.[a-zA-Z]+$ ]]; then
      if dseditgroup -o checkmember -m "$USER" admin &>/dev/null; then
        echo "Demoting $USER from admin to standard..."
        sudo dseditgroup -o edit -d "$USER" -t user admin

        if [[ $? -eq 0 ]]; then
          echo "âœ… Demoted: $USER"
        else
          echo "âŒ Demotion failed: $USER"
        fi
      fi
    fi
  fi

done

# Clear sensitive variables
unset ADMINISTRATOR_PASS TEMPADMIN_PASS DEFAULT_PASS PASSWORD MAX_RETRIES

echo "Done."
