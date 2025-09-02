#!/bin/bash

for VARNAME in DEPLOY_HTTPS_LOGIN DEPLOY_HTTPS_PASSWORD DEPLOY_HTTPS_REQUEST_URL DEPLOY_HTTPS_RESPONSE_URL DEPLOY_HOST DEPLOY_APP; do
  content=$(eval echo -n \$$VARNAME)
  if [ -z "$content" ]; then
    echo Variable $VARNAME must be defined.
    exit 1
  fi
done

sudo apt-get install -y jq curl

DEPLOY_ID=$(uuidgen)

if [ -n "$DEPLOY_BRANCH" ]; then
  REQUEST_DATA="{\"id\":\"$DEPLOY_ID\",\"app\":\"$DEPLOY_APP\",\"host\":\"$DEPLOY_HOST\",\"branch\":\"$DEPLOY_BRANCH\"}"
else
  REQUEST_DATA="{\"id\":\"$DEPLOY_ID\",\"app\":\"$DEPLOY_APP\",\"host\":\"$DEPLOY_HOST\"}"
fi

set -ex
curl -sSL --fail -K - -w '>>> HTTP %{response_code}\n' -X POST -H "Content-Type: application/json" -d "$REQUEST_DATA" "${DEPLOY_HTTPS_REQUEST_URL}/${DEPLOY_ID}" <<<"-u \"${DEPLOY_HTTPS_LOGIN}:${DEPLOY_HTTPS_PASSWORD}\""
set +ex

for I in $(seq 1 480); do
  set -e
  DEPLOY_STATUS=$(curl --fail -sSL -K - "${DEPLOY_HTTPS_RESPONSE_URL}/${DEPLOY_ID}" <<<"-u \"${DEPLOY_HTTPS_LOGIN}:${DEPLOY_HTTPS_PASSWORD}\"")
  set +e
  echo "$DEPLOY_STATUS"
  JSON_STATUS=$(echo "$DEPLOY_STATUS" | jq -r .status 2>/dev/null)
  if [ "$JSON_STATUS" == "finished" ]; then
    DEPLOY_PASS=$(echo "$DEPLOY_STATUS" | jq -r .pass)
    if [ "$DEPLOY_PASS" == "true" ]; then
      exit 0
    else
      exit 1
    fi
  fi
  sleep 1
done
echo Timeout
exit 1
