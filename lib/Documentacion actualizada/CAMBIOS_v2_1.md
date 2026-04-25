# EdgeLeak AI v2.1 — Changelog y Documentación Técnica

## Resumen de Cambios

Esta versión conecta el hardware real (ESP32 + KY-037 + YF-S201) a la aplicación Flutter,
elimina el simulador de datos aleatorios y automatiza completamente el flujo de IA
mediante la regla de los **3 Strikes (Sensor Fusion)**.

---

## 1. Archivos Modificados

### 1.1 `lib/controllers/dashboard_controller.dart`

#### Eliminaciones
| Elemento eliminado | Motivo |
|--------------------|--------|
| `import 'dart:math'` | Ya no se generan datos aleatorios |
| Campo `modoSimulacion` | El modo ahora se deriva del hardware real |
| Campo `_simuladorTimer` | Sin timer de simulación |
| Método `_generarCaudalInmediato()` | Sin generación aleatoria de caudal |
| Método `iniciarSimuladorDinamico()` | Sin simulador dinámico |
| Método `setModoSimulacion()` | Sin selector de modo |
| Método `enviarPayloadIA()` | La IA ya no se invoca manualmente |
| Variables `_contadorPosibleFuga`, `_lastGroqEvaluation`, `_cooldownMinutos`, `_umbralFugasConsecutivas` | Reemplazadas por la regla de 3 strikes |

#### Adiciones / Cambios
| Elemento | Descripción |
|----------|-------------|
| `import email_service.dart` | Instancia de `EmailService` para alertas |
| `int ruidoActual` | Valor de ruido ADC más reciente del KY-037 |
| `String correoUsuarioActual` | Correo del operador logueado (para enviar alertas) |
| `int strikesFuga` | Contador público de anomalías consecutivas |
| `setUsuarioLogueado(nombre, {correo})` | Ahora acepta el correo del usuario como parámetro opcional |
| Lógica 3 Strikes en `procesarLecturaSensor()` | Ver sección 3 |
| Envío de correo en `_llamarGroqPorFuga()` | Si IA confirma fuga crítica → envía alerta por email |

#### Regla de los 3 Strikes (Sensor Fusion)
```
procesarLecturaSensor(ruido, flujo):
  si ruido > 1500 Y flujo < 0.1:
    strikesFuga++
  sino:
    strikesFuga = 0

  si strikesFuga >= 3 Y NO iaProcesando:
    strikesFuga = 0
    invocar IA (Groq API)
    si veredicto == "Fuga Detectada" O severidad == "Crítica":
      enviar correo a correoUsuarioActual
```

---

### 1.2 `lib/data/services/email_service.dart`

Se añadió el método `enviarCorreoAlerta(String destinatario, AlertaFugaModel alerta)`.

- Genera un correo HTML profesional con los campos: **Veredicto IA**, **Severidad**,
  **Mensaje** y **Fecha/Hora**.
- Se envía automáticamente cuando la IA confirma una fuga crítica.
- Utiliza las mismas credenciales SMTP configuradas en el archivo `.env`
  (`SMTP_EMAIL` / `SMTP_PASSWORD`).

---

### 1.3 `lib/view/screens/dashboard_screen.dart`

#### Eliminaciones
- `SegmentedButton` de Inyección de Estado (selector Normal / Anomalía / Fuga).
- Botón `ElevatedButton` de **"EVALUAR CON INTELIGENCIA ARTIFICIAL"**.
- Toda referencia a `controller.modoSimulacion`.

#### Adiciones
- **Indicadores en tiempo real** (fila de dos tarjetas):
  - **Nivel de Ruido**: muestra `ruidoActual` en unidades ADC (0–4095).
  - **Estado Sensor Fusion**: muestra `estadoActual` ('Uso Normal' / 'Posible Fuga' / 'Sin datos').
- **_StrikesIndicator**: barra visual de 3 rayos (⚡) que se iluminan según `strikesFuga`.
- El widget `WaterWaveWidget` ahora recibe el modo derivado del `estadoActual`:
  - `'Posible Fuga'` → modo `'Anomalia'` (olas medias, color amarillo).
  - Cualquier otro → modo `'Normal'` (olas suaves, color azul).

---

### 1.4 `lib/view/screens/login_screen.dart`

Al iniciar sesión correctamente, se pasa el correo del usuario al controlador:

```dart
widget.dashboardController.setUsuarioLogueado(
  usuario.nombre, correo: usuario.correo);
```

Esto permite que el controlador sepa a qué dirección de correo enviar la alerta.

---

## 2. Archivo Nuevo: `esp32_firmware.txt`

Ubicación: **raíz del proyecto** (mismo nivel que `pubspec.yaml`).
Se guarda como `.txt` para evitar conflictos con el linter de Dart.

### Hardware requerido
| Componente | Descripción |
|-----------|-------------|
| ESP32 Dev Module | Microcontrolador con Wi-Fi integrado |
| KY-037 | Sensor de sonido — salida analógica en **GPIO 34** |
| YF-S201 | Sensor de flujo de agua — salida digital en **GPIO 32** |

### Parámetros configurables
| Parámetro | Valor por defecto | Descripción |
|-----------|------------------|-------------|
| `SSID` | `<SSID_WIFI>` | Nombre de tu red Wi-Fi |
| `PASSWORD` | `<PASSWORD_WIFI>` | Contraseña de tu red Wi-Fi |
| `SERVER_URL` | `http://<IP_CELULAR>:8080/api/sensor` | IP local del teléfono con la app Flutter |
| `API_KEY` | `edgeleak-share-2024` | Header de autenticación del servidor local |
| `FACTOR_CALIBRACION` | `450.0` | Factor YF-S201 (pulsos/litro) |
| `INTERVALO_MS` | `5000` | Periodo de muestreo y envío (ms) |

### Flujo del firmware
```
setup():
  Configurar GPIO 34 (ADC) y GPIO 32 (INPUT_PULLUP + interrupción FALLING)
  Conectar a Wi-Fi
  Registrar ISR para contar pulsos del YF-S201

loop() cada 5 000 ms:
  1. Leer ruido: promedio de 50 muestras ADC en GPIO 34
  2. Calcular flujo: litros/min = pulsos / (factor × intervalo_s)
  3. Mostrar en Serial Monitor
  4. HTTP POST → { "ruido": <int>, "flujo": <float> }
     Headers: Content-Type: application/json, x-api-key: edgeleak-share-2024
```

### Fórmula de caudal YF-S201
```
frecuencia (Hz) = pulsos / intervalo_s
flujo (L/min)   = frecuencia / 7.5
                = pulsos / (7.5 × intervalo_s)
                = pulsos / (450 / 60 × intervalo_s)
```

---

## 3. Variables de Entorno (`.env`)

Asegúrate de que el archivo `.env` en la raíz del proyecto Flutter contenga:

```
SMTP_EMAIL=tu_correo@gmail.com
SMTP_PASSWORD=tu_app_password_gmail
GROQ_API_KEY=tu_clave_groq
```

> **Nota**: Para Gmail es necesario generar una **Contraseña de Aplicación** en
> `Seguridad de cuenta Google > Verificación en dos pasos > Contraseñas de aplicación`.

---

## 4. Arquitectura del Flujo Completo

```
ESP32 (KY-037 + YF-S201)
    │ HTTP POST cada 5 s
    ▼
LocalApiService (Puerto 8080)
    │ onProcesarLectura callback
    ▼
DashboardController.procesarLecturaSensor(ruido, flujo)
    │
    ├─ Actualiza ruidoActual, caudalActual, estadoActual → notifyListeners()
    ├─ Inserta LecturaRaw en SQLite
    ├─ Actualiza buffer en memoria (últimas 10 lecturas)
    │
    └─ Regla 3 Strikes
          │ strikesFuga >= 3
          ▼
       GroqApiService.analizarPatronReal()
          │ veredicto == "Fuga Detectada" || severidad == "Crítica"
          ▼
       EmailService.enviarCorreoAlerta(correoUsuarioActual, alerta)
       DatabaseService.insertarAlerta(alerta)

DashboardScreen (UI)
    ├─ WaterWaveWidget    ← animación basada en estadoActual
    ├─ Caudal (L/min)     ← caudalActual
    ├─ Ruido (ADC)        ← ruidoActual
    ├─ Estado SF          ← estadoActual
    ├─ StrikesIndicator   ← strikesFuga
    └─ UltimaAlerta card  ← ultimaAlerta
```

---

## 5. Elementos Intactos

Los siguientes componentes **no fueron modificados** en esta versión:

- `HistorialScreen` con filtros y paginación.
- `AdminDashboardScreen` y `AdminUsersScreen`.
- `DatabaseService` (historial, lecturas raw, usuarios).
- `GroqApiService` (lógica de análisis IA).
- `LocalApiService` (servidor HTTP en el teléfono).
- `AuthController` (autenticación y gestión de usuarios).
- `WaterWaveWidget` (animación de olas — sin cambios internos).
