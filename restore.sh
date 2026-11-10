#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <backup_file>"
    exit 1
fi

BACKUP_FILE=$1
DB_USER="cinema_user"
DB_NAME="cinema_db"

echo "Restoring from $BACKUP_FILE at $(date)"
gunzip -c $BACKUP_FILE | psql -U $DB_USER -d $DB_NAME

if [ $? -eq 0 ]; then
    echo "Restore successful"
else
    echo "Restore failed!"
    exit 1
fi