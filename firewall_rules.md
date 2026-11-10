# FireWall Rules для Cinema Booking System

## Сетевая топология

| Зона | Подсеть | Компоненты | IP-адреса |
|------|---------|------------|-----------|
| Public Zone | 10.10.1.0/28 | API Gateway (future) | 10.10.1.1 |
| Internal Zone | 10.10.2.0/28 | booking-service | 10.10.2.2 |
| Data Zone | 10.10.3.0/28 | postgres, redis, rabbitmq | 10.10.3.2, 10.10.3.3, 10.10.3.4 |

---

## FireWall Rules для booking-service (Internal Zone)

| Hostname | Direction | Proto | SRC IP | SRC Port | DST IP | DST Port | Обоснование |
|----------|-----------|-------|--------|----------|--------|----------|-------------|
| booking-service | IN | TCP | internet | * | 10.10.2.2 | 8000 | Пользовательский доступ к API |
| booking-service | OUT | TCP | 10.10.2.2 | * | 10.10.3.2 | 5432 | Доступ к PostgreSQL (явное разрешение) |
| booking-service | OUT | TCP | 10.10.2.2 | * | 10.10.3.3 | 6379 | Доступ к Redis (явное разрешение) |
| booking-service | OUT | TCP | 10.10.2.2 | * | 10.10.3.4 | 5672 | Доступ к RabbitMQ (явное разрешение) |
| booking-service | OUT | ICMP | 10.10.2.2 | * | 10.10.3.0/28 | * | Диагностика сети |

---

## FireWall Rules для postgres (Data Zone)

| Hostname | Direction | Proto | SRC IP | SRC Port | DST IP | DST Port | Обоснование |
|----------|-----------|-------|--------|----------|--------|----------|-------------|
| postgres | IN | TCP | 10.10.2.2 | * | 10.10.3.2 | 5432 | Приём запросов от booking-service (явное разрешение) |
| postgres | OUT | TCP | 10.10.3.2 | * | 10.10.2.0/28 | * | **ЗАПРЕЩЕНО** - DROP (принцип минимальности) |
| postgres | OUT | TCP | 10.10.3.2 | * | 10.10.3.3 | * | **ЗАПРЕЩЕНО** - DROP (изоляция в Data Zone) |
| postgres | OUT | TCP | 10.10.3.2 | * | 10.10.3.4 | * | **ЗАПРЕЩЕНО** - DROP (изоляция в Data Zone) |
| postgres | OUT | ICMP | 10.10.3.2 | * | 10.10.2.0/28 | * | **ЗАПРЕЩЕНО** - DROP |

---

## FireWall Rules для redis (Data Zone)

| Hostname | Direction | Proto | SRC IP | SRC Port | DST IP | DST Port | Обоснование |
|----------|-----------|-------|--------|----------|--------|----------|-------------|
| redis | IN | TCP | 10.10.2.2 | * | 10.10.3.3 | 6379 | Приём запросов от booking-service (явное разрешение) |
| redis | OUT | TCP | 10.10.3.3 | * | 10.10.2.0/28 | * | **ЗАПРЕЩЕНО** - DROP (принцип минимальности) |
| redis | OUT | TCP | 10.10.3.3 | * | 10.10.3.2 | * | **ЗАПРЕЩЕНО** - DROP (изоляция в Data Zone) |
| redis | OUT | TCP | 10.10.3.3 | * | 10.10.3.4 | * | **ЗАПРЕЩЕНО** - DROP (изоляция в Data Zone) |

---

## FireWall Rules для rabbitmq (Data Zone)

| Hostname | Direction | Proto | SRC IP | SRC Port | DST IP | DST Port | Обоснование |
|----------|-----------|-------|--------|----------|--------|----------|-------------|
| rabbitmq | IN | TCP | 10.10.2.2 | * | 10.10.3.4 | 5672 | Приём запросов от booking-service (явное разрешение) |
| rabbitmq | IN | TCP | 10.10.2.2 | * | 10.10.3.4 | 15672 | Management UI (только для разработки) |
| rabbitmq | OUT | TCP | 10.10.3.4 | * | 10.10.2.0/28 | * | **ЗАПРЕЩЕНО** - DROP (принцип минимальности) |
| rabbitmq | OUT | TCP | 10.10.3.4 | * | 10.10.3.2 | * | **ЗАПРЕЩЕНО** - DROP (изоляция в Data Zone) |
| rabbitmq | OUT | TCP | 10.10.3.4 | * | 10.10.3.3 | * | **ЗАПРЕЩЕНО** - DROP (изоляция в Data Zone) |
