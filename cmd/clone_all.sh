#!/usr/bin/env bash

show_help() {
  cat << EOF
Использование: $0 <путь_к_конфигу>

Скрипт клонирует все репозитории из указанных проектов Bitbucket.
Репозитории группируются по подкаталогам проектов в директории dest_dir.

Параметры:
  <путь_к_конфигу>    Путь к JSON конфигу (обязательный)

Пример:
  $0 cfg/bitbucket-config.json

EOF
  exit 1
}

# Проверка наличия аргумента
if [ $# -eq 0 ]; then
  show_help
fi

CONFIG_FILE="$1"

# Определяем корень проекта (родитель от cmd/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Преобразуем путь к конфигу в абсолютный
if [[ "$CONFIG_FILE" != /* ]]; then
  CONFIG_FILE="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Ошибка: Конфигурационный файл $CONFIG_FILE не найден!"
  exit 1
fi

# Валидация JSON
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
  echo "Ошибка: Невалидный JSON в $CONFIG_FILE"
  exit 1
fi

# Читаем и валидируем настройки
BITBUCKET_URL=$(jq -r '.bitbucket.url // empty' "$CONFIG_FILE")
USERNAME=$(jq -r '.bitbucket.username // empty' "$CONFIG_FILE")
TOKEN=$(jq -r '.bitbucket.token // empty' "$CONFIG_FILE")
DEST_DIR=$(jq -r '.bitbucket.dest_dir // empty' "$CONFIG_FILE")
LOG_DIR=$(jq -r '.bitbucket.log_dir // empty' "$CONFIG_FILE")

# Валидация обязательных полей
if [ -z "$BITBUCKET_URL" ]; then
  echo "Ошибка: bitbucket.url не указан в конфиге"
  exit 1
fi
if [ -z "$USERNAME" ]; then
  echo "Ошибка: bitbucket.username не указан в конфиге"
  exit 1
fi
if [ -z "$TOKEN" ]; then
  echo "Ошибка: bitbucket.token не указан в конфиге"
  exit 1
fi
if [ -z "$DEST_DIR" ]; then
  echo "Ошибка: bitbucket.dest_dir не указан в конфиге"
  exit 1
fi
if [ -z "$LOG_DIR" ]; then
  echo "Ошибка: bitbucket.log_dir не указан в конфиге"
  exit 1
fi

# Создаем директории
mkdir -p "$PROJECT_ROOT/$DEST_DIR"
mkdir -p "$PROJECT_ROOT/$LOG_DIR"

# Формируем имя лог-файла
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$PROJECT_ROOT/$LOG_DIR/clone-$TIMESTAMP.log"

cd "$PROJECT_ROOT/$DEST_DIR" || exit

# Получаем количество проектов
PROJECT_COUNT=$(jq '.projects | length' "$CONFIG_FILE")

{
  echo "=============================================="
  echo "Начало клонирования: $(date)"
  echo "Найдено $PROJECT_COUNT проектов в конфигурации"
  echo "=============================================="

  # Проходим по каждому проекту
  for i in $(seq 0 $((PROJECT_COUNT - 1))); do
    PROJECT_KEY=$(jq -r ".projects[$i].key" "$CONFIG_FILE")
    PROJECT_NAME=$(jq -r ".projects[$i].name" "$CONFIG_FILE")
    
    echo ""
    echo "Обработка проекта: $PROJECT_NAME ($PROJECT_KEY)"
    echo "----------------------------------------------"
    
    # Создаем подкаталог для проекта
    mkdir -p "$PROJECT_KEY"
    cd "$PROJECT_KEY" || continue

    START=0
    LIMIT=100
    TOTAL_REPOS=0

    # Первый проход: считаем общее количество репозиториев
    while true; do
      RESPONSE=$(curl -s -u "$USERNAME:$TOKEN" "$BITBUCKET_URL/rest/api/1.0/projects/$PROJECT_KEY/repos?start=$START&limit=$LIMIT")
      COUNT=$(echo "$RESPONSE" | jq '.values | length')
      TOTAL_REPOS=$((TOTAL_REPOS + COUNT))
      IS_LAST_PAGE=$(echo "$RESPONSE" | jq -r '.isLastPage')
      if [ "$IS_LAST_PAGE" == "true" ]; then break; fi
      START=$((START + LIMIT))
    done

    echo "  Найдено репозиториев: $TOTAL_REPOS"
    START=0
    CURRENT=0

    # Второй проход: клонируем
    while true; do
      RESPONSE=$(curl -s -u "$USERNAME:$TOKEN" "$BITBUCKET_URL/rest/api/1.0/projects/$PROJECT_KEY/repos?start=$START&limit=$LIMIT")
      
      REPOS=$(echo "$RESPONSE" | jq -r '.values[] | "\(.slug) \(.links.clone[] | select(.name=="ssh") | .href)"')
      
      if [ -z "$REPOS" ]; then break; fi

      echo "$REPOS" | while read -r slug ssh_url; do
        CURRENT=$((CURRENT + 1))
        if [ ! -d "$slug" ]; then
          printf "  [%d/%d] Клонируем %-30s " "$CURRENT" "$TOTAL_REPOS" "$slug"
          if git clone "$ssh_url" >> "$LOG_FILE" 2>&1; then
            echo "✓"
          else
            echo "✗ (ошибка)"
          fi
        else
          printf "  [%d/%d] %-30s пропущен\n" "$CURRENT" "$TOTAL_REPOS" "$slug"
        fi
      done

      IS_LAST_PAGE=$(echo "$RESPONSE" | jq -r '.isLastPage')
      if [ "$IS_LAST_PAGE" == "true" ]; then break; fi
      START=$((START + LIMIT))
    done

    # Возвращаемся в корень repos/
    cd ..
  done

  echo ""
  echo "=============================================="
  echo "Клонирование завершено: $(date)"
  echo "=============================================="
} | tee "$LOG_FILE"

echo ""
echo "Лог сохранен в: $LOG_FILE"