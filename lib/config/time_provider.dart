/// Función que retorna la fecha/hora actual.
///
/// Inyectable en constructores para habilitar el time-travelling en tests
/// sin depender directamente de [DateTime.now].
typedef TimeProvider = DateTime Function();
