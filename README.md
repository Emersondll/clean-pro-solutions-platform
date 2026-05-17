# Clean Pro Solutions — Platform Orchestrator

Central repository for the Clean Pro Solutions microservices platform. Contains Docker Compose orchestration, infrastructure configuration, and end-to-end integration tests.

---

## Architecture Overview

The platform consists of **12 microservices** communicating via **Netflix Eureka** (service discovery) and **RabbitMQ** (async event bus), with **MongoDB** as the persistence layer per service (database-per-service pattern).

```
                          ┌─────────────────────────────────┐
                          │         BFF / API Gateway        │
                          │         (port 8080)              │
                          └───────────────┬─────────────────┘
                                          │ (reverse proxy via Eureka)
        ┌─────────────────────────────────┼────────────────────────────────┐
        │                                 │                                │
   ┌────▼────┐  ┌──────────┐  ┌─────────▼──┐  ┌──────────┐  ┌──────────┐│
   │  Auth   │  │  User    │  │  Catalog   │  │Scheduling│  │Avail.    ││
   │  :8081  │  │  :8082   │  │  :8083     │  │  :8084   │  │  :8085   ││
   └────┬────┘  └──────────┘  └────────────┘  └────┬─────┘  └──────────┘│
        │                                           │                     │
   ┌────▼────────────────────────────────────────────▼───────────────────┤
   │                         RabbitMQ (SAGA Event Bus)                   │
   └────┬──────────┬──────────┬──────────┬──────────┬────────────────────┘
        │          │          │          │          │
   ┌────▼────┐ ┌───▼────┐ ┌──▼──────┐ ┌─▼───────┐ ┌▼──────────┐
   │Contract │ │Payment │ │ Rating  │ │Notif.   │ │  Chat     │
   │  :8086  │ │  :8087 │ │  :8088  │ │  :8089  │ │  :8091    │
   └─────────┘ └────────┘ └─────────┘ └─────────┘ └───────────┘
                                                    ┌───────────┐
                                                    │ Support   │
                                                    │  :8092    │
                                                    └───────────┘
```

### Infrastructure

| Component | Image | Port |
|-----------|-------|------|
| MongoDB | mongo:7.0 | 27017 |
| RabbitMQ | rabbitmq:3.13-management-alpine | 5672 / 15672 |
| Service Registry (Eureka) | custom build | 8761 |

### Microservices

| Service | Port | Database | RabbitMQ |
|---------|------|----------|----------|
| auth-service | 8081 | auth_db | Producer |
| user-service | 8082 | user_db | Consumer |
| catalog-service | 8083 | catalog_db | — |
| scheduling-service | 8084 | scheduling_db | Producer |
| availability-service | 8085 | availability_db | Consumer |
| contract-service | 8086 | contract_db | Producer + Consumer |
| payment-service | 8087 | payment_db | Producer + Consumer |
| rating-service | 8088 | rating_db | Consumer |
| notification-service | 8089 | notification_db | Consumer |
| chat-service | 8091 | chat_db | — |
| support-service | 8092 | support_db | — |
| bff-service | 8080 | — | — |

---

## Technology Stack

- **Java 21** + **Spring Boot 3.3.4**
- **Spring Cloud Netflix Eureka** — service registry and discovery
- **Spring Cloud Gateway** — BFF reverse proxy
- **Spring Data MongoDB** — persistence (database per service)
- **Spring AMQP / RabbitMQ** — async SAGA event bus
- **Spring Security + JWT** — stateless authentication
- **SpringDoc / OpenAPI 3** — API documentation
- **Docker + Docker Compose** — containerization and orchestration
- **JUnit 5 + Mockito** — unit testing
- **JaCoCo** — code coverage (minimum 80%)

---

## Quick Start

### Prerequisites

- Docker Desktop (with Compose v2)
- PowerShell 5.1+ (Windows) or `pwsh` (cross-platform)

### Start the full platform

```powershell
docker-compose up -d --build
```

Wait for all services to register in Eureka (approximately 2–3 minutes):

```
http://localhost:8761
```

### Run the full E2E integration test

```powershell
.\test-integrated.ps1
```

The script executes all 30+ steps automatically across all 12 services:
Auth → User → Catalog → Availability → Scheduling → Contract → Payment → Notifications → Chat → Rating → Support

### Interactive HTTP tests

Open `clean-pro-e2e-test.http` in VS Code (REST Client extension) or IntelliJ IDEA for step-by-step execution with captured variables.

### Individual service development

Each service has its own Dockerfile and can be built in isolation:

```powershell
cd clean-pro-solutions-auth-service
mvn clean verify         # build + tests + coverage check
docker build -t auth-service .
```

---

## SAGA Pattern — Contract Lifecycle

The core business flow uses an event-driven SAGA coordinated via RabbitMQ:

```
Client          Scheduling      Contract        Payment         Notification
  │                │               │               │                │
  │──createSchedule▶│               │               │                │
  │                │──ScheduleCreatedEvent──────────────────────────▶│
  │                │               │               │                │
  │──createContract────────────────▶│               │                │
  │                │               │──ContractCreatedEvent──────────▶│
  │                │               │───────────────▶│                │
  │                │               │          (creates payment)      │
  │                │               │               │                │
  │──simulateWebhook───────────────────────────────▶│                │
  │                │               │               │──PaymentApprovedEvent
  │                │               │◀──────────────│                │
  │                │         (CONFIRMED)            │──────────────▶│
  │                │               │               │         (notifies both)
```

### Event reference

| Event | Producer | Consumers |
|-------|----------|-----------|
| `ScheduleCreatedEvent` | scheduling-service | availability-service, notification-service |
| `ContractCreatedEvent` | contract-service | payment-service, notification-service |
| `PaymentApprovedEvent` | payment-service | contract-service, notification-service |
| `PaymentRejectedEvent` | payment-service | contract-service, notification-service |

---

## API Reference

### Auth Service — `:8081`

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/register` | Register a new user |
| POST | `/auth/login` | Authenticate and get JWT |
| POST | `/auth/refresh` | Refresh access token |
| GET | `/auth/validate` | Validate JWT token |

### User Service — `:8082`

| Method | Path | Description |
|--------|------|-------------|
| POST | `/users` | Create user profile |
| GET | `/users/{id}` | Get user by ID |
| GET | `/users/email/{email}` | Get user by email |
| PUT | `/users/{id}` | Update user |
| DELETE | `/users/{id}` | Delete user |
| PUT | `/users/{id}/contractor-profile` | Update contractor profile |
| POST | `/users/{id}/device-tokens` | Register push token |
| GET | `/users/nearby` | Find nearby contractors (geospatial) |

### Catalog Service — `:8083`

| Method | Path | Description |
|--------|------|-------------|
| POST | `/services` | Create service offering |
| GET | `/services` | List all services |
| GET | `/services/active` | List active services |
| GET | `/services/{id}` | Get by ID |
| GET | `/services/type/{type}` | Filter by type |
| GET | `/services/search` | Full-text search |
| PUT | `/services/{id}` | Update service |
| DELETE | `/services/{id}` | Delete service |

### Scheduling Service — `:8084`

| Method | Path | Description |
|--------|------|-------------|
| POST | `/schedulings` | Create scheduling |
| GET | `/schedulings/{id}` | Get by ID |
| GET | `/schedulings/client/{clientId}` | List by client |
| GET | `/schedulings/contractor/{contractorId}` | List by contractor |
| PUT | `/schedulings/{id}` | Update scheduling |
| POST | `/schedulings/recurring` | Create recurring schedulings |
| PATCH | `/schedulings/{id}/cancel` | Cancel |
| PATCH | `/schedulings/{id}/complete` | Complete |

### Availability Service — `:8085`

| Method | Path | Description |
|--------|------|-------------|
| GET | `/availability/contractor/{contractorId}` | Get contractor slots |
| GET | `/availability/check` | Check availability for time range |

### Contract Service — `:8086`

| Method | Path | Description |
|--------|------|-------------|
| POST | `/contracts` | Create contract |
| GET | `/contracts/{id}` | Get by ID |
| GET | `/contracts/client/{clientId}` | List by client |
| GET | `/contracts/contractor/{contractorId}` | List by contractor |

### Payment Service — `:8087`

| Method | Path | Description |
|--------|------|-------------|
| GET | `/payments/contract/{contractId}` | Get payment for contract |
| POST | `/payments/webhook` | Simulate gateway webhook |

### Rating Service — `:8088`

| Method | Path | Description |
|--------|------|-------------|
| POST | `/ratings` | Submit a rating |
| GET | `/ratings/reviewed/{reviewedId}` | Get ratings by reviewed user |
| GET | `/ratings/reviewed/{reviewedId}/average` | Get average score |

### Notification Service — `:8089`

| Method | Path | Description |
|--------|------|-------------|
| GET | `/notifications/recipient/{recipientId}` | Get notifications for user |

### Chat Service — `:8091`

| Method | Path | Description |
|--------|------|-------------|
| POST | `/chat/rooms` | Get or create chat room |
| GET | `/chat/{roomId}/stream` | SSE stream (real-time messages) |
| POST | `/chat/{roomId}/messages` | Send message |
| GET | `/chat/{roomId}/messages` | Get message history |

### Support Service — `:8092`

| Method | Path | Description |
|--------|------|-------------|
| POST | `/tickets` | Open support ticket |
| GET | `/tickets/{id}` | Get ticket by ID |
| GET | `/tickets/requester/{requesterId}` | List by requester |
| GET | `/tickets/contract/{contractId}` | List by contract |
| GET | `/tickets` | Filter by status or type |
| PATCH | `/tickets/{id}/assign` | Assign to agent |
| PATCH | `/tickets/{id}/resolve` | Resolve with description |
| PATCH | `/tickets/{id}/close` | Close ticket |

### BFF / API Gateway — `:8080`

All services are accessible via the BFF using the same paths prefixed by the service name.
OpenAPI docs: `http://localhost:8080/swagger-ui.html`

---

## Project Structure

```
Projeto Clean Pro/
├── docker-compose.yml                         # Full platform orchestration
├── clean-pro-e2e-test.http                    # Interactive E2E tests (REST Client)
├── test-integrated.ps1                        # Automated E2E PowerShell script
├── CLAUDE.md                                  # AI agent refactoring guidelines
├── SYSTEM_ARCHITECTURE_AND_AI_SPEC.md         # Architecture specification
├── clean-pro-solutions-service-registry/      # Eureka server (:8761)
├── clean-pro-solutions-auth-service/          # JWT auth (:8081)
├── clean-pro-solutions-user-service/          # User profiles (:8082)
├── clean-pro-solutions-catalog/               # Service catalog (:8083)
├── clean-pro-solutions-scheduling-service/    # Scheduling (:8084)
├── clean-pro-solutions-availability-service/  # Availability (:8085)
├── clean-pro-solutions-contract-service/      # Contracts (:8086)
├── clean-pro-solutions-payment-service/       # Payments (:8087)
├── clean-pro-solutions-rating-service/        # Ratings (:8088)
├── clean-pro-solutions-notification-service/  # Push/in-app notifications (:8089)
├── clean-pro-solutions-chat-service/          # Real-time chat SSE (:8091)
├── clean-pro-solutions-support-service/       # Support tickets (:8092)
└── clean-pro-solutions-bff/                  # API Gateway (:8080)
```

---

## Useful URLs

| Resource | URL |
|----------|-----|
| Eureka Dashboard | http://localhost:8761 |
| RabbitMQ Management | http://localhost:15672 (guest/guest) |
| BFF Swagger UI | http://localhost:8080/swagger-ui.html |
| Auth Swagger UI | http://localhost:8081/swagger-ui.html |

---

## Related Repositories

Each service has its own repository and independent lifecycle:

- [auth-service](https://github.com/emersondll/clean-pro-solutions-auth-service)
- [user-service](https://github.com/emersondll/clean-pro-solutions-user-service)
- [catalog-service](https://github.com/emersondll/clean-pro-solutions-catalog)
- [scheduling-service](https://github.com/emersondll/clean-pro-solutions-scheduling-service)
- [availability-service](https://github.com/emersondll/clean-pro-solutions-availability-service)
- [contract-service](https://github.com/emersondll/clean-pro-solutions-contract-service)
- [payment-service](https://github.com/emersondll/clean-pro-solutions-payment-service)
- [rating-service](https://github.com/emersondll/clean-pro-solutions-rating-service)
- [notification-service](https://github.com/emersondll/clean-pro-solutions-notification-service)
- [chat-service](https://github.com/emersondll/clean-pro-solutions-chat-service)
- [support-service](https://github.com/emersondll/clean-pro-solutions-support-service)
- [bff-service](https://github.com/emersondll/clean-pro-solutions-bff)
- [service-registry](https://github.com/emersondll/clean-pro-solutions-service-registry)

---

© 2026 Clean Pro Solutions — Developed by Emerson Lima
