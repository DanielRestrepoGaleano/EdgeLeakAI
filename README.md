# 💧 EdgeLeak AI - Producto Mínimo Viable (MVP)

Bienvenido al repositorio oficial del MVP de **EdgeLeak AI**, un proyecto desarrollado para el **Proyecto Integrador (PICUR)** de la Corporación Universitaria Remington.

Esta aplicación móvil (construida con Flutter) simula el comportamiento de un sistema IoT para la detección inteligente de microfugas en lavaplatos domésticos utilizando Inteligencia Artificial (Groq API).

---

## 🛠️ Requisitos Previos (¡Muy Importante!)

Antes de clonar el proyecto, asegúrate de tener instalado el SDK de Flutter y un entorno de desarrollo (VS Code o Android Studio).

Abre tu terminal y ejecuta el siguiente comando para verificar tu entorno:
```bash
flutter doctor
```

⚠️ ATENCIÓN: Para que el proyecto compile sin errores, TODOS los checks de flutter doctor relacionados con tu sistema (Windows/Mac), Android toolchain y tu IDE deben estar en verde ([✓]). Si tienes una [X], debes resolverla antes de continuar.

---

## 🚀 Instalación y Configuración

Sigue estos pasos al pie de la letra para levantar el proyecto en tu máquina local:

### 1. Clonar el repositorio

Abre tu terminal en la carpeta donde deseas guardar el proyecto y ejecuta:
```bash
git clone <https://github.com/DanielRestrepoGaleano/EdgeLeakAI.git>
cd edgeleak
```

### 2. Instalar dependencias

Descarga todos los paquetes necesarios (HTTP, Sqflite, DotEnv, etc.) ejecutando:
```bash
flutter pub get
```

### 3. Configurar la API Key de Groq (Variables de Entorno)

Por seguridad, la llave de la Inteligencia Artificial no está subida a este repositorio. En la raíz del proyecto encontrarás un archivo llamado `.variable_entorno.example`.

- Renombra el archivo `.variable_entorno.example` para que se llame únicamente `.env`
- Ábrelo y reemplaza el texto con tu API Key real de Groq:
```env
# Archivo .env
GROQ_API_KEY=gsk_AQUI_PONE_LA_API_KEY_REAL_DE_GROQ
```

(Nota: El archivo `.env` ya está ignorado en el `.gitignore` para no subir credenciales sensibles).

### 4. Ejecutar la aplicación

Conecta tu celular por USB o inicia tu Emulador de Android/iOS y ejecuta:
```bash
flutter run
```

---

## 🧠 ¿Cómo funciona la aplicación? (Arquitectura MVP)

El sistema está diseñado bajo el patrón MVC (Modelo-Vista-Controlador) y opera de la siguiente manera:

### 🌊 Simulador Dinámico de Hardware

Dado que en esta fase no evaluamos el hardware físico (ESP32 + YF-S201), la pantalla principal ("Panel de Control") cuenta con un selector de inyección de datos con 3 estados:

- **Normal:** Simula un caudal aleatorio bajo (0.1 a 0.5 L/min). La animación muestra agua calmada en nivel bajo.
- **Anomalía:** Simula un flujo irregular (1.2 a 2.5 L/min). El agua sube a nivel medio y cambia a color advertencia.
- **Fuga:** Simula una tubería rota (6.0 a 9.0 L/min). El agua sube al máximo nivel, se agita rápidamente y la interfaz se torna roja (Crítica).

### 🤖 Inteligencia Artificial (Groq API)

Al presionar el botón "Evaluar con Inteligencia Artificial":

1. El controlador captura el estado exacto del agua en ese milisegundo.
2. Empaqueta el dato en un Payload estructurado y lo envía asíncronamente a la API de Groq usando el modelo avanzado `llama-3.3-70b-versatile`.
3. La IA analiza el caudal, genera un veredicto estructurado en formato JSON puro y la aplicación actualiza la interfaz sin bloquearse.

### 🗄️ Persistencia Local (Sqflite)

Cada vez que la IA devuelve un veredicto exitoso, el resultado se guarda automáticamente en una base de datos local SQLite (`edgeleak_history.db`). Puedes ver este registro histórico presionando el ícono de Reloj/Historial en la esquina superior derecha del Panel de Control.

---

## 📂 Estructura de Carpetas (lib/)

- `/config`: Temas globales y manejo de rutas.
- `/controllers`: Lógica de negocio y manejo de estado de la simulación.
- `/data`: Modelos de datos, comunicación con la API de Groq y base de datos Sqflite.
- `/view`: Pantallas (Dashboard, Historial) y Widgets personalizados (como la animación matemática de olas de agua).

---