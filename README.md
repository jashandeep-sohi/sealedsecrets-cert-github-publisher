# sealedsecrets-cert-github-publisher

Fetch the latest sealing certificate from the [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets)
API server and publish it to a Github repositiory.

The certificate can then be used by anyone to seal secrets without needing access to
the Kuberentes cluster (i.e. `kubeseal --cert ...`).

# Usage

This is primarily designed to be run as a `CronJob` on the same cluster as the Sealed Secrets
controller.

For example, to periodically update the certificate:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: sealedsecrets-cert-github-publisher
spec:
  schedule: "@midnight"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: publish
              image: ghcr.io/jashandeep-sohi/sealedsecrets-cert-github-publisher:latest
              imagePullPolicy: Always
              env:
                - name: SEALEDSECRET_CONTROLLER_NAMESPACE
                  value: "kube-system"

                - name: SEALEDSECRET_CONTROLLER_NAME
                  value: "sealed-secrets-controller"

                # If set, controller name and controller namespace are ignored, and the certificate is retrieved from this URL instead.
                - name: SEALEDSECRET_CERT_URL
                  value: ""

                # Github authentication can be done via a PAT token or a Github App.
                # Github App is preferred to keep access limited as possible.
                - name: GITHUB_AUTH
                  value: "app" # or 'token'

                # If using token (PAT) auth.
                - name: GITHUB_TOKEN
                  value: "...."

                # If using Github App, best practice is to create a new one, just for this application.
                # It will require the following Repository permissions:
                #   - Checks (read)
                #   - Contents (read/write)
                #   - Pull Requests (read/write)

                - name: GITHUB_APP_ID
                  value: "<your github app id>"

                - name: GITHUB_APP_INSTALLATION_ID
                  value: "<your github app installation id>"

                - name: GITHUB_APP_PRIVATEKEY
                  valueFrom:
                    secretKeyRef:
                      name: sealedsecrets-cert-github-publisher
                      key: GITHUB_APP_PRIVATEKEY
                      optional: false

                - name: GITHUB_REPO
                  value: "<org>/<repo-name>"

                # File to update in the repo
                - name: UPDATE_YAML_FILE
                  value: "sealedsecrets/fn-config.yaml"

                # yq expression (https://mikefarah.gitbook.io/yq/operators/traverse-read) to update in the file.
                - name: UPDATE_YAML_PATH_EXPRESSION
                  value: ".data.cert"

                - name: COMMIT_TITLE
                  value: "chore: update sealedsecret cert"

                - name: BRANCH_PREFIX
                  value: "chore/sealedsecret-cert/"

                - name: PR_LABELS
                  value: "chore,sealedsecrets"

                - name: PR_ASSIGNEES
                  value: "github-username1,github-username2"

                - name: PR_REVIEWERS
                  value: "github-username1,github-username2"

                - name: PR_TEAM_REVIEWERS
                  value: "github-team1,github-team2"

                - name: PR_BASE_BRANCH
                  value: "main"

                - name: PR_MERGE
                  value: "true"

                - name: PR_MERGE_METHOD
                  value: "squash"
---
apiVersion: v1
kind: Secret
metatada:
  name: sealedsecrets-cert-github-publisher
stringData:
  GITHUB_APP_PRIVATEKEY: |-
    <PEM encoded private key>
```
