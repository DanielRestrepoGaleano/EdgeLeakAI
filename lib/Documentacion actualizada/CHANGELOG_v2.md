# 📋 EdgeLeak AI — Changelog v2.0

> **Rama:** `feature/admin-dashboard-ux-improvements`  
> **Fecha:** 2026-04-24  
> **Equipo:** Daniel Restrepo Galeano / Oscar Mauricio

---

## 🗂️ Índice

1. [Resumen de cambios](#1-resumen-de-cambios)
2. [Nuevos archivos creados](#2-nuevos-archivos-creados)
3. [Archivos modificados](#3-archivos-modificados)
4. [Separación de roles](#4-separación-de-roles)
5. [Endpoints de la API local](#5-endpoints-de-la-api-local)
6. [Base de datos SQLite v4](#6-base-de-datos-sqlite-v4)
7. [Hardware — Mapeo de pines ESP32](#7-hardware--mapeo-de-pines-esp32)
8. [Firmware ESP32 — Sketch de referencia](#8-firmware-esp32--sketch-de-referencia)
9. [Umbrales y significado de los datos](#9-umbrales-y-significado-de-los-datos)
10. [Pendientes del estado anterior](#10-pendientes-del-estado-anterior)

---

## 1. Resumen de cambios

| Área | Estado anterior | Estado v2.0 |
|------|----------------|-------------|
| DTOs formales | ⚠️ Parcial (modelos mixtos) | ✅ Separación DTO / Entity completa |
| Seguridad en POST /api/sensor | ⚠️ Sin autenticación | ✅ `x-api-key` obligatorio |
| Tabla de lecturas raw | ❌ No existía | ✅ `lecturas_raw` en SQLite v4 |
| Dashboard Administrador | ⚠️ Compartido con operador | ✅ Pantalla exclusiva de monitoreo |
| Dashboard Operador | ✅ Simulador disponible | ✅ + Leyenda UX de umbrales |
| Historial de fugas | ⚠️ Sin filtros ni eliminación | ✅ Filtros, paginación, eliminación |
| Navegación por rol | ❌ Todos al mismo dashboard | ✅ Admin → `/admin_dashboard`, Operador → `/dashboard` |

---

## 2. Nuevos archivos creados

### DTOs (`lib/data/dto/`)

| Archivo | Responsabilidad |
|---------|----------------|
| `sensor_request_dto.dart` | Valida y transporta el payload del ESP32 (`ruido`, `flujo`). Lanza `FormatException` si faltan campos. |
| `alerta_fuga_dto.dart` | DTO de presentación para el historial de fugas. Construido desde `AlertaFugaModel`. Usado en la respuesta JSON del endpoint `GET /api/history`. |
| `lectura_raw_dto.dart` | DTO de presentación para lecturas crudas del sensor. Construido desde `LecturaRawModel`. |

### Entidad (`lib/data/models/`)

| Archivo | Responsabilidad |
|---------|----------------|
| `lectura_raw_model.dart` | Entidad de dominio para la tabla `lecturas_raw`. Guarda `ruido`, `flujo`, `estado` y `timestamp` de cada lectura del ESP32. |

### Pantallas (`lib/view/screens/`)

| Archivo | Responsabilidad |
|---------|----------------|
| `admin_dashboard_screen.dart` | Panel de monitoreo exclusivo para administradores. Muestra estado del sistema, buffer de lecturas en tiempo real, contexto UX (significado de L/min, umbrales, lógica de Sensor Fusion) y accesos rápidos. **No contiene el simulador de hardware.** |

---

## 3. Archivos modificados

### `lib/data/services/database_service.dart`
- Versión de base de datos elevada de **v3 → v4**.
- Crea la tabla `lecturas_raw` en `onCreate` y en `onUpgrade` (para dispositivos con DB antigua).
- Nuevos métodos:
  - `obtenerHistorialFiltrado({severidad, desde, hasta, limit, offset})` — historial con filtros y paginación.
  - `eliminarAlerta(int id)` — elimina una alerta por ID.
  - `eliminarAlertas(List<int> ids)` — elimina múltiples alertas en una sola consulta SQL.
  - `insertarLecturaRaw(LecturaRawModel)` — persiste cada lectura del ESP32.
  - `obtenerLecturasRaw({limit})` — recupera las últimas lecturas crudas.

### `lib/data/services/local_api_service.dart`
- **POST /api/sensor** ahora valida `x-api-key` en el header (misma clave que `GET /api/history`).
- Usa `SensorRequestDto.fromMap()` para deserializar y validar el cuerpo de la petición.
- `GET /api/history` usa `AlertaFugaDto.fromModel()` para serializar la respuesta.

### `lib/controllers/dashboard_controller.dart`
- Historial refactorizado con paginación (20 items por página) y filtros de severidad + rango de fechas.
- Nuevos métodos públicos:
  - `inicializarHistorial()` — carga la primera página con filtros activos.
  - `cargarMasHistorial()` — agrega la siguiente página.
  - `aplicarFiltros({severidad, desde, hasta})` — aplica filtros y reinicia la paginación.
  - `limpiarFiltros()` — restablece todos los filtros.
  - `eliminarAlerta(int id)` — elimina una alerta y recarga.
  - `eliminarAlertasSeleccionadas()` — elimina todas las alertas marcadas.
  - `toggleSeleccion(int id)` / `activarModoSeleccion(int id)` / `cancelarSeleccion()` — gestión de selección múltiple.
- `procesarLecturaSensor()` ahora persiste cada lectura en `lecturas_raw`.

### `lib/view/screens/dashboard_screen.dart`
- Se eliminó el botón de "Gestión de Usuarios" (ahora solo en el admin dashboard).
- Se añadió la leyenda de umbrales (`_UmbralLegenda`) debajo del indicador de caudal.
- Tooltip informativo en el selector de simulación.
- `inicializarHistorial()` se llama al navegar al historial.

### `lib/view/screens/historial_screen.dart`
- Completamente reescrito como `StatefulWidget`.
- **Barra de filtros** con:
  - Selector de rango de fechas (`showDateRangePicker`).
  - Chips de severidad: Todas / Crítica / Advertencia / Normal.
  - Botón "Limpiar" (aparece solo si hay filtros activos).
- **Paginación**: muestra 20 items; botón "Cargar más" si hay más registros.
- **Eliminación individual**: botón de papelera en cada card.
- **Selección múltiple**: mantener presionado activa el modo selección → seleccionar varias → eliminar todas.
- Cards rediseñadas con badge de severidad, fecha formateada, y soporte de selección visual.

### `lib/config/routes/app_routes.dart`
- Nueva ruta `adminDashboardScreen = 'admin_dashboard'`.
- `AdminDashboardScreen` registrado en el mapa de rutas.

### `lib/view/screens/login_screen.dart`
- Tras login exitoso:
  - Si `usuario.esTemporal == 1` → `changePasswordScreen` (sin cambios).
  - Si `usuario.esAdmin` → **`adminDashboardScreen`**.
  - En otro caso → `dashboardScreen`.
- Se llama `inicializarHistorial()` al entrar a cualquier dashboard.

---

## 4. Separación de roles

```
Login exitoso
     │
     ├─ es_temporal = 1 ──────→ ChangePasswordScreen
     │
     ├─ rol = 'admin' ─────────→ AdminDashboardScreen
     │                            (monitoreo, sin simulador)
     │
     └─ rol = 'operador' ──────→ DashboardScreen
                                  (simulador + evaluación IA)
```

Desde el `AdminDashboardScreen` el administrador accede a:
- **Gestión de Usuarios** → `AdminUsersScreen`
- **Historial de Fugas** → `HistorialScreen` (con todos los filtros)

---

## 5. Endpoints de la API local

El servidor HTTP corre en `http://<IP_DEL_DISPOSITIVO>:8080` solo en red Wi-Fi local.

### POST /api/sensor

Recibe lecturas del sensor ESP32 cada ciclo (recomendado: cada 5 s).

**Headers requeridos:**
```
Content-Type: application/json
x-api-key: <valor de LOCAL_API_KEY en .env>
```

**Body:**
```json
{
  "ruido": 1800,
  "flujo": 0.08
}
```

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `ruido` | `int` | Valor ADC del KY-038 (0–4095, pin D34 del ESP32) |
| `flujo` | `double` | Caudal en L/min del YF-S201 (pin D32 del ESP32) |

**Respuesta exitosa (200):**
```json
{
  "status": "ok",
  "estado": "Posible Fuga",
  "ruido": 1800,
  "flujo": 0.08
}
```

**Errores posibles:**
| Código | Causa |
|--------|-------|
| 400 | JSON inválido o campos faltantes |
| 401 | `x-api-key` ausente o incorrecto |
| 500 | Error interno del servidor |

---

### GET /api/history

Devuelve el historial de fugas detectadas por la IA.

**Headers requeridos:**
```
x-api-key: <valor de LOCAL_API_KEY en .env>
```

**Respuesta exitosa (200):**
```json
[
  {
    "id": 5,
    "veredicto": "Fuga Detectada",
    "severidad": "Crítica",
    "mensaje": "Cierra la llave principal y revisa las conexiones bajo el lavaplatos.",
    "timestamp": "2026-04-24T22:15:30.000"
  }
]
```

---

## 6. Base de datos SQLite v4

**Nombre del archivo:** `edgeleak_v4.db`

### Tabla `historial`
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | INTEGER PK | Autoincremental |
| `veredicto` | TEXT | Resultado de la IA: `Fuga Detectada` / `Flujo Normal` |
| `severidad` | TEXT | `Crítica` / `Advertencia` / `Normal` |
| `mensaje` | TEXT | Recomendación generada por la IA |
| `fecha` | TEXT | ISO 8601 |

### Tabla `lecturas_raw` *(nueva en v4)*
| Columna | Tipo | Descripción |
|---------|------|-------------|
| `id` | INTEGER PK | Autoincremental |
| `ruido` | INTEGER | Valor ADC del sensor de ruido (0–4095) |
| `flujo` | REAL | Caudal en L/min |
| `estado` | TEXT | `Uso Normal` / `Posible Fuga` / `Sin Clasificar` |
| `timestamp` | TEXT | ISO 8601 |

### Tabla `usuarios`
*(sin cambios estructurales desde v3)*

---

## 7. Hardware — Mapeo de pines ESP32

| Componente | Pin del Sensor | Pin ESP32 (30 pines) | Función |
|-----------|---------------|---------------------|---------|
| Sensor de Ruido KY-038 | VCC | 3V3 | Alimentación (3.3 V) |
| | GND | GND | Tierra común |
| | A0 (Analógico) | **D34** | Medición ADC de nivel de ruido |
| | DO (Digital) | **D35** | Detección de picos (golpes) |
| Sensor de Flujo YF-S201 | Rojo (VCC) | 3V3 | Alimentación de señal segura |
| | Negro (GND) | GND | Tierra común |
| | Amarillo (Data) | **D32** | Conteo de pulsos de agua |

> ⚠️ Los pines D34 y D35 del ESP32 son **solo entrada** (input-only), ideal para ADC y señales digitales.

---

## 8. Firmware ESP32 — Sketch de referencia

El sketch `main.cpp` del repositorio de pruebas implementa:

- **Factor de calibración:** `450.0` pulsos por litro (YF-S201 estándar).
- **Intervalo de lectura:** 1000 ms (1 segundo).
- **Interrupción en FALLING** para el pin D32 (conteo de pulsos de caudal).
- Impresión por Serial (115200 baud) de: caudal, ruido analógico y alerta de golpe.

Para enviar las lecturas a la app, reemplaza la sección `mostrarDatos()` con una petición HTTP POST:

```cpp
#include <WiFi.h>
#include <HTTPClient.h>

const char* ssid     = "TU_SSID";
const char* password = "TU_CLAVE_WIFI";
const char* apiUrl   = "http://192.168.1.X:8080/api/sensor";
const char* apiKey   = "edgeleak-share-2024"; // valor de LOCAL_API_KEY

void enviarDatos(float caudal, int ruido) {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.begin(apiUrl);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-api-key", apiKey);

  String body = "{\"ruido\":" + String(ruido) +
                ",\"flujo\":" + String(caudal, 2) + "}";
  int code = http.POST(body);
  http.end();
}
```

> Reemplaza `192.168.1.X` con la IP del dispositivo Android/iOS en la misma red Wi-Fi.

---

## 9. Umbrales y significado de los datos

### L/min (Litros por minuto)
Cuántos litros de agua fluyen a través de la tubería en un minuto.

| Rango | Estado | Significado |
|-------|--------|-------------|
| 0.1 – 0.5 L/min | 🟢 Normal | Uso doméstico regular del lavaplatos |
| 0.5 – 5.0 L/min | 🟡 Anomalía | Flujo elevado, posible mal uso o pre-fuga |
| > 5.0 L/min | 🔴 Fuga | Fuga activa — intervención inmediata requerida |

### Sensor de Ruido (ADC 0–4095)
| Valor | Interpretación |
|-------|---------------|
| < 1500 | Ambiente silencioso, tubería sin vibración |
| > 1500 | Ruido en tubería — puede indicar flujo o golpe de agua |

### Lógica de Sensor Fusion
```
Ruido > 1500  +  Flujo > 0.5 L/min  →  Uso Normal
Ruido > 1500  +  Flujo < 0.1 L/min  →  Posible Fuga
Resto de combinaciones              →  Sin Clasificar

Si "Posible Fuga" persiste 3 lecturas consecutivas (~15 s)
  → Se llama a Groq AI para análisis (cooldown: 3 min)
```

---

## 10. Pendientes del estado anterior

| Ítem | Estado |
|------|--------|
| Hardware físico conectado (deshabilitar simulador en modo real) | 🔄 La app ya acepta datos del ESP32 vía POST; el simulador se mantiene solo en la vista de operador. Para usar hardware real, enviar datos reales al endpoint. |
| Exposición en internet (ngrok / servidor cloud) | ❌ Pendiente — actualmente solo funciona en red Wi-Fi local |
| Autenticación por roles en la API REST (JWT) | ❌ Pendiente — se usa API Key simple por ahora |

---

*Generado automáticamente por el agente Copilot — EdgeLeak AI v2.0*
