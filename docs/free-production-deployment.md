# Free MVP deployment

This is the recommended zero-cost launch layout for ChatCart:

| Component | Provider | Free-tier behavior |
| --- | --- | --- |
| React dashboard and legal pages | Cloudflare Pages | Static hosting with HTTPS and SPA routing |
| Rails API, webhooks, and Solid Queue | Koyeb Free Web Service | One 512 MB/0.1 vCPU instance; sleeps after one hour without inbound traffic |
| PostgreSQL | Neon Free | Serverless PostgreSQL with scale-to-zero; current free allowance is sufficient for an MVP |
| Conversation AI | Google AI Studio / Gemini | Existing API key and free quota |
| Messaging | Meta Messenger and WhatsApp Cloud API | Meta app and business assets |

This is suitable for an MVP and Meta review. Free compute can sleep, restart, reach quotas, or change terms. Move the Rails service to paid always-on compute before promising production uptime to businesses.

The repository no longer includes a Render Blueprint because it conflicted with this plan and could accidentally provision the wrong resources. Koyeb is configured from its dashboard using the exact values below.

## 1. Security gate

Do not deploy until all of these are complete:

- Remove `backend/config/master.key` from Git tracking.
- Rotate the Rails master key because the previous key exists in Git history.
- Rotate any secret that was ever committed or pasted into a public location.
- Keep `.env` files local and enter production secrets only in provider dashboards.
- Keep the GitHub repository private unless the full Git history has been audited or rewritten.

Generate production values locally without printing them into source files:

```bash
cd backend
bin/rails db:encryption:init
bin/rails secret
```

The first command supplies the three Active Record encryption values. The second supplies `SECRET_KEY_BASE`. Store all results in a password manager and the Koyeb environment settings.

## 2. Create the Neon database

1. Create a free Neon account and a project named `chatcart-production`.
2. Select the region nearest the backend when possible. Koyeb Free currently offers Frankfurt or Washington, D.C.; use the matching/nearest Neon region.
3. Set the compute to the smallest practical size with scale-to-zero enabled.
4. Copy the pooled PostgreSQL connection string. Confirm it includes `sslmode=require`.
5. Keep it private. It becomes Koyeb's `DATABASE_URL`.

No Render database is needed. Render's free PostgreSQL expires after 30 days, so it is not used in this plan.

## 3. Deploy the Rails backend to Koyeb

Create a Web Service from the GitHub repository with:

- App: `chatcart`
- Service: `chatcart-api`
- Branch: the final merged production branch
- Builder: Dockerfile
- Work directory: `backend`
- Dockerfile: `backend/Dockerfile` (or `Dockerfile` when the work directory is already `backend`)
- Instance: Free
- Port: use the platform-provided `PORT`
- Health check path: `/up`

Set these environment variables:

```text
RAILS_ENV=production
RAILS_MAX_THREADS=2
WEB_CONCURRENCY=1
SOLID_QUEUE_IN_PUMA=true
SOLID_QUEUE_SUPERVISOR_MODE=async
JOB_THREADS=1
JOB_POLLING_INTERVAL=2
JOB_DISPATCH_INTERVAL=2
FORCE_SSL=true
DATABASE_URL=<Neon pooled connection string>
SECRET_KEY_BASE=<generated Rails secret>
RAILS_MASTER_KEY=<new local backend/config/master.key value>
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<generated value>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<generated value>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<generated value>
DASHBOARD_ORIGIN=<Cloudflare Pages production URL, added after frontend creation>
APP_HOST=<Koyeb hostname without https://>
PLATFORM_ADMIN_EMAIL=<private administrator email>
PLATFORM_ADMIN_PASSWORD=<unique password of at least 12 characters>
CHATCART_OWNER_EMAIL=<business owner email>
CHATCART_OWNER_PASSWORD=<different unique password of at least 12 characters>
MESSENGER_VERIFY_TOKEN=<new random value>
MESSENGER_PAGE_ACCESS_TOKEN=<Meta Page token>
MESSENGER_APP_SECRET=<Meta app secret>
WHATSAPP_VERIFY_TOKEN=<new random value>
WHATSAPP_ACCESS_TOKEN=<Meta permanent system-user token>
WHATSAPP_APP_SECRET=<Meta app secret>
WHATSAPP_PHONE_NUMBER_ID=<Meta phone number ID>
GEMINI_API_KEY=<Google AI Studio key>
GEMINI_MODEL=gemini-3.5-flash-lite
```

After the first successful deploy, run the seed command once using Koyeb's console/command facility:

```bash
./bin/rails db:seed
```

Before deploying, copy `backend/.env.production.example` to a temporary private location, fill it with production values, and run:

```bash
cd backend
RAILS_ENV=production mise exec -- bin/rails deployment:preflight
```

Do not commit the filled file. The preflight checks presence and structure without printing secret values.

The container entrypoint automatically runs `db:prepare` whenever the Rails server starts. Solid Queue runs inside Puma so a separate paid worker is not required.

Verify:

```text
https://<koyeb-host>/up
https://<koyeb-host>/ready
```

Both must succeed. `/ready` additionally confirms that PostgreSQL and Solid Queue tables are available.

## 4. Deploy the React frontend to Cloudflare Pages

Create a Pages project from the same GitHub repository:

- Production branch: the final merged production branch
- Root directory: `frontend`
- Framework preset: Vite
- Build command: `npm ci && npm run build`
- Build output directory: `dist`
- Environment variable: `VITE_API_URL=https://<koyeb-host>`

The committed `frontend/public/_redirects` makes React routes work on direct navigation.

Verify these public URLs without signing in:

```text
https://<cloudflare-host>/privacy
https://<cloudflare-host>/data-deletion
```

Then set Koyeb's `DASHBOARD_ORIGIN` to the exact Cloudflare production origin and redeploy the backend.

## 5. Configure Meta Messenger

In the Meta app dashboard, set:

- Callback URL: `https://<koyeb-host>/webhooks/messenger`
- Verify token: the exact `MESSENGER_VERIFY_TOKEN` stored in Koyeb
- Privacy Policy URL: `https://<cloudflare-host>/privacy`
- User Data Deletion URL: `https://<cloudflare-host>/data-deletion`

Subscribe the Page to the required Messenger webhook fields and make sure the correct Page access token is in Koyeb. Complete Meta business/app review and switch the app to Live before expecting replies for the general public.

## 6. Configure WhatsApp

In WhatsApp Configuration, set:

- Callback URL: `https://<koyeb-host>/webhooks/whatsapp`
- Verify token: the exact `WHATSAPP_VERIFY_TOKEN` stored in Koyeb

Add the permanent system-user access token, app secret, and phone number ID to Koyeb. Complete business verification and production phone-number setup where Meta requires it.

## 7. Launch verification

Test in this order:

1. Backend `/up` succeeds over HTTPS.
2. Privacy and deletion pages open in a private browser window.
3. Dashboard login works.
4. Product and business-policy data are visible.
5. Messenger webhook verification succeeds.
6. A non-developer Facebook account receives replies.
7. A full order reaches confirmation and appears in the dashboard.
8. CSV export works.
9. WhatsApp verification and inbound/outbound messages work.
10. No secret, token, phone number, or message content appears in deployment logs unexpectedly.

## Free-tier operational limits

- Koyeb Free sleeps after one hour without inbound traffic. Its documented deep-sleep wake is normally 1–5 seconds.
- Background jobs run inside the Rails web process in Solid Queue's async supervisor mode. This avoids several forked Ruby processes on the 512 MB instance. Jobs do not run while the free instance is asleep, but an inbound webhook wakes the service.
- Koyeb documents a typical deep-sleep wake of 1–5 seconds. A Rails cold boot can add time, and Meta may retry a slow webhook; this is acceptable for staging but not an uptime promise.
- Neon can scale to zero. The production queue polls every two seconds to reduce database compute use. Monitor the current free-plan compute, storage, and egress allowances in Neon because provider limits can change.
- Cloudflare Pages is static and remains available even while the backend sleeps, so Meta can access the legal pages.
- Monitor Koyeb memory and Neon storage/compute. Upgrade the backend first if real customers depend on timely replies.

## Releasing future versions

ChatCart uses `main` as its production branch. Configure Koyeb and Cloudflare Pages to auto-deploy every successful merge to `main`.

### Normal release flow

1. Create a `WC-###-description` feature branch.
2. Open a pull request and wait for every CI job to pass: Rails security scans, Ruby lint, backend tests, frontend lint, frontend type-check, and frontend build.
3. Merge the approved pull request to `main`.
4. Koyeb and Cloudflare automatically deploy the new `main` commit.
5. Confirm `/up`, dashboard login, legal pages, one test conversation, and one test order.
6. In GitHub, open **Actions → Release → Run workflow**, select `main`, and enter the next semantic version without `v`, such as `0.2.0`.
7. The release workflow repeats the backend and frontend checks, optionally smoke-tests production, creates tag `v0.2.0`, and publishes generated GitHub release notes.

Use semantic versions consistently:

- Patch (`0.2.1`): bug fixes and safe conversation improvements.
- Minor (`0.3.0`): backward-compatible features.
- Major (`1.0.0`): incompatible API, data, or operational changes.

In GitHub repository settings, add these Actions variables after deployment so releases can verify the live system:

```text
PRODUCTION_API_URL=https://<koyeb-host>
PRODUCTION_WEB_URL=https://<cloudflare-host>
```

These are public URLs, not secrets.

### Database migration rule

The backend container runs `db:prepare` before starting. Production migrations must therefore be backward-compatible with the previous release:

1. Add new columns/tables as nullable or with safe defaults.
2. Deploy code that can handle old and new data.
3. Backfill data separately when needed.
4. Remove old columns only in a later release.

Never rely on an automatic destructive rollback for customer orders or conversations.

### Rollback

If a release fails before a GitHub version is created, use Koyeb and Cloudflare's deployment history to redeploy the last working commit. If a tagged release is faulty, redeploy the previous tag/commit and then create a forward-fix branch. Do not reverse a production database migration unless its data impact has been reviewed and a backup is available.
