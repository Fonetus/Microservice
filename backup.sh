#!/bin/bash

# Параметры подключения
DB_USER="cinema_user"
DB_NAME="cinema_db"
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/cinema_db_$DATE.sql.gz"

# Создаём полный бэкап
echo "Starting backup at $(date)"
pg_dump -U $DB_USER -d $DB_NAME | gzip > $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "Backup successful: $BACKUP_FILE"
    # Удаляем бэкапы старше 7 дней
    find $BACKUP_DIR -name "cinema_db_*.sql.gz" -mtime +7 -delete
    echo "Old backups cleaned"
else
    echo "Backup failed!"
    exit 1
fi