#!/bin/bash

echo "=========================================="
echo "Network Isolation Test - Cinema Booking"
echo "=========================================="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция проверки TCP-соединения
check_tcp() {
    local container=$1
    local target=$2
    local port=$3
    local expected=$4

    result=$(docker exec $container python3 -c "import socket; s=socket.socket(); s.settimeout(2); s.connect(('$target', $port)); print('OK')" 2>&1)

    if [ "$result" = "OK" ] && [ "$expected" = "ALLOW" ]; then
        echo -e "${GREEN}✅ ALLOWED${NC} - $container -> $target:$port"
        return 0
    elif [ "$result" != "OK" ] && [ "$expected" = "DENY" ]; then
        echo -e "${GREEN}✅ DENIED${NC} - $container -> $target:$port (isolation works)"
        return 0
    else
        echo -e "${RED}❌ SECURITY ERROR${NC} - $container -> $target:$port (expected: $expected, got: $result)"
        return 1
    fi
}

echo "1. Testing ALLOWED connections (booking-service -> Data Zone)..."
echo "-----------------------------------------------------------"
check_tcp "cinema_booking_app" "10.10.3.2" 5432 "ALLOW"
check_tcp "cinema_booking_app" "10.10.3.3" 6379 "ALLOW"
check_tcp "cinema_booking_app" "10.10.3.4" 5672 "ALLOW"
echo ""

echo "2. Testing DENIED connections (Data Zone -> Internal Zone)..."
echo "-----------------------------------------------------------"
check_tcp "cinema_postgres" "10.10.2.2" 8000 "DENY"
check_tcp "cinema_redis" "10.10.2.2" 8000 "DENY"
check_tcp "cinema_rabbitmq" "10.10.2.2" 8000 "DENY"
echo ""

echo "3. Testing DENIED connections (Data Zone internal isolation)..."
echo "-----------------------------------------------------------"
check_tcp "cinema_postgres" "10.10.3.3" 6379 "DENY"
check_tcp "cinema_postgres" "10.10.3.4" 5672 "DENY"
check_tcp "cinema_redis" "10.10.3.2" 5432 "DENY"
check_tcp "cinema_redis" "10.10.3.4" 5672 "DENY"
echo ""

echo "4. Showing FireWall rules inside containers..."
echo "-----------------------------------------------------------"
echo "Postgres OUTPUT chain:"
docker exec cinema_postgres iptables -L OUTPUT -n
echo ""
echo "Redis OUTPUT chain:"
docker exec cinema_redis iptables -L OUTPUT -n
echo ""
echo "RabbitMQ OUTPUT chain:"
docker exec cinema_rabbitmq iptables -L OUTPUT -n
echo ""

echo "=========================================="
echo "Test Complete"
echo "=========================================="