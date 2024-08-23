#!/bin/sh
# shellcheck disable=SC2016,SC3043

# Import utils.
eval "$GLUE_SCRIPT_UTILS"
JQ_PATH=/usr/local/bin/jq

BuildMessageBody() {
    # Send message
    #   If sending message, default to custom template,
    #   if none is supplied, check for a pre-selected template value.
    #   If none, error.
    if [ -n "${GLUE_PARAM_CUSTOM:-}" ]; then
        CUSTOM_BODY=$(jq -n --arg text "$GLUE_PARAM_CUSTOM" '{text: $text}')
        SanitizeVars "$CUSTOM_BODY"
        # shellcheck disable=SC2016
        CUSTOM_BODY_MODIFIED=$(echo "$CUSTOM_BODY_MODIFIED" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/`/\\`/g')
        T2="$(eval printf '%s' \""$CUSTOM_BODY_MODIFIED"\")"
    else
        # shellcheck disable=SC2154
        if [ -n "${GLUE_PARAM_TEMPLATE:-}" ]; then TEMPLATE="\$$GLUE_PARAM_TEMPLATE"
        elif [ "$CCI_STATUS" = "pass" ]; then TEMPLATE="\$basic_success_1"
        elif [ "$CCI_STATUS" = "fail" ]; then TEMPLATE="\$basic_fail_1"
        else echo "A template wasn't provided nor is possible to infer it based on the job status. The job status: '$CCI_STATUS' is unexpected."; exit 1
        fi

        [ -z "${GLUE_PARAM_TEMPLATE:-}" ] && echo "No message template was explicitly chosen. Based on the job status '$CCI_STATUS' the template '$TEMPLATE' will be used."
        template_body="$(eval printf '%s' \""$TEMPLATE\"")"

        json_body=$(jq -n --arg text "$template_body" '{text: $text}')
        SanitizeVars "$json_body"

        # shellcheck disable=SC2016
        T1="$(printf '%s' "$json_body" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/`/\\`/g')"
        T2="$(eval printf '%s' \""$T1"\")"
    fi

    # Insert the default target. THIS IS TEMPORARY
    T2="$(printf '%s' "$T2" | jq ". + {\"target\": \"$GLUE_DEFAULT_TARGET\"}")"

    if [ -n "${GLUE_PARAM_THREAD_SUBJECT:-}" ]; then
        T2="$(printf '%s' "$T2" | jq ". + {\"threadSubject\": \"$GLUE_PARAM_THREAD_SUBJECT\"}")"
        if [ -n "${GLUE_PARAM_THREAD_BY:-}" ]; then
            T2="$(printf '%s' "$T2" | jq ". + {\"threadBy\": \"$GLUE_PARAM_THREAD_BY\"}")"
        fi
    fi

    GLUE_MSG_BODY="$T2"
}

PostToGlue() {
    # Post once per target listed by the target parameter
    #    The target must be modified in GLUE_MSG_BODY
    # shellcheck disable=SC2001
    for i in $(eval echo \""$GLUE_PARAM_TARGET"\" | sed "s/,/ /g")
    do
        echo "Sending to Glue Target: $i"
        GLUE_MSG_BODY=$(echo "$GLUE_MSG_BODY" | jq --arg target "$i" '.target = $target')
        if [ "$GLUE_PARAM_DEBUG" -eq 1 ]; then
            printf "%s\n" "$GLUE_MSG_BODY" > "$GLUE_MSG_BODY_LOG"
            echo "The message body being sent to Glue can be found below. To view redacted values, rerun the job with SSH and access: ${GLUE_MSG_BODY_LOG}"
            echo "$GLUE_MSG_BODY"
        fi
        GLUE_SENT_RESPONSE=$(curl -s -f -X POST -H 'Content-type: application/json' --data "$GLUE_MSG_BODY" "$GLUE_WEBHOOK")

        if [ "$GLUE_PARAM_DEBUG" -eq 1 ]; then
            printf "%s\n" "$GLUE_SENT_RESPONSE" > "$GLUE_SENT_RESPONSE_LOG"
            echo "The response from the API call to Glue can be found below. To view redacted values, rerun the job with SSH and access: ${GLUE_SENT_RESPONSE_LOG}"
            echo "$GLUE_SENT_RESPONSE"
        fi

        GLUE_ERROR_MSG=$(echo "$GLUE_SENT_RESPONSE" | jq '.error')
        if [ ! "$GLUE_ERROR_MSG" = "null" ]; then
            echo "Glue API returned an error message:"
            echo "$GLUE_ERROR_MSG"
            echo
            echo
            echo "View the Setup Guide: https://github.com/gluegroups/circle-orb/wiki/Setup"
            if [ "$GLUE_PARAM_IGNORE_ERRORS" = "0" ]; then
                exit 1
            fi
        fi
    done
}

InstallJq() {
    echo "Checking For JQ + CURL"
    if command -v curl >/dev/null 2>&1 && ! command -v jq >/dev/null 2>&1; then
        uname -a | grep Darwin > /dev/null 2>&1 && JQ_VERSION=jq-osx-amd64 || JQ_VERSION=jq-linux32
        curl -Ls -o "$JQ_PATH" https://github.com/stedolan/jq/releases/download/jq-1.6/"${JQ_VERSION}"
        chmod +x "$JQ_PATH"
        command -v jq >/dev/null 2>&1
        return $?
    else
        command -v curl >/dev/null 2>&1 || { echo >&2 "GLUE ORB ERROR: CURL is required. Please install."; exit 1; }
        command -v jq >/dev/null 2>&1 || { echo >&2 "GLUE ORB ERROR: JQ is required. Please install"; exit 1; }
        return $?
    fi
}

FilterBy() {
    if [ -z "$1" ] || [ -z "$2" ]; then
      return
    fi

    # If any pattern supplied matches the current branch or the current tag, proceed; otherwise, exit with message.
    FLAG_MATCHES_FILTER="false"
    for i in $(echo "$1" | sed "s/,/ /g"); do
        if echo "$2" | grep -Eq "^${i}$"; then
            FLAG_MATCHES_FILTER="true"
            break
        fi
    done
    # If the invert_match parameter is set, invert the match.
    if { [ "$FLAG_MATCHES_FILTER" = "false" ] && [ "$GLUE_PARAM_INVERT_MATCH" -eq 0 ]; } || \
        { [ "$FLAG_MATCHES_FILTER" = "true" ] && [ "$GLUE_PARAM_INVERT_MATCH" -eq 1 ]; }
    then
        # don't send message.
        echo "NO GLUE ALERT"
        echo
        echo "Current reference \"$2\" does not match any matching parameter"
        echo "Current matching pattern: $1"
        exit 0
    fi
}

SetupEnvVars() {
    echo "BASH_ENV file: $BASH_ENV"
    if [ -f "$BASH_ENV" ]; then
        echo "Exists. Sourcing into ENV"
        # shellcheck disable=SC1090
        . "$BASH_ENV"
    else
        echo "Does Not Exist. Skipping file execution"
    fi
}

CheckEnvVars() {
    if [ -z "${GLUE_WEBHOOK:-}" ]; then
        echo "In order to use the Glue Orb, a Webhook URL must be present via the GLUE_WEBHOOK environment variable."
        echo "Follow the setup guide available in the wiki: https://github.com/gluegroups/circle-orb/wiki/Setup"
        exit 1
    fi
    # If no target is provided, quit with error
    if [ -z "${GLUE_PARAM_TARGET:-}" ]; then
       echo "No target was provided. Enter value for GLUE_DEFAULT_TARGET env var, or target parameter"
       exit 1
    fi
}

ShouldPost() {
    if [ "$CCI_STATUS" = "$GLUE_PARAM_EVENT" ] || [ "$GLUE_PARAM_EVENT" = "always" ]; then
        # In the event the Glue notification would be sent, first ensure it is allowed to trigger
        # on this branch or this tag.
        FilterBy "$GLUE_PARAM_BRANCHPATTERN" "${CIRCLE_BRANCH:-}"
        FilterBy "$GLUE_PARAM_TAGPATTERN" "${CIRCLE_TAG:-}"

        echo "Posting Status"
    else
        # don't send message.
        echo "NO GLUE ALERT"
        echo
        echo "This command is set to send an alert on: $GLUE_PARAM_EVENT"
        echo "Current status: ${CCI_STATUS}"
        exit 0
    fi
}

SetupLogs() {
    if [ "$GLUE_PARAM_DEBUG" -eq 1 ]; then
        LOG_PATH="$(mktemp -d 'glue-orb-logs.XXXXXX')"
        GLUE_MSG_BODY_LOG="$LOG_PATH/payload.json"
        GLUE_SENT_RESPONSE_LOG="$LOG_PATH/response.json"

        touch "$GLUE_MSG_BODY_LOG" "$GLUE_SENT_RESPONSE_LOG"
        chmod 0600 "$GLUE_MSG_BODY_LOG" "$GLUE_SENT_RESPONSE_LOG"
    fi
}

# $1: Template with environment variables to be sanitized.
SanitizeVars() {
  [ -z "$1" ] && { printf '%s\n' "Missing argument."; return 1; }
  local template="$1"

  # Find all environment variables in the template with the format $VAR or ${VAR}.
  # The "|| true" is to prevent bats from failing when no matches are found.
  local variables
  variables="$(printf '%s\n' "$template" | grep -o -E '\$\{?[a-zA-Z_0-9]*\}?' || true)"
  [ -z "$variables" ] && { printf '%s\n' "Nothing to sanitize."; return 0; }

  # Extract the variable names from the matches.
  local variable_names
  variable_names="$(printf '%s\n' "$variables" | grep -o -E '[a-zA-Z0-9_]+' || true)"
  [ -z "$variable_names" ] && { printf '%s\n' "Nothing to sanitize."; return 0; }

  # Find out what OS we're running on.
  detect_os

  for var in $variable_names; do
    # The variable must be wrapped in double quotes before the evaluation.
    # Otherwise, the newlines will be removed.
    local value
    value="$(eval printf '%s' \"\$"$var\"")"
    [ -z "$value" ] && { printf '%s\n' "$var is empty or doesn't exist. Skipping it..."; continue; }

    printf '%s\n' "Sanitizing $var..."

    local sanitized_value="$value"
    # Escape backslashes.
    sanitized_value="$(printf '%s' "$sanitized_value" | awk '{gsub(/\\/, "&\\"); print $0}')"
    # Escape newlines.
    sanitized_value="$(printf '%s' "$sanitized_value" | awk 'NR > 1 { printf("\\n") } { printf("%s", $0) }')"
    # Escape double quotes.
    if [ "$PLATFORM" = "windows" ]; then
        sanitized_value="$(printf '%s' "$sanitized_value" | awk '{gsub(/"/, "\\\""); print $0}')"
    else
        sanitized_value="$(printf '%s' "$sanitized_value" | awk '{gsub(/\"/, "\\\""); print $0}')"
    fi

    # Write the sanitized value back to the original variable.
    # shellcheck disable=SC3045 # This is working on Alpine.
    printf -v "$var" "%s" "$sanitized_value"
  done

  return 0;
}

# Will not run if sourced from another script.
# This is done so this script may be tested.
ORB_TEST_ENV="bats-core"
if [ "${0#*"$ORB_TEST_ENV"}" = "$0" ]; then
    # shellcheck source=/dev/null
    . "/tmp/GLUE_JOB_STATUS"
    ShouldPost
    SetupEnvVars
    SetupLogs
    CheckEnvVars
    InstallJq
    BuildMessageBody
    PostToGlue
fi
