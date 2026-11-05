# DO7_Docker_Compose — контейнеризация микросервисов и оркестрация с Docker Swarm

<p align="center">
  <img src="https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white" />
  <img src="https://img.shields.io/badge/Docker%20Compose-2496ED?logo=docker&logoColor=white" />
  <img src="https://img.shields.io/badge/Docker%20Swarm-2496ED?logo=docker&logoColor=white" />
  <img src="https://img.shields.io/badge/Vagrant-1868F2?logo=vagrant&logoColor=white" />
  <img src="https://img.shields.io/badge/Java-ED8B00?logo=openjdk&logoColor=white" />
  <img src="https://img.shields.io/badge/Maven-C71A36?logo=apachemaven&logoColor=white" />
  <img src="https://img.shields.io/badge/Nginx-009639?logo=nginx&logoColor=white" />
  <img src="https://img.shields.io/badge/Portainer-13BEF9?logo=portainer&logoColor=white" />
</p>

> **Полезные материалы**
>
> - [Полное задание School 21](README_RUS.md) — исходные требования и описание всех частей проекта.
> - [Подробный отчёт о выполнении](src/REPORT.MD) — ход работы, конфигурации и скриншоты результатов.

## О проекте

**DO7_Docker_Compose** — учебный проект School 21, посвящённый контейнеризации микросервисного приложения и его развёртыванию в распределённом Docker Swarm-кластере.

Работа построена как последовательное усложнение инфраструктуры: сначала приложение запускается локально с помощью Docker Compose, затем переносится в виртуальную машину, после чего разворачивается на трёх узлах Docker Swarm.

Приложение состоит из Java-сервисов, PostgreSQL и RabbitMQ. Для сборки Java-приложений используются multi-stage Dockerfile на базе Maven и Eclipse Temurin. В Swarm-кластере взаимодействие сервисов организовано через overlay network, а внешний доступ к `session-service` и `gateway-service` предоставляется через Nginx reverse proxy. Для визуального контроля кластера развёрнут Portainer.

Данный проект демонстрирует мои практические навыки контейнеризации, сетевого взаимодействия контейнеров, подготовки инфраструктуры и оркестрации сервисов. Он не позиционируется как отказоустойчивая production-платформа.

## Кратко о технологиях

| Область | Инструменты |
|---|---|
| Контейнеризация | Docker |
| Локальная оркестрация | Docker Compose |
| Кластерная оркестрация | Docker Swarm |
| Виртуализация и подготовка VM | Vagrant, VirtualBox |
| Операционная система узлов | Ubuntu Server 24.04 LTS |
| Backend-сервисы | Java, Spring Boot |
| Сборка Java-приложений | Maven |
| База данных | PostgreSQL |
| Очереди сообщений | RabbitMQ |
| Reverse proxy | Nginx |
| Управление Swarm | Portainer |
| Проверка API | Postman |

## Архитектура

### Этап 1. Локальный запуск через Docker Compose

На первом этапе все компоненты запускаются на одной машине в общей bridge-сети Docker Compose.

В состав приложения входят:

- `session-service` — сервис сессий
- `hotel-service` — сервис отелей
- `booking-service` — сервис бронирования
- `payment-service` — сервис платежей
- `loyalty-service` — сервис программы лояльности
- `report-service` — сервис отчётов
- `gateway-service` — API Gateway
- `postgres` — база данных PostgreSQL
- `rabbitmq` — брокер сообщений
- `nginx` — внешний прокси в Swarm-конфигурации

В локальной конфигурации для доступа с хоста публикуются порты `8081` сервиса сессий и `8087` Gateway. Остальные backend-сервисы доступны внутри сети Compose.

### Этап 2. Docker Swarm из трёх узлов

Для кластерного развёртывания создаются три виртуальные машины:

| Узел | IP-адрес | Роль |
|---|---|---|
| `manager01` | `192.168.56.10` | Swarm manager |
| `worker01` | `192.168.56.11` | Swarm worker |
| `worker02` | `192.168.56.12` | Swarm worker |

### Сетевое взаимодействие

В Swarm-конфигурации используется сеть `services_network` с драйвером `overlay`. Она позволяет сервисам, размещённым на разных узлах кластера, взаимодействовать друг с другом по DNS-именам сервисов.

Внешний Nginx подключён к той же overlay-сети и проксирует запросы:

- порт `8081` → `session-service:8081`
- порт `8087` → `gateway-service:8087`

Порты самих `session-service` и `gateway-service` в Swarm-файле не публикуются на хост. Таким образом, внешняя точка входа проходит через Nginx, а backend-сервисы остаются доступны через внутреннюю сеть кластера.

## Что было реализовано

### 1. Контейнеризация Java-микросервисов

Для каждого микросервиса подготовлен отдельный Dockerfile:

- `session-service`
- `hotel-service`
- `booking-service`
- `payment-service`
- `loyalty-service`
- `report-service`
- `gateway-service`

Для сборки используется Maven и Java 8 (Eclipse Temurin).

Dockerfile построены по multi-stage подходу.

**Этап сборки:**

- используется образ `maven:3.9-eclipse-temurin-8`
- копируется `pom.xml`
- Maven заранее загружает зависимости командой `mvn dependency:go-offline`
- копируется исходный код
- собирается JAR-файл командой `mvn package -DskipTests -B`

**Этап запуска:**

- используется runtime-образ Eclipse Temurin JRE на базе Ubuntu Jammy
- в образ копируется только собранный JAR
- создаётся системный пользователь `appuser` и группа `appgroup`
- приложение запускается от непривилегированного пользователя
- для сервисов, зависящих от PostgreSQL и RabbitMQ, используется `wait-for-it.sh`

В отчёте приведено сравнение размера обычной и multi-stage сборки: итоговый образ в рассмотренном примере получился почти в 2,5 раза меньше.

Это показывает практическую пользу разделения build- и runtime-окружений: Maven и инструменты сборки не нужны для запуска готового Java-приложения.

### 2. Локальный запуск приложения через Docker Compose

На первом этапе создан `docker-compose_task1.yml`, который описывает запуск приложения на одной машине.

В конфигурации определены:

- PostgreSQL с инициализацией базы через `init.sql`
- RabbitMQ
- семь Java-микросервисов
- общая bridge-сеть `services_network`
- именованные volumes для данных PostgreSQL и RabbitMQ
- healthcheck для PostgreSQL и RabbitMQ
- зависимости сервисов от готовности инфраструктурных компонентов через `depends_on` с `condition: service_healthy`

Для проверки локального запуска опубликованы порты сервисов `session-service` и `gateway-service`. После сборки и запуска приложения были выполнены подготовленные Postman-тесты. В отчёте указано, что все тесты прошли успешно.

### 3. Подготовка виртуальных машин с помощью Vagrant

Для воспроизводимого создания инфраструктуры написан `Vagrantfile`.

На первом шаге создавалась одна VM Ubuntu Server 24.04 LTS с передачей исходного кода приложения в виртуальную машину.

Затем конфигурация была расширена до трёх узлов:

- `manager01`;
- `worker01`;
- `worker02`.

Для VM заданы статические адреса приватной сети и параметры CPU/RAM. Установка Docker автоматизирована скриптом `install_docker.sh`, который подключает официальный репозиторий Docker и устанавливает Docker Engine, CLI, containerd, Buildx и Compose plugin.

Использование Vagrant позволяет пересоздавать лабораторную инфраструктуру командами, а не настраивать каждую виртуальную машину вручную.

### 4. Инициализация Docker Swarm

На `manager01` выполняется инициализация Swarm:

```bash
docker swarm init --advertise-addr 192.168.56.10
```

После инициализации manager получает join-токен для worker-узлов. Скрипт `manager.sh` сохраняет его в файл, а `worker.sh` ожидает появления файла и выполняет подключение worker к manager.

Таким образом, создание кластера автоматизировано shell-скриптами, запускаемыми при provisioning Vagrant.

### 5. Публикация образов и развёртывание Stack

Для кластерного развёртывания Compose-файл был адаптирован: вместо локальной сборки сервисы используют готовые образы из Docker Hub, например `shanteve/booking-service:1.0`.

На manager размещаются Compose-файл, конфигурация Nginx, SQL-инициализация и файл переменных окружения. Затем приложение разворачивается как Docker Stack.

В конфигурации Swarm:

- PostgreSQL и RabbitMQ имеют по одной реплике;
- для PostgreSQL и RabbitMQ задано ограничение размещения `node.role == manager`;
- backend-сервисы подключены к overlay-сети;
- Nginx также размещается на manager и публикует порты `8081` и `8087`.

Это демонстрирует использование Swarm scheduling constraints и отличие кластерного развёртывания от локального Docker Compose.

### 6. Настройка Nginx reverse proxy

В кластер добавлен отдельный сервис Nginx. Его конфигурация монтируется в контейнер только для чтения:

```yaml
volumes:
  - ./nginx.conf:/etc/nginx/nginx.conf:ro
```

Для разрешения DNS-имён контейнеров используется встроенный DNS Docker:

```nginx
resolver 127.0.0.11 valid=10s ipv6=off;
```

Nginx принимает запросы на портах `8081` и `8087` и передаёт их соответствующим backend-сервисам по overlay-сети.

Публикуются только порты Nginx. Прямой доступ к `session-service` и `gateway-service` через опубликованные порты не предоставляется.

### 7. Проверка приложения через Postman

После развёртывания стека в Swarm были повторно запущены подготовленные Postman-тесты.

Для тестирования с локальной машины значение `API_HOST` было изменено с `localhost` на IP-адрес manager-узла `192.168.56.10`.

В отчёте зафиксирован успешный результат выполнения тестов после переноса приложения в кластер.

### 8. Проверка распределения задач по узлам

Для проверки состояния кластера использовались команды Docker, позволяющие получить список узлов и размещение задач сервисов.

Это позволяет увидеть, на каких узлах Swarm запущены контейнеры, и проверить, что workload распределяется между manager и worker-узлами в соответствии с настройками и ограничениями размещения.

### 9. Визуализация кластера с помощью Portainer

Для визуального управления кластером был развёрнут отдельный Docker Stack с Portainer CE и Portainer Agent.

В конфигурации:

- Portainer Agent запускается в режиме `global` — по одной задаче на каждом подходящем узле
- Agent получает доступ к Docker socket и каталогу Docker volumes
- Portainer Server запускается одной репликой на manager
- Portainer Server подключается к агентам через `tasks.agent:9001`
- данные Portainer сохраняются в отдельном volume `portainer_data`

Через веб-интерфейс Portainer была проверена визуализация распределения задач по узлам кластера.

## Ключевые технические решения

| Решение | Зачем оно используется |
|---|---|
| Отдельный контейнер для каждого микросервиса | Разделить жизненный цикл и окружение компонентов приложения. |
| Multi-stage Dockerfile | Не включать Maven и build-инструменты в runtime-образ. |
| Непривилегированный `appuser` | Снизить привилегии Java-процессов внутри контейнеров. |
| Docker Compose на первом этапе | Проверить взаимодействие сервисов на одной машине до перехода к кластеру. |
| Vagrant provisioning | Воспроизводимо создавать виртуальные машины и настраивать Docker. |
| Docker Swarm | Разворачивать сервисы на нескольких узлах и управлять их задачами. |
| Overlay network | Обеспечить сетевое взаимодействие контейнеров на разных узлах. |
| Placement constraints | Размещать stateful-компоненты и Nginx на manager-узле согласно заданной конфигурации. |
| Nginx reverse proxy | Предоставить единую внешнюю точку входа для session и gateway сервисов. |
| Portainer Agent в режиме global | Получать данные о Docker-окружении на каждом узле. |

## Запуск проекта

### Требования

- Vagrant
- VirtualBox с поддержкой архитектуры хоста
- Docker Engine и Docker CLI
- доступ к Docker Hub для загрузки образов
- Postman для запуска предоставленной коллекции тестов

В проекте используется box `bento/ubuntu-24.04`. В исходной лабораторной среде он был выбран с учётом ARM64-хоста MacBook на Apple M1.

### Локальный запуск через Docker Compose

Перейдите в каталог `src`:

```bash
cd src
```

Подготовьте файл окружения на основе шаблона:

```bash
cp .env.example .env
```

Заполните параметры подключения к PostgreSQL, RabbitMQ и внутренним сервисам. Не используйте учебные пароли в публичном или production-окружении.

Соберите и запустите приложение:

```bash
docker compose -f docker-compose_task1.yml build
docker compose -f docker-compose_task1.yml up -d
```

Проверьте состояние контейнеров:

```bash
docker compose -f docker-compose_task1.yml ps
```

Остановите приложение:

```bash
docker compose -f docker-compose_task1.yml down
```

### Создание Swarm-кластера

Из каталога `src`:

```bash
vagrant up
```

Проверьте созданные виртуальные машины:

```bash
vagrant status
```

Подключитесь к manager:

```bash
vagrant ssh manager01
```

Проверить состояние кластера можно командами:

```bash
docker node ls
docker service ls
docker stack ls
docker stack services <stack_name>
docker stack ps <stack_name>
```

Для запуска Stack на manager используется подготовленный `docker-compose.yml`:

```bash
docker stack deploy -c docker-compose.yml <stack_name>
```

Имя Stack и значения переменных окружения должны соответствовать вашей конфигурации. Перед запуском убедитесь, что образы доступны в Docker Hub, а `.env` и необходимые файлы находятся на manager.

### Portainer

Portainer разворачивается отдельным Stack из `portainer.yml`:

```bash
docker stack deploy -c portainer.yml portainer
```

В текущей конфигурации веб-интерфейс Portainer публикуется на портах `9443`, `9000` и `8000`. Для доступа используйте адрес manager-узла и соответствующий порт.

> Команды выше описывают общий порядок запуска по конфигурации проекта. Для полного повторения лабораторной работы следуйте последовательности и подготовке файлов из [подробного отчёта](src/REPORT.MD).

## Структура репозитория

```text
DO7_Docker_Compose/
├── README.md
├── README_RUS.md
├── misc/
│   └── images/
│       └── project_diagram.png
└── src/
    ├── Vagrantfile
    ├── Vagrantfile_task2
    ├── install_docker.sh
    ├── manager.sh
    ├── worker.sh
    ├── docker-compose_task1.yml
    ├── docker-compose.yml
    ├── nginx.conf
    ├── portainer.yml
    ├── .env.example
    ├── services/
    │   ├── database/
    │   │   └── init.sql
    │   ├── session-service/
    │   ├── hotel-service/
    │   ├── booking-service/
    │   ├── payment-service/
    │   ├── loyalty-service/
    │   ├── report-service/
    │   └── gateway-service/
    ├── application_tests.postman_collection.json
    └── REPORT.MD
```

## Проверка результата

В отчёте приведены материалы, подтверждающие выполнение основных этапов:

- Dockerfile и сравнение размеров обычной и multi-stage сборки
- запуск микросервисного приложения через Docker Compose
- успешное прохождение Postman-тестов на локальном этапе
- создание и удаление виртуальной машины Vagrant
- запуск трёх VM и подключение узлов к Docker Swarm
- развёртывание Stack на manager
- настройка Nginx reverse proxy
- успешное прохождение Postman-тестов после развёртывания в Swarm
- список узлов и распределение задач по ним
- визуализация распределения задач в Portainer

Подробные скриншоты и ход выполнения находятся в [src/REPORT.MD](src/REPORT.MD).

## Что я изучил

- Как контейнеризировать набор Java-микросервисов
- Как использовать multi-stage Dockerfile для уменьшения runtime-образов
- Как запускать несколько взаимосвязанных сервисов с Docker Compose
- Как использовать healthcheck и `depends_on` для управления порядком старта в Compose
- Как создавать виртуальные машины и выполнять provisioning с помощью Vagrant
- Как инициализировать Docker Swarm и подключать worker-узлы
- Как публиковать образы в Docker Hub и использовать их при кластерном развёртывании
- Как работает overlay network и DNS-обнаружение сервисов в Swarm
- Как ограничивать размещение сервисов с помощью placement constraints
- Как организовать внешний доступ через Nginx reverse proxy
- Как проверять API через Postman и наблюдать за состоянием кластера через Portainer

## Границы проекта и дальнейшее развитие

Текущая конфигурация демонстрирует работу микросервисного приложения в Docker Swarm, но не является отказоустойчивой production-архитектурой. При дальнейшем развитии я бы уделил внимание следующим направлениям.

### Безопасность

- Не использовать стандартные учётные данные RabbitMQ в рабочем окружении.
- Ограничить доступ к Docker socket: подключение `/var/run/docker.sock` к Portainer Agent фактически предоставляет агенту широкие полномочия над Docker Engine узла
- Защитить интерфейс Portainer и не публиковать административные порты в недоверенную сеть
- Фиксировать образы по digest и регулярно сканировать их на уязвимости

### Надёжность и эксплуатация

- Добавить healthcheck для Java-микросервисов и настроить политику обновления/отката Swarm-сервисов
- Рассмотреть несколько manager-узлов для отказоустойчивости control plane. Один manager не обеспечивает HA кластера
- Продумать резервное копирование PostgreSQL и RabbitMQ, а также восстановление данных
- Учитывать, что PostgreSQL и RabbitMQ размещаются с одной репликой на manager, а локальные named volumes не обеспечивают автоматическую репликацию данных между узлами
- Добавить централизованные логи, метрики, алертинг и мониторинг состояния сервисов
- Перенести параметры окружения из `.env` в безопасное управление конфигурацией и секретами

### Сборка и доставка

- Добавить CI pipeline для автоматической сборки, тестирования, сканирования и публикации образов
- Использовать immutable image tags или digest вместо изменяемых тегов
- Проверить multi-architecture сборку: runtime-образы в Dockerfile явно используют `arm64v8/eclipse-temurin`, поэтому перенос на x86_64-узлы потребует соответствующих amd64-образов или multi-platform manifest
- Не пропускать тесты при сборке в CI без отдельного тестового этапа: сейчас в Dockerfile используется `mvn package -DskipTests`

Это направления дальнейшего развития, а не функциональность, уже реализованная в проекте.

## Ссылки

- [Полное задание School 21](README_RUS.md)
- [Подробный отчёт с командами и скриншотами](src/REPORT.MD)
- [GitHub-профиль](https://github.com/Shanteve)
