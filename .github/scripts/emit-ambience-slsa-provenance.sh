#!/usr/bin/env bash
set -euo pipefail

output_path="${1:?Usage: emit-ambience-slsa-provenance.sh <output-path>}"

required_values=(
  GITHUB_REF
  GITHUB_REPOSITORY
  GITHUB_RUN_ATTEMPT
  GITHUB_RUN_ID
  GITHUB_SHA
  PATCH_COMMIT
  UPSTREAM_COMMIT
)
for name in "${required_values[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    printf 'Missing required GitHub Actions value: %s\n' "$name" >&2
    exit 1
  fi
done

if [[ ! "$GITHUB_REF" =~ ^refs/tags/ambience-1\.37\.0-p7482\.[1-9][0-9]*$ ]]; then
  printf 'SLSA provenance requires an allowlisted patched release tag\n' >&2
  exit 1
fi

workflow_path=".github/workflows/ambience-patched-release.yml"
repository_url="https://github.com/${GITHUB_REPOSITORY}"
workflow_identity="${repository_url}/${workflow_path}@${GITHUB_REF}"
source_uri="git+${repository_url}@${GITHUB_REF}"
invocation_id="${repository_url}/actions/runs/${GITHUB_RUN_ID}/attempts/${GITHUB_RUN_ATTEMPT}"

jq -n \
  --arg build_type "https://github.com/Attestations/GitHubActionsWorkflow@v1" \
  --arg invocation_id "$invocation_id" \
  --arg patch_commit "$PATCH_COMMIT" \
  --arg repository_url "$repository_url" \
  --arg sha "$GITHUB_SHA" \
  --arg source_uri "$source_uri" \
  --arg upstream_commit "$UPSTREAM_COMMIT" \
  --arg workflow_identity "$workflow_identity" \
  --arg workflow_path "$workflow_path" \
  '{
    builder: {id: $workflow_identity},
    buildType: $build_type,
    invocation: {
      configSource: {
        uri: $source_uri,
        digest: {sha1: $sha},
        entryPoint: $workflow_path
      },
      parameters: {
        patchCommit: $patch_commit,
        repository: $repository_url,
        upstreamCommit: $upstream_commit
      },
      environment: {}
    },
    metadata: {
      buildInvocationID: $invocation_id,
      completeness: {
        parameters: true,
        environment: false,
        materials: true
      },
      reproducible: false
    },
    materials: [
      {
        uri: "git+https://github.com/dani-garcia/vaultwarden@refs/tags/1.37.0",
        digest: {sha1: $upstream_commit}
      },
      {
        uri: "git+https://github.com/dani-garcia/vaultwarden@refs/pull/7482/head",
        digest: {sha1: $patch_commit}
      },
      {
        uri: $source_uri,
        digest: {sha1: $sha}
      }
    ]
  }' > "$output_path"
