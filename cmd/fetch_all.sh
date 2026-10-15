#!/usr/bin/env bash

show_help() {
  cat << EOF
Использование: $0 <путь_к_конфигу>

Скрипт обновляет все репозитории в указанной директории (git fetch --all).
Поддерживает структуру с подкаталогами по проектам.

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
DEST_DIR=$(jq -r '.bitbucket.dest_dir // empty' "$CONFIG_FILE")
LOG_DIR=$(jq -r '.bitbucket.log_dir // empty' "$CONFIG_FILE")

# Валидация обязательных полей
if [ -z "$DEST_DIR" ]; then
  echo "Ошибка: bitbucket.dest_dir не указан в конфиге"
  exit 1
fi
if [ -z "$LOG_DIR" ]; then
  echo "Ошибка: bitbucket.log_dir не указан в конфиге"
  exit 1
fi

if [ ! -d "$PROJECT_ROOT/$DEST_DIR" ]; then
  echo "Ошибка: Директория $PROJECT_ROOT/$DEST_DIR не существует"
  exit 1
fi

# Создаем директорию для логов
mkdir -p "$PROJECT_ROOT/$LOG_DIR"

# Формируем имя лог-файла
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$PROJECT_ROOT/$LOG_DIR/fetch-$TIMESTAMP.log"

cd "$PROJECT_ROOT/$DEST_DIR" || exit

{
  echo "=============================================="
  echo "Начало обновления: $(date)"
  echo "=============================================="

  # Считаем общее количество репозиториев (с учетом вложенности по проектам)
  TOTAL_REPOS=$(find . -maxdepth 3 -type d -name ".git" | wc -l | tr -d ' ')
  CURRENT=0
  UPDATED=0
  FAILED=0

  echo "  Найдено репозиториев: $TOTAL_REPOS"
  echo ""

  # Проходим по всем директориям (с учетом вложенности по проектам)
  for git_dir in $(find . -maxdepth 3 -type d -name ".git"); do
    dir=$(dirname "$git_dir")
    CURRENT=$((CURRENT + 1))
    printf "  [%d/%d] %-40s " "$CURRENT" "$TOTAL_REPOS" "$dir"
    cd "$dir" || continue
    if git fetch --all --quiet >> "$LOG_FILE" 2>&1; then
      echo "✓"
      UPDATED=$((UPDATED + 1))
    else
      echo "✗ (ошибка)"
      FAILED=$((FAILED + 1))
    fi
    cd "$PROJECT_ROOT/$DEST_DIR" || exit
  done

  echo ""
  echo "  Итого: обновлено $UPDATED, ошибок $FAILED"
  echo ""
  echo "=============================================="
  echo "Обновление завершено: $(date)"
  echo "=============================================="
} | tee "$LOG_FILE"

echo ""
echo "Лог сохранен в: $LOG_FILE"