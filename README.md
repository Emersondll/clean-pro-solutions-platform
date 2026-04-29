# Clean Pro Solutions - Platform Orchestrator 🚀

Este repositório é o **ponto central** do ecossistema Clean Pro Solutions. Ele contém toda a configuração necessária para subir a malha de microserviços, infraestrutura e realizar testes de integração ponta-a-ponta.

## 🏗️ Arquitetura do Sistema
O sistema é composto por 10 microserviços independentes, orquestrados via **Docker Compose** e registrados através do **Netflix Eureka**.

### Componentes de Infraestrutura:
- **MongoDB**: Persistência de dados para todos os serviços.
- **RabbitMQ**: Mensageria assíncrona para comunicação entre serviços.
- **Service Registry (Eureka)**: Descoberta de serviços e balanceamento de carga.

## 🛠️ Como Iniciar o Ambiente

O projeto foi desenhado para ser totalmente portátil e fácil de subir. Você tem duas opções principais:

### ⚡ Quick Start (Subir e Testar)
Se você quer subir tudo e já validar o funcionamento com um único comando:

```powershell
docker-compose up -d --build; .\test-integrated.ps1
```

Este comando irá:
1. Compilar todos os microserviços.
2. Subir os containers (Banco, Rabbit, Registry e Serviços).
3. Executar o fluxo completo de teste (Agendamento -> Contrato -> Pagamento -> Avaliação).

O script de teste integrado valida o fluxo ponta-a-ponta:
`Agendamento -> Contrato -> Pagamento -> Notificação -> Avaliação`

### 2. Ambientes Isolados
Cada microserviço possui seu próprio `docker-compose.yml` em sua pasta. Para rodar um serviço específico com suas dependências mínimas, navegue até a pasta do serviço e execute:
```bash
docker-compose up -d --build
```

Acompanhe o status do registro de serviços (Eureka) em: [http://localhost:8761](http://localhost:8761)

## 🔗 Repositórios Relacionados
Cada serviço possui seu próprio ciclo de vida e repositório:
- [auth-service](https://github.com/emersondll/clean-pro-solutions-auth-service)
- [user-service](https://github.com/emersondll/clean-pro-solutions-user-service)
- [scheduling-service](https://github.com/emersondll/clean-pro-solutions-scheduling-service)
- [contract-service](https://github.com/emersondll/clean-pro-solutions-contract-service)
- [payment-service](https://github.com/emersondll/clean-pro-solutions-payment-service)
- [rating-service](https://github.com/emersondll/clean-pro-solutions-rating-service)
- [notification-service](https://github.com/emersondll/clean-pro-solutions-notification-service)
- [catalog-service](https://github.com/emersondll/clean-pro-solutions-catalog)
- [availability-service](https://github.com/emersondll/clean-pro-solutions-availability-service)
- [bff-service](https://github.com/emersondll/clean-pro-solutions-bff)
- [service-registry](https://github.com/emersondll/clean-pro-solutions-service-registry)

---
© 2026 Clean Pro Solutions - Desenvolvido por Emerson Lima.
