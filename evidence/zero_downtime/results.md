# Zero-Downtime Deployment — Test Report

**Project:** Multi-Stage Docker & Zero-Downtime GitHub Actions Pipeline  
**Test date:** 17/10/2026 9:12AM  
**Application image tag:**  mukul3990/zero-downtime-api:latest

## Environment
- EC2 operating system: host 9.20.18-1ubuntu2.1-Ubuntu
- Container registry: Docker Hub
- Reverse proxy: Nginx
- Blue application port: 8081
- Green application port: 8082

## Results

| Metric | Measured result |
|---|---|
| Total requests | 544 |
| Successful 2xx responses | 544 |
| Failed/non-2xx requests | 0 |
| HTTP 5xx responses | 0 |
| Success rate | 100.00% |
| Deployment duration | 120s |
| Docker image size | 102.38mb |
| GitHub Actions workflow duration | 2m 19s |

## Validation
- [x] Application health checks passed
- [x] Nginx configuration validated
- [x] New container passed its health checks
- [x] Nginx switched to the new backend
- [x] Traffic was tested during deployment
- [x] Results and terminal evidence were saved

## Conclusion
[Describe what the measured results demonstrate. Report any failures honestly and avoid claiming zero downtime unless the test evidence supports that conclusion.]
