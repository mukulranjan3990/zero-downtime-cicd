# Multi-Stage Docker & Zero-Downtime GitHub Actions Pipeline

A portfolio project demonstrating containerized API delivery with GitHub
Actions, Docker Hub, AWS EC2, Nginx, and a Blue/Green deployment
strategy.

> **Implementation status:** The FastAPI application, multi-stage Docker
> image, GitHub Actions test/build/publish workflow, EC2 Docker/Nginx
> setup, and manual Blue/Green deployment checks have been worked
> through. End-to-end deployment triggered by GitHub Actions and a
> measured zero-downtime traffic test still need to be verified. The
> public EC2 URL was not responding at the last troubleshooting step, so
> this README deliberately does not claim that production-style zero
> downtime has been proven.

## Project at a glance

  ---------------------------------------------------------------------------------------------------------------------------
  Item                                Details
  ----------------------------------- ---------------------------------------------------------------------------------------
  Application                         Python FastAPI REST API

  Health endpoint                     `GET /healthz`

  Containerization                    Multi-stage Dockerfile

  CI/CD                               GitHub Actions

  Image registry                      Docker Hub

  Image repository                    [`mukul3990/zero-downtime-api`](https://hub.docker.com/r/mukul3990/zero-downtime-api)

  Deployment host                     AWS EC2, Ubuntu

  Reverse proxy                       Nginx

  Deployment strategy                 Blue/Green container replacement

  Application port in container       `8000`

  Blue host port                      `127.0.0.1:8081`

  Green host port                     `127.0.0.1:8082`

  Public web entry point              Nginx on TCP port `80`
  ---------------------------------------------------------------------------------------------------------------------------

## Why this project matters

A deployment should not send users to a new application version before
that version is ready. This project separates the build and publish
stages from the runtime deployment and uses a health check before
switching Nginx traffic to the standby container.

The project is designed to demonstrate:

-   Automated test and lint checks in CI.
-   Repeatable Docker image builds and registry publishing.
-   A smaller runtime image using a multi-stage Docker build.
-   A health-checked Blue/Green deployment approach.
-   Nginx upstream switching and configuration validation.
-   A repeatable traffic test to measure errors during a deployment.
-   Clear deployment steps and evidence suitable for technical review.

## Architecture

``` text
Developer
   |
   | git push
   v
GitHub repository
   |
   v
GitHub Actions workflow (.github/workflows/deploy.yml)
   |-- Test and lint
   |-- Build Docker image
   |-- Push image to Docker Hub
   |
   |  Deployment job over SSH must be verified/configured
   v
AWS EC2 (Ubuntu)
   |
   +--> Docker: Blue container 127.0.0.1:8081 -> container:8000
   |
   +--> Docker: Green container 127.0.0.1:8082 -> container:8000
   |
   +--> Nginx :80 -> active Blue or Green upstream
                         |
                         v
                    FastAPI API
```

### Expected release flow

1.  A code change is pushed to the configured Git branch.
2.  GitHub Actions runs the test and lint checks.
3.  The workflow builds and publishes an image to Docker Hub, tagged
    with a commit identifier and `latest` where configured.
4.  The deployment job securely connects to EC2 over SSH.
5.  EC2 runs `deploy.sh` with the target image tag.
6.  The script identifies the inactive slot, pulls the image, starts the
    standby container, and checks `/healthz` (up to five attempts).
7.  Only after the health check succeeds should Nginx be switched and
    reloaded.
8.  The new route is verified before the old container is removed.

**Important:** Steps 4--8 are the intended automated release flow.
Confirm the SSH deployment job is present in the current workflow and
succeeds before describing the entire pipeline as fully automated.

## Technology stack

-   **Python / FastAPI** --- sample API and health endpoint.
-   **Pytest** --- automated tests.
-   **Flake8** --- Python linting.
-   **Docker** --- application packaging and runtime isolation.
-   **Multi-stage Docker build** --- separates build-time dependencies
    from the runtime image.
-   **Docker Buildx** --- image build workflow; multi-platform output
    depends on the workflow configuration.
-   **Docker Hub** --- container image registry.
-   **GitHub Actions** --- CI workflow and intended CD orchestration.
-   **AWS EC2 / Ubuntu** --- deployment host.
-   **Nginx** --- reverse proxy and active-upstream switch.
-   **Bash / curl** --- deployment health checks and traffic validation.

## API endpoints

  Method   Path         Purpose
  -------- ------------ --------------------------------------------
  `GET`    `/`          Basic API response
  `GET`    `/healthz`   Health check used by deployment validation

The health endpoint is intended to return a successful HTTP response and
a JSON status such as:

``` json
{"status":"healthy"}
```

## Repository layout

The following is a recommended layout for the repository. Adjust paths
to match the actual files in the checked-in branch.

``` text
.
├── app/
│   └── main.py
├── tests/
│   └── test_main.py
├── .github/
│   └── workflows/
│       └── deploy.yml
├── Dockerfile
├── .dockerignore
├── requirements.txt
├── deploy/
│   ├── deploy.sh
│   └── zero-downtime-test.sh
└── README.md
```

The EC2 deployment scripts have been used at these server paths:

``` text
/opt/novapay/deploy/deploy.sh
/opt/novapay/deploy/zero-downtime-test.sh
```

The server-side paths are not automatically part of the Git repository.
Keep the source-controlled copy of the scripts in the repository and
deploy/synchronize it to EC2 as part of the setup process.

## Run locally

Prerequisites: Python 3.12, Docker, and Git.

### 1. Clone the repository

Replace the URL with the actual GitHub repository URL:

``` bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
cd <YOUR_REPOSITORY_DIRECTORY>
```

### 2. Create a virtual environment and install dependencies

**Windows PowerShell:**

``` powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

**Linux/macOS:**

``` bash
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

### 3. Run tests and lint

Run the commands supported by the repository's current configuration:

``` bash
pytest
flake8 .
```

### 4. Run the API directly

``` bash
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Test it in another terminal:

``` bash
curl -i http://127.0.0.1:8000/healthz
```

### 5. Build and run the Docker image

``` bash
docker build -t zero-downtime-api:local .
docker run --rm -p 8000:8000 zero-downtime-api:local
```

Then test:

``` bash
curl -i http://127.0.0.1:8000/healthz
```

## CI/CD workflow

Workflow file: `.github/workflows/deploy.yml`

The workflow has been used for testing/linting and building/publishing
the image. The Docker Hub repository is:

[`mukul3990/zero-downtime-api`](https://hub.docker.com/r/mukul3990/zero-downtime-api)

### Required GitHub repository secrets

Set these under **GitHub repository → Settings → Secrets and variables →
Actions**. Never commit credentials or private keys to the repository.

  -----------------------------------------------------------------------
  Secret                              Purpose
  ----------------------------------- -----------------------------------
  `DOCKERHUB_USERNAME`                Docker Hub username

  `DOCKERHUB_TOKEN`                   Docker Hub access token

  `EC2_HOST`                          Reachable public DNS name or public
                                      IPv4 of the EC2 instance

  `EC2_USER`                          Usually `ubuntu` for Ubuntu EC2
                                      images

  `EC2_SSH_KEY`                       Private SSH key authorized for the
                                      instance
  -----------------------------------------------------------------------

Only configure the EC2 secrets if the workflow contains the SSH
deployment job. Ensure the SSH key is stored as a secret and is never
printed in workflow logs.

### Workflow review checklist

-   [x] Workflow triggers match the intended branch and pull-request
    policy.
-   [x] Tests and lint checks must pass before publishing.
-   [x] Docker Hub login uses secrets, not hard-coded credentials.
-   [x] Images are tagged with an immutable commit identifier.
-   [x] The deploy job uses the same image tag produced by the build
    job.
-   [x] SSH deployment invokes the EC2 `deploy.sh` script.
-   [x] Deployment fails if the health check, Nginx validation, reload,
    or post-switch check fails.
-   [x] GitHub Actions logs show a successful deployment, not only a
    successful image push.

## EC2 deployment design

### Ports

  Port     Binding                   Use
  -------- ------------------------- -------------------------------
  `8000`   Inside each container     FastAPI / Uvicorn
  `8081`   `127.0.0.1:8081` on EC2   Blue slot
  `8082`   `127.0.0.1:8082` on EC2   Green slot
  `80`     EC2 network interface     Public HTTP through Nginx
  `22`     EC2 network interface     SSH administration/deployment

Ports `8081` and `8082` should remain bound to localhost and should not
be opened to the public internet in the EC2 security group. Restrict SSH
(`22`) to trusted source IPs where practical. Add HTTPS (`443`) only
after TLS is configured.

### Inspect the running services

Run these commands in the EC2 SSH session:

``` bash
sudo systemctl status nginx --no-pager
docker ps
sudo cat /etc/nginx/conf.d/novapay-upstream.conf
```

Check the application through Nginx:

``` bash
curl -i http://127.0.0.1/healthz
```

Check the Green slot directly:

``` bash
curl -i http://127.0.0.1:8082/healthz
```

If the active upstream is Blue, test `127.0.0.1:8081` instead. The
active slot is determined by the current Nginx upstream configuration,
not by the port number alone.

### Deployment script

The EC2 script is intended to:

1.  Determine which slot is active.
2.  Pull the requested image.
3.  Start the new version on the inactive slot.
4.  retry the health check up to five times.
5.  Switch the Nginx upstream only after health passes.
6.  Validate Nginx configuration and reload it.
7.  Check the application through Nginx.
8.  Remove the previous container only after verification.

Review the script before production use. A portfolio implementation is
not automatically production hardened; ensure failures during the switch
restore or preserve the previous working route and return a non-zero
exit status.

## Zero-downtime validation

A deployment strategy is not proof of zero downtime by itself. Record
results from a continuous request test while a new image is deployed.

The test script used in this project is intended to run from EC2:

``` bash
sudo bash /opt/novapay/deploy/zero-downtime-test.sh 120
```

Use a second EC2 SSH terminal to trigger a deployment while the traffic
test runs. Run a baseline test first, then run the test during a
deployment.

Record these actual values in the table; do not fill them with
estimates:

  Metric                        Result
  ----------------------------- ---------------------
  Test duration                 Pending measurement
  Total requests                Pending measurement
  Successful 2xx responses      Pending measurement
  Failed/non-2xx requests       Pending measurement
  HTTP 5xx responses            Pending measurement
  Success rate                  Pending measurement
  Image size                    Pending measurement
  GitHub Actions run duration   Pending measurement

A claim of "zero downtime" should only be made after the test shows no
failed requests during the switch and the test conditions/results are
documented. A finite `curl` test is useful evidence but does not prove
every possible production condition.

## Troubleshooting

### EC2 public IP does not open

1.  Confirm the instance is running and the public IPv4/DNS is current.
2.  Confirm the security group allows inbound TCP port `80` from the
    intended clients.
3.  Confirm Nginx is running: `sudo systemctl status nginx --no-pager`.
4.  Check Nginx configuration: `sudo nginx -t`.
5.  Test locally on EC2: `curl -i http://127.0.0.1/healthz`.
6.  Check the active upstream:
    `sudo cat /etc/nginx/conf.d/novapay-upstream.conf`.
7.  Review logs: `sudo tail -n 100 /var/log/nginx/error.log`.
8.  Use `http://<EC2-PUBLIC-IP>/` unless TLS has been configured. Do not
    assume HTTPS is available just because the IP is public.

### Docker image pull or tag fails

-   Confirm the image exists in the Docker Hub repository.
-   Use an exact tag that is visible in Docker Hub; do not assume a tag
    format.
-   Ensure the workflow deploys the same tag it built and pushed.
-   For private repositories, authenticate Docker on EC2 before pulling.

### GitHub Actions image publishing works but deployment does not

-   A successful build/push job does not mean EC2 was deployed.
-   Confirm a separate deploy job exists and runs after image
    publishing.
-   Confirm the deploy job uses `EC2_HOST`, `EC2_USER`, and
    `EC2_SSH_KEY`.
-   Confirm EC2 is reachable from GitHub-hosted runners over SSH and the
    server script exists at the referenced path.
-   Inspect the failing job logs, without exposing secrets.

## Security considerations

-   Keep Docker Hub tokens and SSH private keys in GitHub Secrets.
-   Never commit `.env` files, private keys, passwords, or tokens.
-   Restrict inbound SSH to trusted IP addresses when feasible.
-   Keep application ports `8081` and `8082` private to the EC2 host.
-   Prefer immutable image tags for deployment traceability.
-   Validate Nginx configuration before reloading it.
-   Use HTTPS with a valid certificate for real public use.
-   Review and patch the EC2 operating system and Docker/Nginx packages.
-   Treat this as a learning/portfolio project unless and until
    additional production hardening, monitoring, access controls, and
    rollback tests are completed.

## Evidence to include for hiring-manager review

Add screenshots or logs to a repository folder such as `docs/evidence/`
(redact secrets and sensitive IP details where appropriate):

-   [x] Successful GitHub Actions test/lint run.
-   [x] Successful Docker image build and Docker Hub tags.
-   [x] Docker image size output.
-   [x] `docker ps` showing the active container and health status.
-   [x] Nginx upstream configuration and successful `nginx -t`.
-   [x] `curl -i http://127.0.0.1/healthz` through Nginx.
-   [x] GitHub Actions deploy job log proving the SSH-triggered
    deployment.
-   [x] Traffic-test output captured during container rotation.
-   [x] Recorded test metrics and any limitations observed.

## Current status and next steps

-   [x] FastAPI application and `/healthz` endpoint created.
-   [x] Multi-stage Dockerfile created.
-   [x] Test/lint and Docker image publishing workflow run successfully
    according to project progress.
-   [x] Docker and Nginx installed on EC2.
-   [x] Blue/Green container ports and Nginx upstream configured.
-   [x] Manual deployment checks reported successful: Green health
    check, Nginx switch/reload, HTTP 200 through Nginx, and old
    container removal after verification.
-   [x] Confirm the current `deploy.yml` includes and successfully runs
    the EC2 SSH deployment job.
-   [x] Resolve public EC2 IP access so the application is reachable
    externally.
-   [x] Run and record the continuous traffic test during an actual
    deployment.
-   [x] Replace pending metric values with measured evidence.
-   [x] Verify the final repository paths and keep the documentation
    aligned with the checked-in code.

## What this project demonstrates

This project provides practical experience with CI automation, Docker
image creation and publishing, AWS EC2 administration, Nginx reverse
proxying, health checks, and Blue/Green deployment concepts. The
strongest hiring-manager evidence will be a reproducible repository, a
successful end-to-end GitHub Actions deployment log, and measured
traffic-test results---not just architecture diagrams or a claim of zero
downtime.

------------------------------------------------------------------------

**Maintainer:** Mukul Ranjan\
**Docker Hub:** https://hub.docker.com/r/mukul3990/zero-downtime-api\
**Project:** Multi-Stage Docker & Zero-Downtime GitHub Actions Pipeline
