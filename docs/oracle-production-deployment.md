# Oracle Always Free backend deployment

> **Planned migration, not the current production environment.** ChatCart currently runs its Rails backend on Render. Use this guide when moving to an always-on Oracle VM; verify Oracle's current free-tier availability and account requirements before migration.

This deployment runs the Rails API, Meta webhooks, and Solid Queue on one Oracle Cloud VM. Neon remains the PostgreSQL provider, and Cloudflare Pages hosts the React frontend.

## 1. Create the VM

Create an Always Free compute instance in Oracle Cloud:

- Image: Ubuntu 24.04 (Canonical)
- Shape: `VM.Standard.A1.Flex` (Ampere ARM)
- Size: 1 OCPU/6 GB RAM is sufficient; 2 OCPUs/12 GB is preferred when available
- Public IPv4 address enabled
- Your SSH public key uploaded, or Oracle's generated private key downloaded safely

Use a stable or reserved public IP where available. Meta's callback URL must remain stable.

## 2. Open only the required ports

Add these ingress rules to the subnet security list or network security group:

| Source | Protocol | Port | Purpose |
| --- | --- | --- | --- |
| `0.0.0.0/0` | TCP | 80 | Certificate validation and HTTPS redirect |
| `0.0.0.0/0` | TCP | 443 | HTTPS API and webhooks |
| Your public IP `/32` | TCP | 22 | SSH administration |

Do not expose PostgreSQL or the Rails container directly.

## 3. Configure DNS

Create an `A` record such as `api.example.com` pointing to the VM's public IP. With Cloudflare DNS, initially use **DNS only** until Caddy obtains its certificate.

## 4. Install Docker

Connect to the VM:

```bash
ssh ubuntu@<VM_PUBLIC_IP>
```

Install Docker Engine and the Compose plugin using Docker's official Ubuntu installation instructions. Then run:

```bash
sudo usermod -aG docker ubuntu
```

Log out and reconnect. Verify:

```bash
docker --version
docker compose version
```

## 5. Clone and configure ChatCart

```bash
git clone https://github.com/Khaled-Ahmmed-Anik/ChatCart.git
cd ChatCart
git checkout main
git pull --ff-only origin main
cp deploy/oracle/.env.example deploy/oracle/.env
nano deploy/oracle/.env
```

Set all real production values. Important rules:

- `DATABASE_URL` uses Neon's pooled connection string.
- `APP_DOMAIN` and `APP_HOST` contain only the API hostname, without `https://`.
- `DASHBOARD_ORIGIN` is the exact deployed frontend origin.
- Use unique production secrets and passwords.
- Never commit `deploy/oracle/.env`.

Generate missing Rails values locally from `backend/`:

```bash
bin/rails secret
bin/rails db:encryption:init
```

## 6. Deploy

On the Oracle VM:

```bash
cd ~/ChatCart/deploy/oracle
docker compose up -d --build
docker compose ps
docker compose logs --tail=100 backend
```

The container automatically executes `db:prepare`, primary migrations, and the critical schema contract check. A pending migration or missing required column stops startup and makes `/ready` return `503`. Seed initial accounts once:

```bash
docker compose exec backend ./bin/rails db:seed
```

Verify both endpoints:

```bash
curl --fail https://<APP_DOMAIN>/up
curl --fail https://<APP_DOMAIN>/ready
```

`/ready` confirms PostgreSQL connectivity and Solid Queue availability.

## 7. Configure Meta

Messenger callback:

```text
https://<APP_DOMAIN>/webhooks/messenger
```

WhatsApp callback:

```text
https://<APP_DOMAIN>/webhooks/whatsapp
```

Meta's verify tokens must exactly match the values in `deploy/oracle/.env`.

## Release updates

```bash
cd ~/ChatCart
git pull --ff-only
cd deploy/oracle
docker compose up -d --build
curl --fail https://<APP_DOMAIN>/ready
```

## Operations

```bash
docker compose ps
docker compose logs --tail=200 backend
docker compose logs -f backend
docker compose restart
docker compose down
```

Do not use `docker compose down -v`; that deletes persistent Caddy certificates and local Active Storage data.
