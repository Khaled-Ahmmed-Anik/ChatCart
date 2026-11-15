# Oracle production migration runbook

**Planned migration only.** Render remains production until cutover is approved. Keep Cloudflare Pages and the existing Neon production database. Do not run seeds, rotate encryption keys or change feature rollouts during this move.

## Prerequisites

- Oracle account and available Always Free-eligible VM. Confirm current Console limits and estimated cost before creating resources. Capacity is not guaranteed; idle free VMs may be reclaimed. See [Oracle Always Free resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm).
- Ubuntu 24.04, preferably Ampere A1 ARM with at least 1 OCPU/6 GB RAM within the account's allowance. ARM dependencies are listed in the lockfile, but build and boot still need verification on the VM.
- Stable public IP and an API hostname you control. Compose does not supply a domain.
- SSH keys; allow TCP 22 only from the administrator's IP, TCP 80/443 publicly, optionally UDP 443 for HTTP/3. Check Oracle network rules AND the host firewall. Do not publish PostgreSQL or Rails port 3000.
- Install Docker Engine and Compose using [Docker's Ubuntu instructions](https://docs.docker.com/engine/install/ubuntu/), enable Docker at boot and verify `docker compose version`. Docker group membership effectively grants root access; restrict it to trusted administrators.
- Use the same reviewed commit as Render for cutover. Treat subsequent code/schema upgrades as a separate release.

## 1. Record state and protect data

Record Render's commit, Meta callbacks, Cloudflare Pages production `API_ORIGIN`, and GitHub `PRODUCTION_API_URL` / `PRODUCTION_WEB_URL` for rollback.

Take a verified Neon recovery point before any write-capable startup. Check the plan's recovery availability; otherwise take an encrypted dump and test restore to an isolated database. Never test restoration over production.

Inventory Active Storage attachments/local files on Render. Neon contains attachment records, not image bytes. Copy available bytes separately into Oracle's storage volume and verify sample images. Render's ephemeral storage may already have lost files; a new volume cannot recover them. If there are no stored attachments, record that explicitly.

## 2. Copy configuration securely

Clone ChatCart on the VM and check out the recorded production commit, then:

```bash
cd ChatCart
cp deploy/oracle/.env.example deploy/oracle/.env
chmod 600 deploy/oracle/.env
```

Edit privately. Never paste secrets into logs, PRs, screenshots or chat. Do not share unredacted `docker compose config`; use `--quiet`.

Compose interprets `.env` values: single-quote literal secrets containing `$` or `#` according to [Docker's environment-file syntax](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/#env-file-syntax). Verify copied values without printing them. Do not load this production file into local development/test commands.

Copy exact existing production values from Render:

- `DATABASE_URL` and separate `QUEUE_DATABASE_URL`, `CACHE_DATABASE_URL`, `CABLE_DATABASE_URL` if configured. Confirm the same Neon project, branch and database, with TLS enabled.
- `SECRET_KEY_BASE`, `RAILS_MASTER_KEY` and all three `ACTIVE_RECORD_ENCRYPTION_*` keys. **Do not generate replacements.** If encryption variables were absent, determine the existing effective keys before proceeding.
- Meta app secrets and verify tokens; optional WhatsApp credentials if used. Business Page tokens are encrypted in Neon's `channel_connections`; a global Messenger token is not a substitute for a business connection.
- Gemini key/model and every configured `CONVERSATION_*`, `CUSTOMER_PHOTO_RECOGNITION_*`, `KNOWLEDGE_*` and other runtime flag. The template is not a full copy of Render settings.

Set `APP_DOMAIN` and `APP_HOST` to the API hostname without scheme/path; `DASHBOARD_ORIGIN=https://chatcart-dashboard.pages.dev`; `FORCE_SSL=true`. Keep `DB_POOL=5` or higher after checking actual concurrency. The template uses single-process Puma (`WEB_CONCURRENCY=0`).

**Never run `db:seed` for this migration.** Existing accounts/catalogue remain in Neon. Seeds can overwrite account passwords, product prices, stock and activation. Do not copy seed account passwords into this configuration.

Caddy receives only `APP_DOMAIN`, not backend secrets. `.env` is gitignored and excluded from the backend image context.

## 3. Build and configuration-only preflight

```bash
cd deploy/oracle
docker compose config --quiet
docker compose build backend
docker compose run --rm --no-deps --entrypoint ruby backend bin/oracle-migration-preflight
```

Preflight rejects missing/template values, invalid origins/hosts, non-TLS database URLs and disabled SSL. It does not boot Rails or touch the database. Passing does NOT establish key equality, database identity, credential validity, ARM boot or worker health.

## 4. Read-only database and key validation

Bypass the Docker entrypoint for this one-off runner so it does not migrate or start workers:

```bash
docker compose run --rm --no-deps --entrypoint ./bin/rails backend runner \
  'abort "Not production" unless Rails.env.production?; puts "Database: #{ActiveRecord::Base.connection.select_value("SELECT current_database()")}"; ChannelConnection.find_each { |connection| connection.access_token }; puts "Channel token decryption completed (values not printed)"'
```

Confirm the database target independently against the recorded Neon project/branch, then compare expected business/catalogue counts and active Page connections using read-only checks. Decryption does not prove Meta token validity. Also validate other encrypted integrations in use. Stop on any error.

## 5. Controlled cutover — explicit operator approval required

Schedule a short maintenance window. Build/preflight can happen beforehand; starting against the shared production database is write-capable.

1. Stop/suspend Render's backend **and workers** after checking queues/in-flight deliveries. Preserve its service, configuration and files. Meta may retry events, but do not promise all missed messages will replay.
2. Point the new hostname's DNS A record at Oracle. Initially use DNS-only with Cloudflare until Caddy validates HTTPS. Do not weaken TLS or webhook signatures.
3. Start Oracle:

   ```bash
   docker compose up -d
   docker compose ps
   docker compose logs --tail=100 backend
   ```

   Startup runs `db:prepare`, primary migrations and schema verification. Auxiliary schemas load only if their sentinel table is missing. Investigate unexpected missing tables; do not manually load schemas over existing data. Stop on failure rather than repeatedly redeploying or marking migrations complete.
4. Verify `https://<APP_DOMAIN>/up` and `/ready` return 200 and readiness JSON is true. Compose `/up` is liveness only. `/ready` checks database/schema and queue-table availability, **not a worker heartbeat**.
5. Confirm the worker starts in logs and processes an approved test message/job. Keep only one live deployment's workers during validation.
6. Update Cloudflare Pages production `API_ORIGIN=https://<APP_DOMAIN>` and redeploy to apply it. Verify authenticated requests reach Oracle; saving an environment variable alone is not proof the live deployment uses it.
7. Update the existing Meta app callback to `https://<APP_DOMAIN>/webhooks/messenger`, plus `/webhooks/whatsapp` if used. Retain verify tokens and verify subscriptions. If reusing an existing stable hostname, verify its new routing instead of changing callbacks unnecessarily.
8. Update GitHub `PRODUCTION_API_URL`; retain the dashboard `PRODUCTION_WEB_URL`. The release workflow smoke-tests URLs and creates releases; **it does not deploy Oracle**.

## 6. Acceptance checks

- Owner/platform login, tenant separation and expected products/orders.
- New Messenger event received, processed and reply delivered once with a successful provider response.
- Product image upload/retrieval and customer photo recognition when enabled.
- Whole-business Pause AI: old/new chats recorded without bot delivery; manual staff replies work; Resume confirms and does not replay suppressed bots.
- Individual takeover preserved after business-wide resume.
- No encryption, migration or job errors; monitor queue backlog/delivery failures.
- Approved VM reboot test: Docker must be enabled at boot for `restart: unless-stopped`. Intentionally stopped containers do not automatically resume.

Do not blindly replay skipped deliveries: stale replies can reach real customers. Review/approve individual retries.

## Rollback

Stop Oracle backend/workers first. Restore the recorded Pages `API_ORIGIN` and redeploy, restore Meta callbacks if changed, then resume the recorded Render version. Verify only one deployment processes jobs. Render's 429 restriction may still make fallback unavailable; rollback restores routing, not guaranteed availability.

Do not reverse migrations or restore Neon simply to undo a hosting move: both hosts use the same database. If schema changed, separately check older-code compatibility. Never run `docker compose down -v`: it deletes persistent certificates/storage. Retain backups and the old service until acceptance.

## Future updates and operations

Record the current commit, back up as needed, review migrations, check out a tested commit, then build/recreate with `docker compose up -d --build`. Check readiness AND actual workers/delivery. Single-VM updates can cause brief downtime; this is not zero-downtime deployment.

Oracle releases are manual for now. SSH CI deployment is a separate change requiring scoped credentials and verified host keys. Never expose/reuse personal private keys in CI. Maintain OS updates, encrypted backups, storage monitoring and log rotation.
