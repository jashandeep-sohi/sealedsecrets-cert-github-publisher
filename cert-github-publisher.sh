#!/bin/sh

set -e

if test "$GITHUB_AUTH" = "app"; then
  if test -z "$GITHUB_APP_ID"; then
    echo "GITHUB_APP_ID" not set.
    exit 1
  fi

  if test -z "$GITHUB_APP_INSTALLATION_ID"; then
    echo "GITHUB_APP_INSTALLATION_ID" not set.
    exit 1
  fi

  if test -z "$GITHUB_APP_PRIVATEKEY"; then
    echo "GITHUB_APP_PRIVATEKEY" not set.
    exit 1
  fi
elif test "$GITHUB_AUTH" = "token"; then
  if test -z "$GITHUB_TOKEN"; then
    echo "GITHUB_TOKEN" not set.
    exit 1
  fi
else
  echo "GITHUB_AUTH" must be 'app' or 'token'.
  exit 1
fi


if test -z "$GITHUB_REPO"; then
  echo "GITHUB_REPO" not set.
  exit 1
fi

if test -z "$UPDATE_YAML_FILE"; then
  echo "UPDATE_YAML_FILE" not set.
  exit 1
fi

if test -z "$UPDATE_YAML_PATH_EXPRESSION"; then
  echo "UPDATE_YAML_PATH_EXPRESSION" not set.
  exit 1
fi

: "${SEALEDSECRETS_CONTROLLER_NAMESPACE:=kube-system}"
: "${SEALEDSECRETS_CONTROLLER_NAME:=sealed-secrets-controller}"
: "${SEALEDSECRETS_CONTROLLER_CERT_URL:=}"


: "${COMMIT_TITLE:=chore: update sealedsecret cert}"
: "${BRANCH_PREFIX:=chore/sealedsecret-cert/}"
: "${PR_LABELS:=chore,sealedsecrets}"
: "${PR_ASSIGNEES:=}"
: "${PR_REVIEWERS:=}"
: "${PR_TEAM_REVIEWERS:=}"
: "${PR_BASE_BRANCH:=main}"
: "${PR_MERGE:=false}"
: "${PR_MERGE_METHOD:=squash}"

set -x
kubeseal \
  --controller-namespace "$SEALEDSECRETS_CONTROLLER_NAMESPACE" \
  --controller-name "$SEALEDSECRETS_CONTROLLER_NAME" \
  --cert "$SEALEDSECRETS_CONTROLLER_CERT_URL" \
  --fetch-cert > /tmp/cert.pem
set +x

SS_CERT="$(cat /tmp/cert.pem)"

export SS_CERT GITHUB_TOKEN GITHUB_APP_ID GITHUB_INSTALLATION_ID="$GITHUB_APP_INSTALLATION_ID" GITHUB_PRIVATEKEY="$GITHUB_APP_PRIVATEKEY"

set -x
octopilot \
  --fail-on-error \
  --log-level debug \
  --github-auth-method "$GITHUB_AUTH" \
  --git-stage-all-changed=false \
  --repo "$GITHUB_REPO" \
  --update "yq(file=$UPDATE_YAML_FILE,expression='$UPDATE_YAML_PATH_EXPRESSION',create=true)" \
  --git-stage-pattern "$UPDATE_YAML_FILE" \
  --git-commit-title "$COMMIT_TITLE" \
  --git-branch-prefix "$BRANCH_PREFIX" \
  --pr-labels "$PR_LABELS" \
  --pr-assignees "$PR_ASSIGNEES" \
  --pr-reviewers "$PR_REVIEWERS" \
  --pr-team-reviewers "$PR_TEAM_REVIEWERS" \
  --pr-base-branch "$PR_BASE_BRANCH" \
  --pr-base-branch "$PR_BASE_BRANCH" \
  --pr-merge="$PR_MERGE" \
  --pr-merge-method "$PR_MERGE_METHOD"
