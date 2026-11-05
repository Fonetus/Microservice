# Берем легкий базовый образ Python
FROM python:3.10-slim

# Создаем рабочую директорию внутри контейнера
WORKDIR /app

# Копируем файлы зависимостей и устанавливаем их
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем исходный код приложения
COPY . .

# Команда для запуска сервиса (слушаем на порту 8000)
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]