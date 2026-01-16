#!/bin/bash
# setup.sh - Автоматическая установка Video Generator на Ubuntu

set -e  # Останавливаем скрипт при ошибках

echo "==============================================="
echo "  Установка Video Generator для Ubuntu Server"
echo "==============================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}→${NC} $1"
}

# Проверка прав
if [ "$EUID" -eq 0 ]; then 
    print_error "Не запускайте скрипт от root! Используйте обычного пользователя."
    exit 1
fi

# Шаг 1: Клонирование репозитория
print_info "Шаг 1: Клонирование репозитория..."
if [ -d "app" ]; then
    print_info "Директория app уже существует, обновляю..."
    cd app
    git pull origin main
    cd ..
else
    git clone https://github.com/rse0005-by-r/app.git
    if [ $? -ne 0 ]; then
        print_error "Ошибка клонирования репозитория!"
        exit 1
    fi
fi
print_success "Репозиторий склонирован/обновлен"

# Шаг 2: Переход в директорию проекта
cd app
PROJECT_DIR=$(pwd)

# Шаг 3: Обновление системы
print_info "Шаг 2: Обновление системы..."
sudo apt update && sudo apt upgrade -y
print_success "Система обновлена"

# Шаг 4: Установка системных зависимостей
print_info "Шаг 3: Установка системных зависимостей..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    ffmpeg \
    git \
    curl \
    wget \
    libsm6 \
    libxext6 \
    libgl1-mesa-glx \
    libfontconfig1 \
    libxrender1
print_success "Системные зависимости установлены"

# Шаг 5: Проверка FFmpeg
print_info "Шаг 4: Проверка FFmpeg..."
if command -v ffmpeg &> /dev/null; then
    ffmpeg_version=$(ffmpeg -version | head -n1 | awk '{print $3}')
    print_success "FFmpeg найден (версия: $ffmpeg_version)"
else
    print_error "FFmpeg не установлен!"
    exit 1
fi

# Шаг 6: Создание виртуального окружения
print_info "Шаг 5: Создание виртуального окружения..."
if [ -d "venv" ]; then
    print_info "Виртуальное окружение уже существует"
else
    python3 -m venv venv
    print_success "Виртуальное окружение создано"
fi

# Шаг 7: Активация и обновление pip
print_info "Шаг 6: Активация виртуального окружения..."
source venv/bin/activate
pip install --upgrade pip setuptools wheel
print_success "Pip обновлен"

# Шаг 8: Проверка и создание requirements.txt
print_info "Шаг 7: Установка Python пакетов..."
if [ -f "requirements.txt" ]; then
    print_info "Установка из requirements.txt..."
    pip install -r requirements.txt
else
    print_info "requirements.txt не найден, устанавливаю основные пакеты..."
    pip install \
        Pillow>=10.0.0 \
        opencv-python>=4.8.0 \
        numpy>=1.24.0 \
        requests>=2.31.0 \
        flask>=3.0.0 \
        python-dotenv>=1.0.0
    
    # Создаем requirements.txt
    pip freeze > requirements.txt
    print_success "requirements.txt создан"
fi
print_success "Python пакеты установлены"

# Шаг 9: Создание структуры директорий
print_info "Шаг 8: Создание структуры директорий..."
mkdir -p video_generator/input_images
mkdir -p video_generator/output
mkdir -p video_generator/temp
mkdir -p video_generator/publish
mkdir -p logs

# Создаем пример конфигурации
if [ ! -f "video_generator/config.json" ]; then
    cat > video_generator/config.json << EOF
{
    "image_width": 1920,
    "image_height": 1080,
    "fps": 60,
    "short_video_duration": [8, 10],
    "long_video_duration": [40, 60],
    "language": "ru",
    "api_keys": {
        "google_ai_studio": "ВАШ_КЛЮЧ_ЗДЕСЬ",
        "stability_ai": "ВАШ_КЛЮЧ_ЗДЕСЬ"
    }
}
EOF
    print_success "Конфигурационный файл создан"
fi

# Создаем пример референсного изображения
if [ ! -f "video_generator/input_images/example.json" ]; then
    cat > video_generator/input_images/example.json << EOF
{
    "positive": "яркие цвета, высокая детализация, космическая тематика",
    "negative": "размытость, низкое качество, водяные знаки",
    "style": "футуристический цифровой арт"
}
EOF
    print_info "Пример описания создан: video_generator/input_images/example.json"
fi

print_success "Структура директорий создана"

# Шаг 10: Проверка основного скрипта
print_info "Шаг 9: Проверка основного скрипта..."
if [ -f ".run.py" ]; then
    # Перемещаем скрипт в нужную директорию если нужно
    if [ ! -f "video_generator/run.py" ]; then
        cp .run.py video_generator/run.py
    fi
    chmod +x video_generator/run.py
    
    # Проверяем Python синтаксис
    if python3 -m py_compile video_generator/run.py; then
        print_success "Синтаксис скрипта корректен"
    else
        print_error "Ошибка в синтаксисе скрипта!"
        exit 1
    fi
else
    print_error "Основной скрипт .run.py не найден!"
    exit 1
fi

# Шаг 11: Создание сервиса systemd (опционально)
print_info "Шаг 10: Настройка автозапуска..."
read -p "Настроить автозапуск как сервис systemd? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SERVICE_FILE="/etc/systemd/system/video-generator.service"
    
    cat | sudo tee $SERVICE_FILE << EOF
[Unit]
Description=Video Generator Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=$USER
WorkingDirectory=$PROJECT_DIR/video_generator
Environment="PATH=$PROJECT_DIR/venv/bin"
ExecStart=$PROJECT_DIR/venv/bin/python $PROJECT_DIR/video_generator/run.py
StandardOutput=append:$PROJECT_DIR/logs/service.log
StandardError=append:$PROJECT_DIR/logs/error.log

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable video-generator
    print_success "Сервис systemd создан и включен"
else
    print_info "Автозапуск не настроен"
fi

# Шаг 12: Создание скрипта управления
print_info "Шаг 11: Создание скрипта управления..."
cat > manage.sh << 'EOF'
#!/bin/bash
# manage.sh - Скрипт управления Video Generator

PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
VENV_DIR="$PROJECT_DIR/../venv"

case "$1" in
    start)
        echo "Запуск Video Generator..."
        cd "$PROJECT_DIR"
        source "$VENV_DIR/bin/activate"
        python run.py
        ;;
    stop)
        echo "Остановка сервиса..."
        sudo systemctl stop video-generator 2>/dev/null
        pkill -f "python run.py"
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        if pgrep -f "python run.py" > /dev/null; then
            echo "Video Generator запущен"
        else
            echo "Video Generator остановлен"
        fi
        ;;
    update)
        echo "Обновление из GitHub..."
        cd "$PROJECT_DIR/.."
        git pull origin main
        source "$VENV_DIR/bin/activate"
        pip install -r requirements.txt
        echo "Обновление завершено"
        ;;
    logs)
        tail -f "$PROJECT_DIR/../logs/service.log"
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status|update|logs}"
        exit 1
        ;;
esac
EOF

chmod +x manage.sh
print_success "Скрипт управления создан: manage.sh"

# Шаг 13: Тестовая проверка
print_info "Шаг 12: Тестовая проверка..."
echo "Проверяю установленные компоненты:"

# Проверка Python
python3 --version && print_success "Python работает"

# Проверка FFmpeg
ffmpeg -version | head -n1 && print_success "FFmpeg работает"

# Проверка пакетов Python
python3 -c "import PIL; import cv2; import numpy; import requests; print('Все пакеты импортируются')" \
    && print_success "Python пакеты работают"

# Финальный вывод
echo ""
echo "==============================================="
echo -e "${GREEN}УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!${NC}"
echo "==============================================="
echo ""
echo "📁 Структура проекта:"
echo "  $PROJECT_DIR/"
echo "  ├── venv/                    # Виртуальное окружение"
echo "  ├── video_generator/         # Основная директория"
echo "  │   ├── run.py              # Основной скрипт"
echo "  │   ├── input_images/       # Референсные изображения"
echo "  │   ├── output/             # Готовые видео"
echo "  │   ├── temp/               # Временные файлы"
echo "  │   └── publish/            # Для публикации"
echo "  ├── logs/                   # Логи"
echo "  ├── manage.sh               # Скрипт управления"
echo "  └── requirements.txt        # Зависимости"
echo ""
echo "🚀 Команды для запуска:"
echo ""
echo "Способ 1: Вручную"
echo "  cd $PROJECT_DIR/video_generator"
echo "  source ../venv/bin/activate"
echo "  python run.py"
echo ""
echo "Способ 2: Через скрипт управления"
echo "  ./manage.sh start"
echo ""
echo "Способ 3: Как сервис systemd"
echo "  sudo systemctl start video-generator"
echo "  sudo systemctl status video-generator"
echo ""
echo "🔧 Дополнительные команды:"
echo "  ./manage.sh stop           # Остановить"
echo "  ./manage.sh restart        # Перезапустить"
echo "  ./manage.sh status         # Статус"
echo "  ./manage.sh update         # Обновить из GitHub"
echo "  ./manage.sh logs           # Просмотр логов"
echo ""
echo "📝 Следующие шаги:"
echo "1. Поместите референсные изображения в video_generator/input_images/"
echo "2. Для каждого изображения создайте .json файл с описанием"
echo "3. Запустите скрипт"
echo ""
echo "При возникновении проблем проверьте логи:"
echo "  tail -f $PROJECT_DIR/../logs/service.log"
echo "  cat $PROJECT_DIR/../video_generator.log"
echo ""

# Активируем окружение для первого запуска
cd video_generator
source ../venv/bin/activate

# Запускаем тестовый запуск
print_info "Пробный запуск для проверки..."
if timeout 5s python -c "print('Тестовый запуск успешен')"; then
    print_success "Тестовый запуск выполнен"
else
    print_error "Ошибка при тестовом запуске"
fi