#!/bin/bash

echo "🐕 Watchdog started - monitoring containers..."

while true; do
    # Проверяем каждый контейнер
    for container in cinema_postgres cinema_redis cinema_rabbitmq cinema_booking_app; do
        status=$(docker inspect -f '{{.State.Status}}' $container 2>/dev/null)

        if [ "$status" != "running" ]; then
            echo "⚠️  $container is $status - restarting..."
            docker start $container
            sleep 5
        fi
    done

    sleep 10
done