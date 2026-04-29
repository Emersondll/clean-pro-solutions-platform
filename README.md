# Clean Pro Solutions - Platform Orchestrator 🚀

Este repositório é o **ponto central** do ecossistema Clean Pro Solutions. Ele contém toda a configuração necessária para subir a malha de microserviços, infraestrutura e realizar testes de integração ponta-a-ponta.

## 🏗️ Arquitetura do Sistema
O sistema é composto por 10 microserviços independentes, orquestrados via **Docker Compose** e registrados através do **Netflix Eureka**.

### Componentes de Infraestrutura:
- **MongoDB**: Persistência de dados para todos os serviços.
- **RabbitMQ**: Mensageria assíncrona para comunicação entre serviços.
- **Service Registry (Eureka)**: Descoberta de serviços e balanceamento de carga.

## 🛠️ Como Iniciar o Ambiente

### Pré-requisitos
- Docker & Docker Compose
- Terminal com suporte a PowerShell (para scripts de automação)

### Subindo tudo de uma vez
Para compilar e subir todos os serviços, infraestrutura e rede, execute:
```bash
docker-compose up -d --build
```

Acompanhe o status do registro de serviços em: [http://localhost:8761](http://localhost:8761)

## 🧪 Testes Integrados
Após subir os containers, você pode validar o fluxo completo de negócio (Agendamento -> Contrato -> Pagamento -> Avaliação) rodando:
```powershell
.\test-integrated.ps1
```

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
© 2026 Clean Pro Solutions - Desenvolvido por Emerson.
