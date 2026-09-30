---
id: AgDR-0001
timestamp: 2026-09-30T12:45:00Z
agent: claude
model: claude-opus-5-5
trigger: user-prompt
status: executed
---

# Fix the release workflow and publish to GitHub Packages

> In the context of script_tracker releases, facing a version bump that does not apply and a manual GitHub Packages upload, I decided to fix the release workflow to achieve correct, repeatable releases to both registries, accepting a small workflow change on `main`.

## Context

- `release.yml` bumps the version with the pattern `VERSION = ".*"`. `lib/script_tracker/version.rb` uses single quotes (`VERSION = '0.2.0'`). The pattern does not match, so the bump does not change the file.
- The step then commits with `|| echo "No changes to commit"`. The workflow can tag `vX` and build a gem with the old version.
- `release.yml` publishes only to RubyGems. Version 0.2.0 was pushed to GitHub Packages by hand on 2026-09-30.
- The `Rubocop` workflow is `disabled_inactivity`. CI already runs RuboCop.
- Local check on Ruby 3.4.8: 69 examples, 0 failures, 3 pending. RuboCop reports no offenses. There are no open issues, no open PRs, and no Dependabot alerts.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| Fix the version pattern and add a GitHub Packages push step | Releases become correct and publish to both registries | One workflow change to review |
| Do nothing | No work | The next release can publish a gem with the wrong version. GitHub Packages needs a manual push each time |
| Fix the workflow and also modernize (Ruby 3.4 in the CI matrix, raise `required_ruby_version`, update dev dependencies) | Broader upkeep | Raising the Ruby floor is a breaking change for users. It is not needed for the release bug |

## Decision

Chosen: **fix the version pattern and add a GitHub Packages push step**, because the version bug can publish a mislabelled gem and the fix is small and reversible. Add Ruby 3.4 to the CI matrix in the same change, because it passes locally and costs nothing. Keep `required_ruby_version` unchanged.

## Consequences

- The version pattern must match both quote styles, for example `VERSION = ['"].*['"]`.
- The release job pushes the built gem to `https://rubygems.pkg.github.com/a-abdellatif98` with `GITHUB_TOKEN`. The job already has `packages: write`.
- The redundant `Rubocop` workflow can stay disabled or be deleted.
- Minor dev dependency updates (rake, rubocop, rubocop-rspec, sqlite3) are optional.

## Artifacts

- TBD: commit or PR link.
