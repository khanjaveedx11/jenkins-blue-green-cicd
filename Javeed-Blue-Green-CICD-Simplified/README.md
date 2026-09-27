# Simplified Blue-Green CI/CD Project

A beginner-friendly version of the larger `docker-blue-green-runner` idea.

## Tools

- GitHub
- Jenkins
- Docker
- AWS EC2 (Ubuntu)
- Nginx

## Architecture

```text
GitHub
  ↓
Jenkins
  ↓
Docker Build
  ↓
Blue :5001  /  Green :5002
  ↓
Health Check
  ↓
Nginx :80
  ↓
Users
```

## Files

```text
.
├── app.js
├── package.json
├── Dockerfile
├── Jenkinsfile
├── deploy.sh
├── rollback.sh
├── .gitignore
└── README.md
```

## What deploy.sh does

1. Detects the currently active environment from Nginx.
2. Chooses the inactive environment (Blue or Green).
3. Builds the Docker image.
4. Starts the new container on port 5001 or 5002.
5. Checks `/health`.
6. If healthy, switches Nginx traffic to the new container.
7. Keeps the previous container available for rollback.

## What rollback.sh does

Checks the previous environment and switches Nginx back to it if it is healthy.

## EC2 requirements

Install:

```bash
sudo apt update
sudo apt install -y docker.io nginx git curl
sudo systemctl enable --now docker nginx
sudo usermod -aG docker ubuntu
sudo usermod -aG docker jenkins
```

After adding a user to the Docker group, log out/in or restart the relevant service/session.

Jenkins must also be allowed to run the limited Nginx commands used by `deploy.sh` (`test`, `grep`, `mv`, `nginx -t`, and `systemctl reload nginx`). Configure those permissions carefully rather than giving Jenkins unrestricted sudo access.

## Manual first deployment

```bash
chmod +x deploy.sh rollback.sh
./deploy.sh
```

Check:

```bash
docker ps
curl http://localhost/health
```

Deploy again to switch to the other environment:

```bash
./deploy.sh
```

Rollback:

```bash
./rollback.sh
```

## Jenkins flow

```text
Checkout → Docker Build Check → Blue/Green Deploy → Health Check → Nginx Switch
```

The GitHub webhook can be added after the manual deployment works successfully.
