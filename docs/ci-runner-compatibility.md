# CI runner compatibility

Ruby CI and the manual Release workflow use `ubuntu-24.04`. The frontend-only job can
continue using `ubuntu-latest` because it does not install the pinned Ruby runtime.

The application currently pins Ruby 3.4.7 in `backend/.ruby-version`. When GitHub's
`ubuntu-latest` moved to 26.04, `ruby/setup-ruby` could not download a prebuilt
3.4.7 binary for that image. Security scan, Ruby lint and test jobs failed during
setup, before application checks ran. The previous PR checks were older runs on
a compatible runner; their success did not guarantee a later push would run.

Pinning the runner restores compatibility without changing the Ruby runtime,
Gemfile.lock, Docker image, database, deployment settings or application behaviour.
Keep Release aligned with the Ruby CI jobs so the same setup failure cannot recur
when creating a versioned release.

## Security scan follow-up

Once Ruby setup succeeded, the advisory scan ran and found newly reported issues
in seven locked gems. Keep the scan enabled and use conservative patch updates:

| Gem | Before | Patched |
| --- | --- | --- |
| crass | 1.0.7 | 1.0.8 |
| graphql | 2.6.11 | 2.6.14 |
| loofah | 2.25.2 | 2.25.3 |
| net-ssh | 7.3.2 | 7.3.8 |
| nokogiri | 1.19.4 | 1.19.7 |
| rack | 3.2.7 | 3.2.8 |
| rails-html-sanitizer | 1.7.1 | 1.7.2 |

The dependency follow-up changes `Gemfile.lock`, unlike the runner-only fix.
Ruby 3.4.7, Rails 8.1.4, JSON constraints, unrelated gem versions and existing
Linux/macOS platform entries remain unchanged. Run the advisory scan and full
backend regression suite on the updated lockfile, then verify hosted CI again.

## Verification

Confirm on GitHub that Ruby installation and all subsequent CI checks pass for
the repair PR. A local workflow/YAML check alone cannot prove hosted-runner setup.
After merge, verify the new `main` push independently; an old passing PR check is
not proof that production deployment succeeded.

## Production health is separate

A successful Cloudflare frontend deployment does not prove Render backend readiness.
Check the Render deployment's commit and Events/Logs, then `/up` and `/ready`.
The latter checks database connectivity, migrations, schema contract and queue tables.
An HTML challenge or 429 from the hosting/security layer is not a Rails readiness
response. Do not disable application authentication or retry write requests to
work around it. Inspect Render's account/service state and the source of the
response before changing hosting or security settings.

When upgrading Ruby later, update the application's runtime declarations and
Docker build deliberately, then evaluate the supported runner image together.
