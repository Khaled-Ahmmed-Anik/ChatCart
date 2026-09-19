# ChatCart Messenger Order Assistant

ChatCart is a multi-business conversational-commerce platform. It receives Messenger webhooks, conducts English/Bengali/Banglish sales conversations, confirms durable orders, exposes an authenticated business dashboard, exports orders, and can submit confirmed orders to a delivery provider.

## Current capabilities

- Meta webhook verification and SHA-256 request-signature validation
- Messenger text-message ingestion and replies
- Strict business tenancy with per-business users, products, policies, channels, and delivery settings
- Role-based owner, admin, sales, fulfilment, and analyst access
- Product catalog with price, stock, tags, and active status
- Persistent conversations and message history
- Guided collection of product, quantity, name, phone, and address
- Durable confirmed orders with immutable item and price snapshots
- Dashboard analytics, order CSV export, conversation transcript, and human takeover
- Automatic or manual delivery submission with retryable background jobs
- A dependency-free responsive owner dashboard in `frontend/`
- Seed catalog for the current ChatCart products

Messenger is the currently implemented customer channel. Instagram and WhatsApp are represented in the channel model but require their channel-specific webhook and send adapters.

## Requirements

- Ruby 3.4.7
- Bundler 2.6.9
- PostgreSQL
- An ngrok account for local Messenger testing
- A Meta app connected to a Facebook Page

This repository uses `mise` for the local Ruby runtime in development.

## Setup

```bash
cd backend
cp .env.example .env
mise exec -- bundle install
mise exec -- bin/rails db:prepare
mise exec -- bin/rails db:seed
```

Configure `backend/.env` with your own values:

```dotenv
MESSENGER_VERIFY_TOKEN=choose-a-private-verification-token
MESSENGER_PAGE_ACCESS_TOKEN=your-facebook-page-access-token
MESSENGER_APP_SECRET=your-meta-app-secret
NGROK_HOST=your-assigned-domain.ngrok-free.dev
PLATFORM_ADMIN_TOKEN=generate-a-long-random-token
DASHBOARD_ORIGIN=http://localhost:4173
```

For production, generate database-encryption keys with `bin/rails db:encryption:init` and add the three generated `ACTIVE_RECORD_ENCRYPTION_*` values to the environment. Development and test derive stable local keys from the Rails application secret.

Never commit `backend/.env` or real credentials.

## Run locally

Start Rails:

```bash
cd backend
mise exec -- bin/rails server
```

In another terminal, start the tunnel using the domain assigned to your ngrok account:

```bash
ngrok http --url=https://your-assigned-domain.ngrok-free.dev 3000
```

Install and start the React business dashboard in a third terminal:

```bash
cd frontend
npm install
npm run dev
```

Open `http://localhost:4173`, select the account level, and sign in with email and password. Local seed accounts are configured through `PLATFORM_ADMIN_EMAIL`, `PLATFORM_ADMIN_PASSWORD`, `CHATCART_OWNER_EMAIL`, and `CHATCART_OWNER_PASSWORD` in the ignored `backend/.env` file.

Create a business and its first owner through the platform-admin API:

```bash
curl -X POST http://localhost:3000/admin/businesses \
  -H "Authorization: Bearer $PLATFORM_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"business":{"name":"Demo Shop","slug":"demo-shop","category":"retail"},"owner":{"name":"Owner","email":"owner@example.com"}}'
```

The owner can immediately use the supplied email and password. Authentication returns an opaque 12-hour session token; passwords are stored only as salted PBKDF2 derivations.

Check the application:

```bash
curl http://localhost:3000/up
curl http://localhost:3000/products
```

Configure the Meta Messenger callback URL as:

```text
https://your-assigned-domain.ngrok-free.dev/webhooks/messenger
```

Use the same `MESSENGER_VERIFY_TOKEN` value in Meta, subscribe the Page to the `messages` field, and keep both Rails and ngrok running during local testing.

## API endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/up` | Rails health check |
| `GET` | `/products` | List active, in-stock products |
| `POST` | `/products` | Create a product |
| `GET` | `/conversations/lookup` | Retrieve a conversation and order state |
| `POST` | `/conversation_messages` | Exercise the conversation flow without Messenger |
| `GET` | `/webhooks/messenger` | Meta webhook verification |
| `POST` | `/webhooks/messenger` | Receive Messenger events |
| `GET` | `/api/analytics` | Business conversion and customer analytics |
| `GET` | `/api/orders` | Authenticated business order dashboard |
| `GET` | `/api/orders/export` | Export the business's orders as CSV |
| `GET` | `/api/conversations` | Conversation inbox and transcripts |
| `POST` | `/api/conversations/:id/handover` | Pause automation for human takeover |
| `GET/POST` | `/api/products` | Manage the current business's catalog |
| `GET/PATCH` | `/api/business_policy` | Manage sales and delivery knowledge |
| `GET/PATCH` | `/api/delivery_integration` | Configure order delivery submission |

Use `POST /auth/login` for business users and `POST /auth/admin/login` for platform administrators. All `/api` and `/admin` endpoints require the returned bearer session. The original API-token path remains temporarily available for backward compatibility.

## Tests and code quality

```bash
cd backend
mise exec -- bundle exec rails test
mise exec -- bundle exec rubocop --cache false
mise exec -- bin/brakeman --no-pager
```

## Project layout

```text
backend/   Rails API, database migrations, services, and tests
frontend/  React/Vite multi-page seller and platform-admin dashboard
```

The main application flow is implemented in:

- `backend/app/controllers/webhooks/messenger_controller.rb`
- `backend/app/services/customer_message_recorder.rb`
- `backend/app/services/conversation_message_processor.rb`
- `backend/app/services/bot_reply_generator.rb`
- `backend/app/services/messenger_reply_sender.rb`

## Known next steps

- Implement the Instagram messaging adapter
- Implement the WhatsApp Cloud API adapter
- Add password/OAuth login and API-token rotation UX
- Add delivery-provider-specific adapters and WooCommerce synchronization
- Deploy the backend and dashboard to permanent HTTPS hosting
