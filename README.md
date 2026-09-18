# ChatCart Messenger Order Assistant

ChatCart is a Rails API that receives Facebook Messenger webhooks, guides a customer through a simple product-ordering conversation, stores the conversation and pending order in PostgreSQL, and replies through the Messenger Send API.

## Current capabilities

- Meta webhook verification and SHA-256 request-signature validation
- Messenger text-message ingestion and replies
- Product catalog with price, stock, tags, and active status
- Persistent conversations and message history
- Guided collection of product, quantity, name, phone, and address
- Local order confirmation or cancellation
- Seed catalog for the current ChatCart products

Confirmed orders remain in the local database. WooCommerce submission is not implemented yet.

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
```

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

Internal product and conversation endpoints are not authenticated yet and should not be exposed publicly without additional protection.

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
frontend/  Reserved for a future seller/admin interface
```

The main application flow is implemented in:

- `backend/app/controllers/webhooks/messenger_controller.rb`
- `backend/app/services/customer_message_recorder.rb`
- `backend/app/services/conversation_message_processor.rb`
- `backend/app/services/bot_reply_generator.rb`
- `backend/app/services/messenger_reply_sender.rb`

## Known next steps

- Messenger event deduplication and multi-event payload handling
- Background delivery jobs and retries
- Authentication for internal APIs
- Confirmed-order management endpoints
- Stable production hosting and monitoring
- WooCommerce product and order synchronization
