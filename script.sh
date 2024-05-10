#!/bin/bash

read_env() {
  local filePath=".env"

  if [ ! -f "$filePath" ]; then
    echo "missing ${filePath}"
    exit 1
  fi

  # Read the file line by line
  while read -r LINE; do
    # Remove leading and trailing whitespaces, and carriage return
    CLEANED_LINE=$(echo "$LINE" | awk '{$1=$1};1' | tr -d '\r' | tr -d '"')

    if [[ $CLEANED_LINE != '#'* ]] && [[ $CLEANED_LINE == *'='* ]]; then
      echo "$CLEANED_LINE"
      export "$CLEANED_LINE"
    fi
  done < "$filePath"
}

read_env

echo "${LOGFILE}"
echo "hahaha"
pwd