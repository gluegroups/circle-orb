#!/usr/bin/env bats

setup() {
    source ./src/scripts/notify.sh
    source ./src/scripts/utils.sh
    export GLUE_PARAM_BRANCHPATTERN=$(cat $BATS_TEST_DIRNAME/sampleBranchFilters.txt)
    GLUE_PARAM_INVERT_MATCH="0"
}

@test "1: Skip message on no event" {
    CCI_STATUS="success"
    GLUE_PARAM_EVENT="fail"
    echo "Running notify"
    run ShouldPost
    echo "test output status: $status"
    echo "Output:"
    echo "$output"
    echo " --- "
    [ "$status" -eq 0 ] # Check for no exit error
    [[ $output == *"NO GLUE ALERT"* ]] # Ensure output contains expected string
}

@test "2: ModifyCustomTemplate" {
    # Ensure a custom template has the text key automatically affixed.
    GLUE_PARAM_CUSTOM=$(cat $BATS_TEST_DIRNAME/sampleCustomTemplate.md)
    ModifyCustomTemplate
    TEXTKEY=$(echo $CUSTOM_BODY_MODIFIED | jq '.text')
    [ "$TEXTKEY" == '""' ]
}

@test "4: ModifyCustomTemplate with environment variable in link" {
    TESTLINKURL="http://circleci.com"
    GLUE_PARAM_CUSTOM=$(cat $BATS_TEST_DIRNAME/sampleCustomTemplateWithLink.md)
    GLUE_DEFAULT_TARGET="xyz"
    BuildMessageBody
    EXPECTED=$(echo "{ \"text\": \"Sample link using environment variable in markdown [LINK](${TESTLINKURL})\", \"target\": \"$GLUE_DEFAULT_TARGET\" }" | jq)
    [ "$GLUE_MSG_BODY" == "$EXPECTED" ]
}

@test "5: ModifyCustomTemplate special chars" {
    TESTLINKURL="http://circleci.com"
    GLUE_PARAM_CUSTOM=$(cat $BATS_TEST_DIRNAME/sampleCustomTemplateWithSpecialChars.md)
    GLUE_DEFAULT_TARGET="xyz"
    BuildMessageBody
    EXPECTED=$(echo "{ \"text\": \"These asterisks are not \`glob\` patterns **t** (parentheses'). [Link](https://example.org)\", \"target\": \"$GLUE_DEFAULT_TARGET\" }" | jq)
    [ "$GLUE_MSG_BODY" == "$EXPECTED" ]
}

@test "6: FilterBy - match-all default" {
    GLUE_PARAM_BRANCHPATTERN=".+"
    CIRCLE_BRANCH="xyz-123"
    run FilterBy "$GLUE_PARAM_BRANCHPATTERN" "$CIRCLE_BRANCH"
    echo "Error GLUE_PARAM_BRANCHPATTERN debug: $GLUE_PARAM_BRANCHPATTERN"
    echo "Error output debug: $output"
    [ "$output" == "" ] # Should match any branch: No output error
    [ "$status" -eq 0 ] # In any case, this should return a 0 exit as to not block a build/deployment.
}

@test "7: FilterBy - string" {
    CIRCLE_BRANCH="master"
    run FilterBy "$GLUE_PARAM_BRANCHPATTERN" "$CIRCLE_BRANCH"
    echo "Error output debug: $output"
    [ "$output" == "" ] # "master" is in the list: No output error
    [ "$status" -eq 0 ] # In any case, this should return a 0 exit as to not block a build/deployment.
}

@test "8: FilterBy - regex numbers" {
    CIRCLE_BRANCH="pr-123"
    run FilterBy "$GLUE_PARAM_BRANCHPATTERN" "$CIRCLE_BRANCH"
    echo "Error output debug: $output"
    [ "$output" == "" ] # "pr-[0-9]+" should match: No output error
    [ "$status" -eq 0 ] # In any case, this should return a 0 exit as to not block a build/deployment.
}

@test "9: FilterBy - non-match" {
    CIRCLE_BRANCH="x"
    run FilterBy "$GLUE_PARAM_BRANCHPATTERN" "$CIRCLE_BRANCH"
    echo "Error output debug: $output"
    [[ "$output" =~ "NO GLUE ALERT" ]] # "x" is not included in the filter. Error message expected.
    [ "$status" -eq 0 ] # In any case, this should return a 0 exit as to not block a build/deployment.
}

@test "10: FilterBy - no partial-match" {
    CIRCLE_BRANCH="pr-"
    run FilterBy "$GLUE_PARAM_BRANCHPATTERN" "$CIRCLE_BRANCH"
    echo "Error output debug: $output"
    [[ "$output" =~ "NO GLUE ALERT" ]] # Filter dictates that numbers should be included. Error message expected.
    [ "$status" -eq 0 ] # In any case, this should return a 0 exit as to not block a build/deployment.
}

@test "11: FilterBy - GLUE_PARAM_BRANCHPATTERN is empty" {
    unset GLUE_PARAM_BRANCHPATTERN
    CIRCLE_BRANCH="master"
    run FilterBy "$GLUE_PARAM_BRANCHPATTERN" "$CIRCLE_BRANCH"
    echo "Error output debug: $output"
    [ "$status" -eq 0 ] # In any case, this should return a 0 exit as to not block a build/deployment.
}

@test "12: FilterBy - CIRCLE_BRANCH is empty" {
    run FilterBy "$GLUE_PARAM_BRANCHPATTERN" "$CIRCLE_BRANCH"
    echo "Error output debug: $output"
    [ "$status" -eq 0 ] # In any case, this should return a 0 exit as to not block a build/deployment.
}

@test "13: FilterBy - match and GLUE_PARAM_INVERT_MATCH is set" {
    CIRCLE_BRANCH="pr-123"
    GLUE_PARAM_INVERT_MATCH="1"
    run FilterBy "$GLUE_PARAM_BRANCHPATTERN" "$CIRCLE_BRANCH"
    echo "Error output debug: $output"
    [[ "$output" =~ "NO GLUE ALERT" ]] # "pr-[0-9]+" should match but inverted: Error message expected.
    [ "$status" -eq 0 ] # In any case, this should return a 0 exit as to not block a build/deployment.
}

@test "14: FilterBy - non-match and GLUE_PARAM_INVERT_MATCH is set" {
    CIRCLE_BRANCH="foo"
    GLUE_PARAM_INVERT_MATCH="1"
    run FilterBy "$GLUE_PARAM_BRANCHPATTERN" "$CIRCLE_BRANCH"
    echo "Error output debug: $output"
    [ "$output" == "" ] # Nothing should match but inverted: No output error
    [ "$status" -eq 0 ] # In any case, this should return a 0 exit as to not block a build/deployment.
}

@test "15: Sanitize - Escape newlines in environment variables" {
    CIRCLE_JOB="$(printf "%s\\n" "Line 1." "Line 2." "Line 3.")"
    EXPECTED="Line 1.\\nLine 2.\\nLine 3."
    GLUE_PARAM_CUSTOM=$(cat $BATS_TEST_DIRNAME/sampleCustomTemplate.md)
    SanitizeVars "$GLUE_PARAM_CUSTOM"
    printf '%s\n' "Expected: $EXPECTED" "Actual: $CIRCLE_JOB"
    [ "$CIRCLE_JOB" = "$EXPECTED" ] # Newlines should be literal and escaped
}

@test "16: Sanitize - Escape double quotes in environment variables" {
    CIRCLE_JOB="$(printf "%s\n" "Hello \"world\".")"
    EXPECTED="Hello \\\"world\\\"."
    GLUE_PARAM_CUSTOM=$(cat $BATS_TEST_DIRNAME/sampleCustomTemplate.md)
    SanitizeVars "$GLUE_PARAM_CUSTOM"
    printf '%s\n' "Expected: $EXPECTED" "Actual: $CIRCLE_JOB"
    [ "$CIRCLE_JOB" = "$EXPECTED" ] # Double quotes should be escaped
}

@test "17: Sanitize - Escape backslashes in environment variables" {
    CIRCLE_JOB="$(printf "%s\n" "removed extra '\' from  notification template")"
    EXPECTED="removed extra '\\\' from  notification template"
    GLUE_PARAM_CUSTOM=$(cat $BATS_TEST_DIRNAME/sampleCustomTemplate.md)
    SanitizeVars "$GLUE_PARAM_CUSTOM"
    printf '%s\n' "Expected: $EXPECTED" "Actual: $CIRCLE_JOB"
    [ "$CIRCLE_JOB" = "$EXPECTED" ] # Backslashes should be escaped
}
