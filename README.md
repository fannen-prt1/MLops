# Iris ML API — End-to-End MLOps on Azure

An end-to-end MLOps project that trains a **Random Forest classifier** on the Iris dataset, serves predictions through a **FastAPI** REST API, packages everything into a **Docker** container, provisions cloud infrastructure with **Terraform**, and automates the full lifecycle with a **GitHub Actions** CI/CD pipeline deploying to **Azure Container Apps**.

---

## Table of Contents

- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Local Setup](#local-setup)
  - [Running with Docker](#running-with-docker)
- [API Reference](#api-reference)
- [Model Training](#model-training)
- [Testing](#testing)
- [Infrastructure](#infrastructure)
- [CI/CD Pipeline](#cicd-pipeline)
- [Configuration](#configuration)

---

## Architecture

```
┌─────────────┐       push        ┌───────────────────────┐
│  Developer   │ ───────────────► │   GitHub Actions CI    │
└─────────────┘                   │  ┌─────────────────┐  │
                                  │  │ Train model      │  │
                                  │  │ Run pytest       │  │
                                  │  │ Validate TF      │  │
                                  │  │ Build & push     │  │
                                  │  │   Docker image   │  │
                                  │  └────────┬────────┘  │
                                  └───────────┼───────────┘
                                              │ OIDC login
                                              ▼
                                  ┌───────────────────────┐
                                  │  Azure Container Apps  │
                                  │  ┌─────────────────┐  │
                                  │  │  FastAPI (8000)  │  │
                                  │  │  /health         │  │
                                  │  │  /predict        │  │
                                  │  └─────────────────┘  │
                                  │  Container Registry    │
                                  │  Log Analytics         │
                                  │  Managed Identity      │
                                  └───────────────────────┘
```

---

## Project Structure

```
MLops/
├── app/                           # FastAPI application
│   ├── __init__.py
│   ├── main.py                    # API endpoints and model loading
│   ├── schemas.py                 # Pydantic request/response models
│   └── logging_config.py         # Logging setup (placeholder)
├── model_training/                # ML training pipeline
│   ├── __init__.py
│   └── train.py                   # Train and serialize the model
├── models/                        # Serialized model artifacts
│   └── .gitkeep
├── tests/
│   └── test_api.py                # API integration tests
├── infra/                         # Terraform IaC for Azure
│   ├── main.tf                    # Resource definitions
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   ├── providers.tf               # Azure provider config
│   ├── versions.tf                # Terraform version constraints
│   ├── terraform.tfvars.example   # Example variable values
│   └── github-deployer-role.json  # Custom RBAC role definition
├── .github/workflows/
│   └── ci.yml                     # CI/CD pipeline
├── Dockerfile                     # Container image definition
├── requirements.txt               # Python dependencies
├── pyproject.toml                 # Project metadata
├── .gitignore
└── .dockerignore
```

---

## Tech Stack

| Layer             | Technology                            |
|-------------------|---------------------------------------|
| ML Framework      | scikit-learn (RandomForestClassifier)  |
| API Framework     | FastAPI + Uvicorn                      |
| Validation        | Pydantic v2                           |
| Serialization     | Joblib                                |
| Containerization  | Docker (Python 3.12-slim)             |
| Infrastructure    | Terraform ≥ 1.6 + AzureRM ~> 4.0     |
| Cloud Platform    | Azure (Container Apps, ACR, Log Analytics) |
| CI/CD             | GitHub Actions                        |
| Testing           | pytest + FastAPI TestClient            |
| Authentication    | Azure OIDC (federated credentials)    |

---

## Getting Started

### Prerequisites

- Python 3.12+
- Docker (for container builds)
- Terraform ≥ 1.6 (for infrastructure)
- An Azure subscription (for deployment)

### Local Setup

```bash
# Clone the repository
git clone https://github.com/<your-username>/MLops.git
cd MLops

# Create and activate a virtual environment
python -m venv .venv
.venv\Scripts\activate        # Windows
# source .venv/bin/activate   # macOS/Linux

# Install dependencies
pip install -r requirements.txt

# Train the model
python -m model_training.train

# Start the API server
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

### Running with Docker

```bash
# Train the model first (model artifact is baked into the image)
python -m model_training.train

# Build the image
docker build -t iris-ml-api .

# Run the container
docker run -p 8000:8000 iris-ml-api
```

---

## API Reference

### `GET /health`

Health check endpoint.

**Response:**
```json
{ "status": "healthy" }
```

### `POST /predict`

Predict the species of an Iris flower from its measurements.

**Request body:**
```json
{
  "sepal_length": 5.1,
  "sepal_width": 3.5,
  "petal_length": 1.4,
  "petal_width": 0.2
}
```

All measurements must be positive floats ≤ 10 (centimeters).

**Response:**
```json
{
  "predicted_class": 0,
  "predicted_species": "setosa",
  "confidence": 1.0
}
```

### `GET /docs`

Auto-generated Swagger UI (provided by FastAPI).

---

## Model Training

The training script (`model_training/train.py`) does the following:

1. Loads the Iris dataset from scikit-learn
2. Splits into 80/20 train/test sets (stratified, `random_state=42`)
3. Trains a **Random Forest** classifier with 100 estimators
4. Saves the model, target names, and feature names as a bundle via Joblib to `models/iris_model.joblib`
5. Prints the test accuracy

```bash
python -m model_training.train
# Test accuracy: 100.00%
# Model saved to: .../models/iris_model.joblib
```

---

## Testing

```bash
python -m pytest -v
```

The test suite covers:
- **Health endpoint** — verifies the API returns `200` with `{"status": "healthy"}`
- **Prediction endpoint** — sends valid measurements and asserts correct class, species, and confidence range
- **Input validation** — sends negative measurements and asserts `422 Unprocessable Entity`

---

## Infrastructure

All Azure resources are defined in `infra/` using Terraform:

| Resource                          | Purpose                              |
|-----------------------------------|--------------------------------------|
| Resource Group                    | Logical container for all resources  |
| Azure Container Registry (Basic)  | Stores Docker images                 |
| Log Analytics Workspace           | Centralized logging                  |
| Container Apps Environment         | Hosting environment for the API      |
| Container App                     | Runs the FastAPI container           |
| User Assigned Managed Identity    | Passwordless ACR pull (AcrPull role) |

### Key design decisions

- **Scale-to-zero** — `min_replicas = 0` with HTTP-based auto-scaling (10 concurrent requests threshold)
- **Passwordless auth** — Managed Identity for ACR pull, OIDC for GitHub Actions deploys
- **Liveness probe** — hits `/health` every 30s with a 10s initial delay
- **Region split** — Resource Group in West Europe, Container Apps in France Central

### Provisioning

```bash
cd infra

# Copy and fill in variables
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

---

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci.yml`) has three jobs:

### 1. `test-and-build` (on every push/PR to `main`)
- Checks out code, sets up Python 3.12
- Installs dependencies, trains the model
- Runs the full test suite
- Builds the Docker image

### 2. `terraform-validation` (on every push/PR to `main`)
- Checks Terraform formatting (`fmt -check`)
- Initializes with no backend (`-backend=false`)
- Validates the configuration

### 3. `deploy` (only on push to `main`, after jobs 1 & 2 pass)
- Authenticates to Azure via **OIDC** (federated credentials)
- Builds and pushes the Docker image to Azure Container Registry
- Updates the Container App with the new image (tagged with the commit SHA)
- Runs a health check with retries (up to 3 minutes)

**Required GitHub Secrets:**
| Secret                   | Description                         |
|--------------------------|-------------------------------------|
| `AZURE_CLIENT_ID`        | Service principal / app client ID   |
| `AZURE_TENANT_ID`        | Azure AD tenant ID                  |
| `AZURE_SUBSCRIPTION_ID`  | Azure subscription ID               |

---

## Configuration

| File                           | Purpose                                  |
|--------------------------------|------------------------------------------|
| `requirements.txt`             | Python package dependencies              |
| `Dockerfile`                   | Container image definition               |
| `.gitignore`                   | Excludes venvs, caches, TF state, models |
| `.dockerignore`                | Keeps the image lean (no tests, infra)   |
| `infra/variables.tf`           | Terraform input variables with defaults  |
| `infra/terraform.tfvars.example` | Template for local variable overrides  |
