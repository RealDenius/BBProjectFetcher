#!/usr/bin/env bash

show_help() {
  cat << EOF
Использование: $0 <путь_к_конфигу>

Скрипт-оболочка для выполнения полного цикла:
1. Клонирование всех репозиториев из проектов
2. Обновление всех репозиториев (git fetch)

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Определяем корень проекта (родитель от cmd/)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Преобразуем путь к конфигу в абсолютный
if [[ "$CONFIG_FILE" != /* ]]; then
  CONFIG_FILE="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"
fi

echo "=========================================="
echo "Запуск полного цикла"
echo "Конфиг: $CONFIG_FILE"
echo "Время начала: $(date)"
echo "=========================================="
echo ""

# Шаг 1: Клонирование
echo ">>> ШАГ 1: Клонирование репозиториев"
echo "------------------------------------------"
"$SCRIPT_DIR/clone_all.sh" "$CONFIG_FILE"
CLONE_EXIT_CODE=$?

if [ $CLONE_EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Ошибка: Клонирование завершилось с кодом $CLONE_EXIT_CODE"
  echo "Прерывание выполнения."
  exit $CLONE_EXIT_CODE
fi

echo ""
echo ">>> ШАГ 2: Обновление репозиториев"
echo "------------------------------------------"

# Шаг 2: Обновление
"$SCRIPT_DIR/fetch_all.sh" "$CONFIG_FILE"
FETCH_EXIT_CODE=$?

if [ $FETCH_EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Ошибка: Обновление завершилось с кодом $FETCH_EXIT_CODE"
  exit $FETCH_EXIT_CODE
fi

echo ""
echo "=========================================="
echo "Полный цикл завершен успешно"
echo "Время окончания: $(date)"
echo "=========================================="