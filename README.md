# E-Commerce Platform — Microservices Architecture on Azure

![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoftazure&logoColor=white)
![.NET](https://img.shields.io/badge/.NET_8-512BD4?style=flat&logo=dotnet&logoColor=white)
![Java](https://img.shields.io/badge/Java_21-ED8B00?style=flat&logo=openjdk&logoColor=white)
![Python](https://img.shields.io/badge/Python_3.11-3776AB?style=flat&logo=python&logoColor=white)
![React](https://img.shields.io/badge/React_18-61DAFB?style=flat&logo=react&logoColor=black)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)

A production-ready e-commerce platform built with microservices architecture, deployed on Azure Kubernetes Service (AKS). The platform handles product catalogue management, order processing, invoice generation, and a React SPA frontend — all secured with Azure Active Directory (Entra ID).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Repository Structure](#repository-structure)
3. [Technology Stack](#technology-stack)
4. [Prerequisites](#prerequisites)
5. [Quick Start — Local Development](#quick-start--local-development)
6. [Azure Services](#azure-services)
7. [Infrastructure as Code — Terraform](#infrastructure-as-code--terraform)
8. [Authentication & RBAC](#authentication--rbac)
9. [Database](#database)
10. [CI/CD Pipeline](#cicd-pipeline)
11. [Local Development without Azure](#local-development-without-azure)
12. [Contributing](#contributing)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Azure Cloud                                  │
│                                                                      │
│  ┌──────────────┐      ┌────────────────────────────────────────┐   │
│  │  Azure Front │      │         Azure API Management           │   │
│  │    Door      │──────│  /api/products/* → Product Service     │   │
│  │  + CDN       │      │  /api/orders/*   → Order Service       │   │
│  └──────┬───────┘      └──────────────────┬─────────────────────┘   │
│         │                                  │                         │
│  ┌──────▼───────┐              ┌──────────▼──────────────────────┐  │
│  │ Azure Blob   │              │    Azure Kubernetes Service      │  │
│  │ Storage      │              │  ┌─────────────┐ ┌────────────┐ │  │
│  │ (React SPA)  │              │  │  Product    │ │  Order     │ │  │
│  └──────────────┘              │  │  Service    │ │  Service   │ │  │
│                                │  │  (.NET 8)   │ │ (Java 21)  │ │  │
│  ┌──────────────┐              │  └──────┬──────┘ └─────┬──────┘ │  │
│  │  Azure AD    │              │         │               │        │  │
│  │  (Entra ID)  │◄─────────── │  ┌──────▼───────────────▼──────┐ │  │
│  │  OAuth2/JWT  │              │  │      Invoice Service        │ │  │
│  └──────────────┘              │  │   (Python + Airflow)        │ │  │
│                                │  └────────────────┬────────────┘ │  │
│  ┌──────────────┐              └────────────────────│─────────────┘  │
│  │ Azure        │                                   │                │
│  │  Event Hub   │◄──────────────────────────────────┘                │
│  │ (Events)     │                                                     │
│  └──────────────┘                                                    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              Azure PostgreSQL Flexible Server                 │   │
│  │  Primary (R/W) ────────────────────► Read Replica (R only)   │   │
│  │  Schema: ecommerce                                           │   │
│  │  Tables: products, orders, order_lines, payments             │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  Azure ACR   │  │ Azure Key    │  │  Azure Monitor +         │  │
│  │  (Container  │  │   Vault      │  │  Application Insights    │  │
│  │   Registry)  │  │ (Secrets)    │  │  (Observability)         │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Traffic Flow

1. Users access the React SPA served from **Azure Blob Storage** via **Azure Front Door** (CDN + WAF).
2. API calls are routed through **Azure Front Door** → **Azure API Management (APIM)**, which enforces JWT validation, rate limiting, and CORS before forwarding to the appropriate microservice in **AKS**.
3. The **Order Service** publishes `order.placed` events to **Azure Event Hub** (`order-events` hub), which the **Invoice Service** (Airflow DAG) consumes via the `invoice-processor` consumer group to generate and store PDF invoices.
4. All services authenticate with **Azure AD (Entra ID)** using OAuth 2.0 / JWT bearer tokens.

---

## Repository Structure

```
e-commerce/
├── README.md                    # This file
├── docker-compose.yml           # Local development setup
├── azure-pipelines.yml          # Root Azure DevOps pipeline
├── infra/                       # Terraform IaC
│   ├── providers.tf             # azurerm + azuread provider config
│   ├── backend.tf               # Azure Storage remote state backend
│   ├── main.tf                  # Root module — wires child modules together
│   ├── variables.tf             # All input variables
│   ├── outputs.tf               # Key outputs (connection strings, URLs, etc.)
│   ├── terraform.tfvars.example # Template for your terraform.tfvars
│   ├── .gitignore               # Ignores *.tfvars, *.tfstate, .terraform/
│   └── modules/
│       ├── existing-infra/      # data sources for AKS, PostgreSQL, VNet, ACR
│       ├── eventhub/            # NEW Event Hub namespace + order-events hub
│       └── apim/                # NEW API Management instance + global policy
├── scripts/
│   └── bootstrap-tfstate.sh     # One-time: creates Azure Storage for TF state
├── product-service/             # .NET 8 Product microservice
├── order-service/               # Spring Boot 3.3 Order microservice
├── invoice-service/             # Python + Airflow Invoice microservice
└── ecommerce-ui/                # React 18 frontend
```

---

## Technology Stack

| Service | Language / Framework | Key Libraries / Tools |
|---|---|---|
| **product-service** | C# / .NET 8 | ASP.NET Core Minimal API, EF Core 8, FluentValidation, Serilog, xUnit |
| **order-service** | Java 21 / Spring Boot 3.3 | Spring Data JPA, Spring Security (OAuth2 Resource Server), Azure Event Hubs SDK, Flyway, JUnit 5 |
| **invoice-service** | Python 3.11 / Apache Airflow 2.9 | azure-servicebus, psycopg2, reportlab (PDF), pytest |
| **ecommerce-ui** | TypeScript / React 18 | Vite, TanStack Query, React Router 6, MSAL.js (Azure AD), Tailwind CSS, Vitest |
| **Infrastructure** | Terraform 1.6 | AKS, PostgreSQL Flexible Server, Event Hub, APIM, ACR, Key Vault, Front Door |
| **CI/CD** | Azure DevOps Pipelines | Docker buildx, Helm 3, `az` CLI, `kubectl` |
| **Observability** | Azure Monitor | Application Insights SDK (.NET, Java, Python), Log Analytics Workspace |

---

## Prerequisites

Ensure the following tools are installed and available in your `PATH`:

| Tool | Minimum Version | Install |
|---|---|---|
| Docker Desktop | 4.x+ | https://www.docker.com/products/docker-desktop |
| .NET SDK | 8.0 | https://dotnet.microsoft.com/download/dotnet/8.0 |
| JDK | 21 | https://adoptium.net/ |
| Python | 3.11+ | https://www.python.org/downloads/ |
| Node.js | 20 LTS | https://nodejs.org/ |
| Azure CLI | 2.55+ | https://learn.microsoft.com/en-us/cli/azure/install-azure-cli |
| kubectl | 1.28+ | https://kubernetes.io/docs/tasks/tools/ |
| Helm | 3.13+ | https://helm.sh/docs/intro/install/ |

> **Note:** For Azure deployments, you also need an active Azure subscription and appropriate RBAC permissions (Contributor on the target resource group, plus User Access Administrator to assign managed identity roles).

---

## Quick Start — Local Development

### 1. Clone the Repository

```bash
git clone https://github.com/<your-org>/e-commerce.git
cd e-commerce
```

### 2. Configure Environment Files

Each service ships a `.env.template` file. Copy and populate it before starting:

```bash
cp product-service/.env.template  product-service/.env
cp order-service/.env.template    order-service/.env
cp invoice-service/.env.template  invoice-service/.env
cp ecommerce-ui/.env.template     ecommerce-ui/.env
```

For a fully local run (no Azure), the templates are pre-filled with safe local defaults — you only need to set values if you want to integrate with real Azure services.

### 3. Start All Services with Docker Compose

```bash
docker-compose up --build
```

This starts PostgreSQL 15, Redis 7, Adminer (DB GUI), Product Service, Order Service, and Airflow Webserver. All services are wired to the `ecommerce-net` bridge network.

| Service | Local URL |
|---|---|
| Product Service API | http://localhost:5000 |
| Order Service API | http://localhost:8080 |
| Airflow Webserver | http://localhost:8081 |
| Adminer (DB GUI) | http://localhost:8090 |
| PostgreSQL | localhost:5432 |
| Redis | localhost:6379 |

### 4. Run the UI (outside Docker for hot-reload)

```bash
cd ecommerce-ui
npm install
npm run dev
# Vite dev server → http://localhost:5173
```

### 5. Run Services Individually (for debugging)

**Product Service (.NET 8):**
```bash
cd product-service/src
dotnet restore
dotnet run --launch-profile Development
# http://localhost:5000/swagger
```

**Order Service (Spring Boot):**
```bash
cd order-service
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
# http://localhost:8080/actuator/health
```

**Invoice Service (Airflow):**
```bash
cd invoice-service
pip install -r requirements.txt
export AIRFLOW_HOME=$(pwd)/.airflow
airflow db migrate
airflow standalone
# http://localhost:8082
```

---

## Azure Services

### Azure Kubernetes Service (AKS)
All three backend microservices are containerised and deployed as Kubernetes Deployments on AKS. The cluster uses the **azure** CNI plugin for Pod networking, enabling direct VNet integration. Azure AD workload identity is enabled (OIDC issuer + Federated Credentials) so pods can authenticate to Azure services without mounting secrets.

### Azure API Management (APIM)
APIM acts as the single gateway for all backend APIs. It provides:
- **JWT validation** against Azure AD (Entra ID) JWKS endpoint — unauthenticated requests are rejected before reaching services.
- **Rate limiting** (1,000 calls/minute per subscription key) to protect services from abuse.
- **CORS policy** allowing the Front Door origin, blocking direct browser access to AKS IPs.
- **Path-based routing**: `/api/products/*` → Product Service, `/api/orders/*` → Order Service.

### Azure Front Door + CDN
Front Door serves the React SPA (static files in Blob Storage) globally via its CDN edge. It also provides a single public HTTPS endpoint for the APIM backend, with built-in WAF (Web Application Firewall) policies for OWASP Top 10 protection.

### Azure PostgreSQL Flexible Server
Managed relational database running PostgreSQL 15. The primary server accepts both reads and writes; a **read replica** in the paired Azure region receives asynchronous replication and serves all read-heavy queries (product listings, order history). Backups are geo-redundant with a 7-day retention window.

### Azure Event Hub
Standard-tier namespace hosts the `order-events` hub (4 partitions, 7-day retention). When an order is confirmed, the Order Service publishes an `order.placed` event using the `order-service-sender` authorization rule (send-only). The Invoice Service (Airflow) consumes from the `invoice-processor` consumer group using the `invoice-service-listener` authorization rule (listen-only) to generate PDF invoices asynchronously.

### Azure Container Registry (ACR)
All Docker images are built and pushed to ACR by the CI pipeline. AKS is granted `AcrPull` role via managed identity — no registry credentials are stored in Kubernetes secrets. Premium SKU (prod) enables geo-replication so AKS nodes in multiple regions pull images from the nearest replica.

### Azure Key Vault
All sensitive configuration (DB passwords, Event Hub connection strings, App Insights keys) is stored in Key Vault. Services access secrets at startup via the **Azure Key Vault provider for Secrets Store CSI Driver** mounted as volumes in AKS pods — secrets never appear in environment variables or ConfigMaps.

### Azure Monitor + Application Insights
Each service ships the Application Insights SDK, emitting distributed traces, metrics, and structured logs to a shared Log Analytics Workspace. Dashboards, alert rules, and availability tests are configured in the workspace. End-to-end traces correlate a frontend action to the backend service calls and DB queries using the `operation_Id` propagated via HTTP headers.

---

---

## Infrastructure as Code — Terraform

### Why Terraform instead of Bicep?

| Concern | Bicep | Terraform |
|---|---|---|
| Multi-cloud / multi-provider | Azure only | Any provider (Azure, AzureAD, GitHub, …) |
| State management | Deployment history in ARM | Explicit `.tfstate` with remote locking |
| Drift detection | `what-if` (limited) | `terraform plan` shows full diff |
| Ecosystem | ARM-native | Large registry of community modules |
| Existing resource support | Re-deploy risk | `data` sources + `terraform import` |

The project uses Terraform `data` blocks to **read** existing resources (AKS, PostgreSQL, VNet, ACR) without managing them. Only new resources (Event Hub, APIM) are created with `resource` blocks.

---

### Step 1 — Bootstrap Terraform State Storage

Run this **once** before the first `terraform init`. It creates a storage account in Azure to hold the remote state file.

```bash
chmod +x scripts/bootstrap-tfstate.sh
./scripts/bootstrap-tfstate.sh
```

> If the storage account name `ecommercetfstate` is taken globally, edit the `TFSTATE_SA` variable in `scripts/bootstrap-tfstate.sh` **and** `storage_account_name` in `infra/backend.tf`, then run again.

---

### Step 2 — Configure Variables

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — fill in your resource names, tenant ID, email, etc.
# terraform.tfvars is git-ignored; never commit it.
```

Minimum required values in `terraform.tfvars`:

```hcl
resource_group_name    = "my-existing-rg"
aks_cluster_name       = "my-existing-aks"
postgresql_server_name = "my-existing-postgres"
acr_name               = "myexistingacr"
vnet_name              = "my-existing-vnet"
subnet_name            = "my-existing-aks-subnet"
tenant_id              = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
api_audience           = "api://xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
apim_publisher_email   = "admin@yourdomain.com"
```

---

### Step 3 — Initialise, Plan, Apply

```bash
# Initialise — downloads providers and connects to Azure Storage backend
terraform init

# Preview what Terraform will create/change/destroy
terraform plan -out=tfplan

# Apply — creates Event Hub and APIM; reads existing resources via data sources
terraform apply tfplan
```

Expected `terraform plan` result:
- **2 modules to add** (eventhub, apim — new Azure resources)
- **1 module to read** (existing-infra — data sources only, no changes)
- **0 resources to destroy**

---

### Step 4 — Retrieve Sensitive Outputs

Connection strings are marked `sensitive` and are not printed by default:

```bash
# Event Hub sender connection string (store in Key Vault / pipeline secret)
terraform output -raw eventhub_sender_connection_string

# Event Hub listener connection string
terraform output -raw eventhub_listener_connection_string

# APIM gateway URL
terraform output apim_gateway_url
```

---

### Option B — Import Existing Resources into Terraform State

If you later want Terraform to fully manage the existing AKS, PostgreSQL, VNet, or ACR resources (rather than just reading them via `data` sources), you can import them. This is optional and only needed if you want Terraform to handle lifecycle changes for these resources.

```bash
# Import the existing resource group
terraform import module.existing_infra.azurerm_resource_group.main \
  /subscriptions/<SUB_ID>/resourceGroups/<RG_NAME>

# Import the existing AKS cluster
terraform import module.existing_infra.azurerm_kubernetes_cluster.aks \
  /subscriptions/<SUB_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.ContainerService/managedClusters/<AKS_NAME>

# Import the existing PostgreSQL Flexible Server
terraform import module.existing_infra.azurerm_postgresql_flexible_server.postgres \
  /subscriptions/<SUB_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.DBforPostgreSQL/flexibleServers/<PG_NAME>

# Import the existing ACR
terraform import module.existing_infra.azurerm_container_registry.acr \
  /subscriptions/<SUB_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.ContainerRegistry/registries/<ACR_NAME>

# Import the existing VNet
terraform import module.existing_infra.azurerm_virtual_network.vnet \
  /subscriptions/<SUB_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.Network/virtualNetworks/<VNET_NAME>
```

After importing, convert the corresponding `data` blocks in `modules/existing-infra/main.tf` to `resource` blocks and run `terraform plan` to verify zero drift.

---

### Module Overview

| Module | Type | What it does |
|---|---|---|
| `modules/existing-infra` | `data` only | Reads AKS, PostgreSQL, VNet, Subnet, ACR, Resource Group |
| `modules/eventhub` | `resource` | Creates Event Hub namespace, `order-events` hub, consumer group, send/listen auth rules |
| `modules/apim` | `resource` | Creates APIM instance with system identity, global JWT+rate-limit+CORS policy, Product and Order API definitions |

---

## Authentication & RBAC

### Azure AD App Registration

Two App Registrations are required:

| Registration | Purpose |
|---|---|
| `ecommerce-ui` | SPA client; uses Authorization Code + PKCE flow |
| `ecommerce-api` | Represents the backend API; exposes scopes |

**Scopes exposed by `ecommerce-api`:**
- `products.read` — list and view products
- `products.write` — create/update/delete products (Admin, Manager)
- `orders.read` — view own orders
- `orders.write` — place orders (Customer, Manager, Admin)
- `orders.manage` — view all orders (Admin, Manager)
- `invoices.read` — download invoices

### Application Roles

Roles are defined in the `ecommerce-api` App Registration manifest and assigned to users/groups in Azure AD:

| Role | Permissions |
|---|---|
| `Admin` | Full access to all scopes + user management |
| `Manager` | `products.write`, `orders.manage`, `invoices.read` |
| `Customer` | `products.read`, `orders.read`, `orders.write` |

### JWT Validation Flow

```
Browser                Azure AD               APIM                  AKS Service
   │                      │                    │                        │
   │──── Login (PKCE) ───►│                    │                        │
   │◄─── access_token ────│                    │                        │
   │                      │                    │                        │
   │──── GET /api/products?  Authorization: Bearer <token> ───────────► │
   │                      │                    │                        │
   │                      │◄─── Validate JWT ──│ (JWKS fetch)           │
   │                      │──── 200 OK ────────►                        │
   │                      │                    │──── Forward + claims ──►│
   │                      │                    │                        │
   │◄─────────────────────────── 200 JSON ─────────────────────────────│
```

1. The React SPA uses **MSAL.js** to perform Authorization Code + PKCE against the `ecommerce-ui` App Registration.
2. MSAL acquires an access token scoped to `api://<ecommerce-api-client-id>/<scope>`.
3. Every API call includes `Authorization: Bearer <token>`.
4. APIM's `validate-jwt` policy fetches Azure AD's JWKS endpoint and verifies the token's signature, expiry, audience, and issuer. Invalid tokens receive a `401` response immediately at the gateway.
5. APIM forwards the validated token to the AKS microservice. Services can further inspect `roles` claims to enforce fine-grained authorisation.

---

## Database

### Schema: `ecommerce`

| Table | Description |
|---|---|
| `products` | Product catalogue (id, sku, name, description, price, stock_qty, category_id, created_at, updated_at) |
| `categories` | Product categories (id, name, parent_id) |
| `orders` | Order header (id, customer_id, status, total_amount, currency, created_at, updated_at) |
| `order_lines` | Order line items (id, order_id, product_id, quantity, unit_price, subtotal) |
| `payments` | Payment records (id, order_id, provider, provider_ref, amount, status, paid_at) |
| `invoices` | Invoice metadata (id, order_id, pdf_blob_url, generated_at) |

### Read/Write Separation

Services route queries based on operation type:

- **Writes** (INSERT / UPDATE / DELETE) → `DB_PRIMARY_HOST` (primary server)
- **Reads** (SELECT) → `DB_REPLICA_HOST` (read replica)

The Product Service and Order Service both use separate `DataSource` beans (Spring) / `DbContext` configurations (.NET) pointing to the respective connection strings resolved from Key Vault at startup.

### Migrations

Database schema migrations are managed with:
- **Flyway** (Order Service) — SQL migration scripts in `order-service/src/main/resources/db/migration/`
- **EF Core Migrations** (Product Service) — `dotnet ef migrations add <Name>`

Migrations run automatically on service startup in `Development` / `local` profiles. In production, the CI pipeline runs `flyway migrate` / `dotnet ef database update` as a pre-deployment step with appropriate credentials from Key Vault.

---

## CI/CD Pipeline

### Overview

Each sub-repository has its own `azure-pipelines.yml`. The root `azure-pipelines.yml` coordinates infrastructure deployment and can trigger service pipelines via pipeline resource dependencies.

### Pipeline Stages per Service

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│  Build   │──►│  Test    │──►│  Scan    │──►│  Push    │──►│  Deploy  │
│ (docker  │   │ (unit +  │   │ (Trivy   │   │  Image   │   │  (Helm   │
│  buildx) │   │  integ.) │   │  SAST)   │   │  to ACR  │   │  + AKS)  │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
```

1. **Build** — `docker buildx build` with layer caching via ACR cache.
2. **Test** — Unit tests + integration tests (using Testcontainers for DB).
3. **Scan** — [Trivy](https://trivy.dev/) container vulnerability scan; pipeline fails on HIGH/CRITICAL CVEs.
4. **Push** — Tag image as `<acr>.azurecr.io/<service>:<git-sha>` and push to ACR.
5. **Deploy** — `helm upgrade --install` with a rolling update strategy on AKS. Zero-downtime deployments are enforced via `maxSurge: 1` / `maxUnavailable: 0` in Helm chart values.

### Environments

| Branch | Target Environment | Approval Required |
|---|---|---|
| `develop` | `dev` AKS namespace | No |
| `staging` | `staging` AKS namespace | Yes (tech lead) |
| `main` | `prod` AKS namespace | Yes (two approvers) |

---

## Local Development without Azure

All Azure dependencies have local substitutes, activated by setting `AZURE_MOCK=true` or using the `local` / `Development` profiles.

| Azure Service | Local Substitute |
|---|---|
| Azure AD (JWT) | A mock JWT middleware that accepts any token with `sub` and `roles` claims; a helper script `scripts/gen-local-token.sh` mints valid local JWTs |
| Azure Event Hub | `EVENTHUB_ENABLED=false` in docker-compose; the Invoice Service polls the DB directly instead of consuming events |
| Azure Key Vault | Plain `.env` files sourced at startup (never commit these) |
| Azure Blob Storage | MinIO (optional — add to docker-compose if needed for invoice PDF storage) |
| Application Insights | Console logging only; `APPLICATIONINSIGHTS_CONNECTION_STRING` left unset |
| Azure PostgreSQL | `postgres:15-alpine` container in docker-compose |

### Mock JWT

For local API testing with tools like Postman or curl, generate a mock JWT:

```bash
# Install dependency once
pip install pyjwt

# Generate a token valid for 1 hour
python scripts/gen-local-token.py --sub user-123 --roles Customer
```

Pass the printed token as `Authorization: Bearer <token>` in your requests.

---

## Contributing

### Branch Naming Convention

```
feature/<ticket-id>-short-description    # New features
fix/<ticket-id>-short-description        # Bug fixes
chore/<ticket-id>-short-description      # Maintenance tasks
hotfix/<ticket-id>-short-description     # Production hot fixes
```

Example: `feature/EC-42-add-product-search`

### Pull Request Process

1. Branch off from `develop` (or `main` for hot fixes).
2. Keep PRs focused — one logical change per PR.
3. Ensure all pipeline checks pass (build, test, scan) before requesting review.
4. At least **one approving review** is required; two for `main`.
5. Squash merge into `develop`; merge commit into `main`.
6. Delete the source branch after merge.

### Coding Standards

| Service | Standard |
|---|---|
| **product-service** (.NET) | Follow Microsoft C# Coding Conventions; use `dotnet format`; XML doc comments on public APIs |
| **order-service** (Java) | Google Java Style Guide; Checkstyle enforced in Maven build; Javadoc on public methods |
| **invoice-service** (Python) | PEP 8; `black` formatter; `flake8` linter; type hints on all function signatures |
| **ecommerce-ui** (TypeScript/React) | Airbnb ESLint config; Prettier formatter; component-level Vitest tests |

All services must maintain **>= 80% line coverage** (enforced as a pipeline quality gate).

### Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

Types: feat | fix | docs | style | refactor | test | chore | ci
Scope: product-service | order-service | invoice-service | ecommerce-ui | infra
```

Example: `feat(order-service): add payment status webhook endpoint`

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
