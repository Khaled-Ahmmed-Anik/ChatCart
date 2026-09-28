# Free MVP production deployment

> **Current production architecture:** ChatCart uses a Render Free Web Service, Neon PostgreSQL, and Cloudflare Pages. [`oracle-production-deployment.md`](oracle-production-deployment.md) remains the planned always-on migration path.

This is the recommended zero-cost launch layout for ChatCart:

| Component | Provider | Free-tier behavior |
| --- | --- | --- |
| React dashboard and legal pages | Cloudflare Pages | Static hosting with HTTPS and SPA routing |
| Rails API, webhooks, and Solid Queue | Render Free Web Service | One 512 MB/0.1 CPU instance; sleeps after 15 minutes without inbound traffic |
| PostgreSQL | Neon Free | Serverless PostgreSQL with scale-to-zero; current free allowance is sufficient for an MVP |
| Conversation AI | Google AI Studio / Gemini | Existing API key and free quota |
| Messaging | Meta Messenger and WhatsApp Cloud API | Meta app and business assets |

This is suitable for an MVP and Meta review. Free compute can sleep, restart, reach quotas, or change terms. Move the Rails service to Oracle or paid always-on compute before promising production uptime to businesses.

The repository includes `render.yaml`, which creates only the Rails web service. It deliberately does not create a Render database because Neon is the permanent database.

## 1. Security gate

Do not deploy until all of these are complete:

- Remove `backend/config/master.key` from Git tracking.
- Rotate the Rails master key because the previous key exists in Git history.
- Rotate any secret that was ever committed or pasted into a public location.
- Keep `.env` files local and enter production secrets only in provider dashboards.
- Treat the public GitHub repository and its complete history as public information. Never commit credentials, `.env` files, database URLs, customer data, or private exports.

Generate production values locally without printing them into source files:

```bash
cd backend
bin/rails db:encryption:init
bin/rails secret
```

The first command supplies the three Active Record encryption values. The second supplies `SECRET_KEY_BASE`. Store all results in a password manager and Render's environment settings.

## 2. Create the Neon database

1. Create a free Neon account and a project named `chatcart-production`.
2. Select the region nearest the backend when possible.
3. Set the compute to the smallest practical size with scale-to-zero enabled.
4. Copy the pooled PostgreSQL connection string. Confirm it includes `sslmode=require`.
5. Keep it private. It becomes Render's `DATABASE_URL`.

No Render database is needed. Render's free PostgreSQL expires after 30 days, so it is not used in this plan.

## 3. Deploy the Rails backend to Render

1. Push `render.yaml` to GitHub.
2. In Render, select **New → Blueprint**.
3. Connect the GitHub repository and select `main` as the production branch.
4. Render detects the root `render.yaml` and proposes one Free Web Service named `chatcart-api`.
5. Supply every value marked `sync: false`. Use the Neon pooled URL for `DATABASE_URL`; never create a Render database.
6. Apply the Blueprint and follow the first deployment logs.

The Blueprint deploys in Singapore and configures the Docker build context, `/ready` health check, generated `SECRET_KEY_BASE`, safe single-process memory limits, and the public Render hostname. WhatsApp variables can be added later from the service's Environment page when that channel is enabled.

Before deploying, copy `backend/.env.production.example` to a temporary private location, fill it with production values, and run:

```bash
cd backend
RAILS_ENV=production mise exec -- bin/rails deployment:preflight
```

Do not commit the filled file. The preflight checks presence and structure without printing secret values.

The container entrypoint automatically runs `db:prepare` whenever the Rails server starts. Solid Queue runs inside Puma, so a separate paid worker is not required. After the first healthy deploy, use Render Shell if available or a temporary Docker command deployment to run `./bin/rails db:seed` once; alternatively seed the Neon database locally using the same production `DATABASE_URL`.

Verify:

```text
https://<render-host>/up
https://<render-host>/ready
```

Both must succeed. `/ready` additionally confirms that PostgreSQL and Solid Queue tables are available.

## 4. Deploy the React frontend to Cloudflare Pages

Create a Pages project from the same GitHub repository:

- Production branch: `main`
- Root directory: `frontend`
- Framework preset: Vite
- Build command: `npm ci && npm run build`
- Build output directory: `dist`
- Runtime environment variable: `API_ORIGIN=https://<render-host>`

Do not define `VITE_API_URL` in the production Pages environment. The production
dashboard uses same-origin `/auth`, `/api`, and `/graphql` requests, which the
committed Pages Function proxies to `API_ORIGIN`. Local development continues to
use `VITE_API_URL=http://localhost:3000`.

The committed `frontend/public/_redirects` makes React routes work on direct navigation.

Verify these public URLs without signing in:

```text
https://<cloudflare-host>/privacy
https://<cloudflare-host>/data-deletion
```

Then set Render's `DASHBOARD_ORIGIN` to the exact Cloudflare production origin and redeploy the backend.

## 5. Configure Meta Messenger

In the Meta app dashboard, set:

- Callback URL: `https://<render-host>/webhooks/messenger`
- Verify token: the exact `MESSENGER_VERIFY_TOKEN` stored in Render
- Privacy Policy URL: `https://<cloudflare-host>/privacy`
- User Data Deletion URL: `https://<cloudflare-host>/data-deletion`

Subscribe the Page to the required Messenger webhook fields and make sure the correct Page access token is in Render. Complete Meta business/app review and switch the app to Live before expecting replies for the general public.

## 6. Configure WhatsApp

In WhatsApp Configuration, set:

- Callback URL: `https://<render-host>/webhooks/whatsapp`
- Verify token: the exact `WHATSAPP_VERIFY_TOKEN` stored in Render

Add the permanent system-user access token, app secret, and phone number ID to Render. Complete business verification and production phone-number setup where Meta requires it.

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

- Render Free sleeps after 15 minutes without inbound HTTP or WebSocket traffic. A cold start can take about one minute.
- Background jobs run inside the Rails web process in Solid Queue's async supervisor mode. This avoids several forked Ruby processes on the 512 MB instance. Jobs do not run while the free instance is asleep, but an inbound webhook wakes the service.
- Meta may retry a webhook that encounters a Render cold start. Incoming-event deduplication prevents the retry from being processed twice, but the first customer reply can be delayed.
- Neon can scale to zero. The production queue polls every two seconds to reduce database compute use. Monitor the current free-plan compute, storage, and egress allowances in Neon because provider limits can change.
- Cloudflare Pages is static and remains available even while the backend sleeps, so Meta can access the legal pages.
- Monitor Render memory, bandwidth, build minutes, and Neon storage/compute. Move to Oracle or paid always-on compute when real customers depend on timely replies.

## Releasing future versions

ChatCart uses `main` as its production branch. Configure Render and Cloudflare Pages to auto-deploy every successful merge to `main`.

GitHub protects `main` with the **Main: owner-reviewed pull requests** ruleset. Direct pushes, force pushes, and branch deletion are blocked. `.github/CODEOWNERS` assigns all paths to `@Khaled-Ahmmed-Anik`: other contributors therefore need the owner's approval, while the owner has a PR-only bypass for their own pull requests. The bypass does not permit direct pushes to `main`.

### Normal release flow

1. Create a `WC-###-description` feature branch.
2. Open a pull request and wait for every CI job to pass: Rails security scans, Ruby lint, backend tests, frontend lint, frontend type-check, and frontend build.
3. Resolve review conversations and merge the pull request to `main`. Pull requests from other contributors require approval from the repository owner.
4. Render and Cloudflare automatically deploy the new `main` commit.
5. Confirm `/up`, dashboard login, legal pages, one test conversation, and one test order.
6. In GitHub, open **Actions → Release → Run workflow**, select `main`, and enter the next semantic version without `v`, such as `0.2.0`.
7. The release workflow repeats the backend and frontend checks, optionally smoke-tests production, creates tag `v0.2.0`, and publishes generated GitHub release notes.

Use semantic versions consistently:

- Patch (`0.2.1`): bug fixes and safe conversation improvements.
- Minor (`0.3.0`): backward-compatible features.
- Major (`1.0.0`): incompatible API, data, or operational changes.

In GitHub repository settings, add these Actions variables after deployment so releases can verify the live system:

```text
PRODUCTION_API_URL=https://<render-host>
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

If a release fails before a GitHub version is created, use Render and Cloudflare's deployment history to redeploy the last working commit. If a tagged release is faulty, redeploy the previous tag/commit and then create a forward-fix branch. Do not reverse a production database migration unless its data impact has been reviewed and a backup is available.
