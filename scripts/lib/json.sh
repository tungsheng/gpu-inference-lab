#!/usr/bin/env bash

json_escape() {
  local value=${1-}

  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "${value}"
}

json_string() {
  printf '"%s"' "$(json_escape "${1-}")"
}

json_nullable_string() {
  if [[ -n "${1-}" ]]; then
    json_string "${1}"
    return 0
  fi

  printf 'null'
}

json_nullable_number() {
  if [[ -n "${1-}" ]]; then
    printf '%s' "${1}"
    return 0
  fi

  printf 'null'
}

json_nullable_bool() {
  case "${1-}" in
    1|true|True)
      printf 'true'
      ;;
    0|false|False)
      printf 'false'
      ;;
    *)
      printf 'null'
      ;;
  esac
}
