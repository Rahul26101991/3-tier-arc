# NextOps Industrial Telemetry — Zero-SSH 3-Tier Azure Deployment (Terraform + `cloud-init`)

Fully automated, zero-SSH deployment of the **NextOps Industrial Telemetry** 3-tier application on **Microsoft Azure** using **Terraform** and **`cloud-init`** templates (`db_init.tftpl`, `backend_init.tftpl`, and frontend provisioning).

---

## 1. Architecture Overview

The platform monitors industrial thermal power plant subsystems and telemetry metrics across three isolated tiers inside an Azure Virtual Network (`10.10.0.0/16`):

```text
Browser (User)
      │
      ▼  HTTP (Port 80)
┌─────────────────────────────────────────────────────────────┐
│ Tier 1: Frontend VM (Web Tier)                              │
│ • Ubuntu 22.04 LTS + Nginx                                  │
│ • Builds & serves React/TypeScript/Vite UI (axion-ui)       │
└─────────────────────────────────────────────────────────────┘
      │
      ▼  HTTP REST API (Port 8000: /api/v1, /docs, /devices, /trends)
┌─────────────────────────────────────────────────────────────┐
│ Tier 2: Backend VM (Application Tier)                       │
│ • Ubuntu 22.04 LTS + Python 3 + FastAPI                     │
│ • Managed by systemd (nextops-backend.service) via uvicorn  │
└─────────────────────────────────────────────────────────────┘
      │
      ▼  PostgreSQL Wire Protocol (Port 5432, Private VNet)
┌─────────────────────────────────────────────────────────────┐
│ Tier 3: Database VM (Data Tier — Private IP e.g. 10.10.3.4) │
│ • Ubuntu 22.04 LTS + PostgreSQL ("nextops" database)        │
│ • VNet-scoped authentication via pg_hba.conf                │
└─────────────────────────────────────────────────────────────┘
2. How Zero-SSH Provisioning Works (cloud-init)
Instead of manually SSH-ing into each VM after terraform apply, all OS packages, repository clones, builds, database initialization, and background services are configured automatically via cloud-init templates:

Database Tier (db_init.tftpl)
Installs postgresql, postgresql-contrib, and git.

Updates postgresql.conf (listen_addresses = '*') so PostgreSQL accepts connections over the private VNet interface.

Appends a VNet CIDR rule (scram-sha-256) to pg_hba.conf so the Backend VM can authenticate securely.

Restarts/enables postgresql, sets the postgres role password, and creates the target database (nextops) idempotently if it does not already exist.

Clones the SQL repository and runs initialization scripts (01-extensions.sql, 02-telemetry.sql).

Backend Tier (backend_init.tftpl)
Installs python3, python3-pip, git, and postgresql-client.

Clones the FastAPI repository into /opt/app/repo and installs Python dependencies via python3 -m pip install -r requirements.txt.

Writes DATABASE_URL cleanly (without stray quotes) into /opt/app/repo/.env.

Runs an until pg_isready loop against the Database VM's private IP (10.10.3.4:5432) so the backend waits until PostgreSQL is accepting connections.

Generates and starts /etc/systemd/system/nextops-backend.service using /usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port <app_port> with Restart=always.

Frontend Tier
Installs Node.js/npm and nginx, clones the frontend repository, builds the production bundle (tsc -b && vite build), and enables nginx to serve the compiled UI.

3. Repository Structure
Plaintext
.
├── main.tf                  # Azure Resource Group, VNet, subnets, NSGs, NICs, VMs, cloud-init wiring
├── variables.tf             # Configurable inputs (region, VNet CIDR, DB credentials, ports, repo URLs)
├── outputs.tf               # Exported Public IPs and Database Private IP
└── scripts/
    ├── db_init.tftpl        # PostgreSQL installation, VNet auth, DB creation, SQL schema bootstrap
    └── backend_init.tftpl   # Python packages, .env, pg_isready wait loop, systemd service setup
4. Deployment & Validation Steps
Step 1: Initialize & Deploy Infrastructure
Bash
terraform init
terraform plan
terraform apply
Step 2: Allow cloud-init to Complete (2–3 Minutes)
terraform apply completes as soon as Azure provisions the VMs, while cloud-init continues running package installations, npm run build, pip install, and service startup in the background. Wait 2–3 minutes before testing the endpoints.

Step 3: Retrieve Dynamic Outputs
Bash
terraform output
Step 4: Validate End-to-End Connectivity
Backend Root API: Open http://<backend_public_ip>:8000/api/v1 — verify it returns {"status":"OK","message":"NextOps Industrial - Telemetry Query Service is running"}.

Swagger / OpenAPI Docs: Open http://<backend_public_ip>:8000/docs — test GET /api/v1/health, GET /api/v1/dashboard/summary, and GET /api/v1/devices (all should return HTTP 200).

Frontend Dashboard: Open http://<frontend_public_ip> — perform a hard refresh (Ctrl + Shift + R), open browser DevTools (Network tab), select a subsystem (such as COAL-FEEDER-01), and verify 200 responses for /devices and /trends.

Step 5: Tear Down Resources
Bash
terraform destroy
5. Key Blockers Resolved & Lessons Learned
During iterative testing to achieve a true zero-SSH deployment, the following real-world issues were encountered and engineered out of the templates:

Systemd ModuleNotFoundError: No module named 'uvicorn' (User vs. Root Python Path):

Root Cause: Installing packages under a non-root user placed binaries in /home/azureuser/.local/bin, whereas the systemd unit ran as User=root and could not resolve the user-local Python environment.

Fix: Installed dependencies globally during cloud-init (which runs as root) using python3 -m pip install -r requirements.txt and configured ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port ${app_port} so systemd always uses the exact interpreter where packages were installed.

asyncpg.exceptions.InvalidPasswordError & .env Formatting:

Root Cause: Mismatches between the PostgreSQL ALTER USER password and the backend DATABASE_URL, or literal double quotes written into .env (DATABASE_URL="..."), caused authentication failures at FastAPI startup.

Fix: Unified ${db_password} across both Terraform templatefile() blocks and wrote .env via a clean cat <<EOF heredoc without surrounding quotes.

Race Condition Between Backend Startup and PostgreSQL Readiness:

Root Cause: Azure provisions VMs concurrently; the Backend VM often finished booting before PostgreSQL finished restarting and initializing on the Database VM.

Fix: Added a pg_isready -h "${db_host}" -p "${db_port}" -U postgres polling loop in backend_init.tftpl before starting nextops-backend.service, backed by Restart=always and RestartSec=5 in the systemd unit.

Idempotent Database Creation with set -e:

Root Cause: Running CREATE DATABASE unconditionally under set -e aborts cloud-init if the database already exists.

Fix: Checked pg_database before creating (SELECT 1 FROM pg_database WHERE datname = '${db_name}') so provisioning scripts remain safe and repeatable.

Premature Endpoint Checks (ERR_CONNECTION_REFUSED / Default Nginx Page):

Root Cause: Checking URLs immediately after terraform apply hits VMs while cloud-init is still executing pip install or vite build.

Fix: Documented the 2–3 minute cloud-init convergence window (verifiable via cloud-init status --wait if debugging is ever needed).

6. Security & Git Hygiene
Keep .terraform/, *.tfstate*, .env, and local secret *.tfvars files excluded in .gitignore.

Supply sensitive inputs such as db_password via TF_VAR_* environment variables or an untracked terraform.tfvars file rather than hardcoding secrets in version control.

---

## 7. Future Enhancements: High Availability (Load Balancer & Application Gateway)

The current deployment focuses on a clean, single-instance-per-tier zero-SSH baseline. For production high availability and fault tolerance, you can layer the following Azure components on top of this architecture:

### Option A: Azure Load Balancer (L4 TCP / Health-Probe Failover)
- **Frontend / Backend Pool:** Place multiple Frontend VMs or Backend VMs into an **Azure Load Balancer** backend pool instead of relying on a single VM's public IP.
- **Health Probes:** Configure TCP/HTTP health probes (for example, port `80` for Frontend Nginx and port `8000` `/api/v1/health` for Backend FastAPI) so unhealthy instances are automatically excluded from traffic.
- **Inbound NAT / Bastion:** Keep SSH access restricted via Azure Bastion or strict NSG source IP rules rather than exposing SSH broadly.

### Option B: Azure Application Gateway (L7 Routing, TLS Termination & WAF)
- **Path-Based Routing:** Route `/` and static UI traffic to the Frontend backend pool and `/api/*` (or `/docs`) traffic to the Backend API pool behind a single entry point.
- **TLS / SSL Termination:** Terminate HTTPS (`443`) at Application Gateway and keep backend/internal hops on private VNet traffic.
- **Web Application Firewall (WAF):** Enable WAF mode to inspect incoming HTTP/API requests for common web vulnerabilities before they reach the application tier.

### Database High Availability & Data Tier Hardening
- **PostgreSQL HA & Backups:** Move from a single DB VM to a managed/highly available PostgreSQL setup or configure automated backups, point-in-time recovery, and standby replication.
- **Automated Migrations & Seed Data:** Run schema migrations and optional seed scripts as a controlled step so deployments remain repeatable across environments.