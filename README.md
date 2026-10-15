# BB Project Fetcher

Инструмент для массового клонирования и обновления всех репозиториев из проектов в корпоративном BitBucket.

## Возможности

- Клонирование всех репозиториев из указанных проектов Bitbucket
- Пропуск уже существующих репозиториев (идемпотентность)
- Обновление всех репозиториев через `git fetch`
- Логирование всех операций с временными метками
- Валидация конфигурации
- Поддержка нескольких проектов в одном запуске
- Использование SSH для клонирования (через существующий SSH-ключ)

## Структура проекта

```
.
├── cmd/                    # Скрипты
│   ├── clone_all.sh       # Клонирование репозиториев
│   ├── fetch_all.sh       # Обновление репозиториев
│   └── run_all.sh         # Скрипт-оболочка (клонирование + обновление)
├── cfg/                    # Конфигурационные файлы
│   └── config.json
├── repos/                  # Директория для клонированных репозиториев
│   ├── PROJ1/
│   │   ├── service-a/
│   │   └── service-b/
│   └── PROJ2/
│       ├── service-c/
│       └── service-d/
└── logs/                   # Директория для логов
```

## Требования

- **Git** - для операций клонирования и fetch
- **jq** - для парсинга JSON конфигурации
- **curl** - для запросов к Bitbucket API
- **SSH-ключ** - настроенный для доступа к Bitbucket

### Установка зависимостей

**macOS:**
```bash
brew install jq curl
```

**Ubuntu/Debian:**
```bash
sudo apt-get install jq curl git
```

**CentOS/RHEL:**
```bash
sudo yum install jq curl git
```

## Настройка

### 1. Создание Personal Access Token

1. Зайди в свой профиль Bitbucket (аватарка справа сверху)
2. Выбери **Manage account** → **Personal access tokens**
3. Нажми **Create token**
4. Дай токену имя (например, `repo-fetcher`)
5. Выбери права **Read** для Projects/Repositories
6. Скопируй сгенерированный токен (он покажется только один раз)

### 2. Создание конфигурационного файла

Создай файл конфигурации, например `cfg/config.json`:

```json
{
  "bitbucket": {
    "url": "https://your-bitbucket-domain.com",
    "username": "your_username",
    "token": "your_personal_access_token",
    "dest_dir": "repos",
    "log_dir": "logs"
  },
  "projects": [
    {
      "key": "PROJ1",
      "name": "Первый проект"
    },
    {
      "key": "PROJ2",
      "name": "Второй проект"
    }
  ]
}
```

**Описание полей:**

| Поле | Описание | Обязательное |
|------|----------|--------------|
| `bitbucket.url` | URL твоего Bitbucket Server/Data Center | Да |
| `bitbucket.username` | Твой логин в Bitbucket | Да |
| `bitbucket.token` | Personal Access Token | Да |
| `bitbucket.dest_dir` | Директория для клонирования репозиториев (относительно корня проекта) | Да |
| `bitbucket.log_dir` | Директория для логов (относительно корня проекта) | Да |
| `projects[].key` | Ключ проекта в Bitbucket | Да |
| `projects[].name` | Название проекта (для отображения в логах) | Да |

### 3. Настройка SSH-ключа

Убедись, что твой SSH-ключ добавлен в Bitbucket:

```bash
# Проверка существующего ключа
ls -la ~/.ssh/id_rsa.pub

# Если ключа нет, создай новый
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Добавь публичный ключ в Bitbucket:
# Профиль → SSH keys → Add key
```

Проверь подключение:
```bash
ssh -T git@your-bitbucket-domain.com
```

## Использование

Все скрипты запускаются из корня проекта.

### Полный цикл (клонирование + обновление)

```bash
./cmd/run_all.sh cfg/config.json
```

Этот скрипт:

1. Клонирует все новые репозитории из указанных проектов
2. Пропускает уже существующие репозитории
3. Выполняет `git fetch --all` для всех репозиториев

### Только клонирование

```bash
./cmd/clone_all.sh cfg/config.json
```

Клонирует все репозитории из указанных проектов. Существующие репозитории пропускаются.

### Только обновление

```bash
./cmd/fetch_all.sh cfg/config.json
```

Выполняет `git fetch --all` для всех репозиториев в директории `repos/`.

### Просмотр справки

Запусти любой скрипт без аргументов:

```bash
./cmd/run_all.sh
```

## Логи

Все операции логируются в файлы с временными метками:

- **Клонирование:** `logs/clone-YYYYMMDD-HHMMSS.log`
- **Обновление:** `logs/fetch-YYYYMMDD-HHMMSS.log`

Пример имени лога: `clone-20261014-134256.log`

Логи содержат:

- Информацию о начале и завершении операций
- Список обрабатываемых проектов
- Статус клонирования/обновления каждого репозитория
- Вывод команд `git clone` и `git fetch`

## Примеры

### Пример 1: Первый запуск

```bash
# Создаем конфиг
cat > cfg/config.json << EOF
{
  "bitbucket": {
    "url": "https://bitbucket.example.com",
    "username": "ivanov",
    "token": "abc123xyz",
    "dest_dir": "repos",
    "log_dir": "logs"
  },
  "projects": [
    {
      "key": "BACKEND",
      "name": "Backend Services"
    }
  ]
}
EOF

# Запускаем полный цикл
./cmd/run_all.sh cfg/config.json
```

### Пример 2: Ежедневное обновление

Добавь в crontab для ежедневного обновления в 8:00:

```bash
crontab -e

# Добавь строку:
0 8 * * * cd /path/to/bitbucket-fetcher && ./cmd/fetch_all.sh cfg/config.json
```

### Пример 3: Несколько конфигов для разных окружений

```bash
# Конфиг для разработки
./cmd/run_all.sh cfg/dev-config.json

# Конфиг для продакшена
./cmd/run_all.sh cfg/prod-config.json
```

## Устранение неполадок

### Ошибка: "Конфигурационный файл не найден"

Убедись, что запускаешь скрипт из корня проекта и путь к конфигу указан правильно:

```bash
# Правильно:
./cmd/run_all.sh cfg/config.json

# Неправильно (если ты в cmd/):
./run_all.sh ../cfg/config.json
```

### Ошибка: "bitbucket.token не указан в конфиге"

Проверь, что все обязательные поля заполнены в JSON:

```bash
# Валидация JSON
jq . cfg/config.json
```

### Ошибка при клонировании: "Permission denied (publickey)"

1. Проверь, что SSH-ключ добавлен в Bitbucket
2. Проверь подключение: `ssh -T git@your-bitbucket-domain.com`
3. Убедись, что используется правильный SSH-ключ: `ssh-add -l`

### Ошибка: "jq: command not found"

Установи jq:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

## Безопасность

- **Не коммитьте токены в репозиторий!** Добавьте `cfg/*.json` в `.gitignore`
- Используйте `git-crypt` или `SOPS` для шифрования конфигов с секретами
- Регулярно ротируйте Personal Access Tokens
- Ограничьте права токена только до **Read**

## Лицензия

MIT
