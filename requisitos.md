Prompt para Generación de Aplicación Flutter (Control Domótico BT)
Instrucción: Genera una aplicación Flutter completa y en un solo archivo (main.dart) para controlar luces dimmeables y un servomotor (puerta) a través de un módulo Bluetooth (HC-05/06), siguiendo el protocolo de comunicación serial definido.
1. Estilo y Diseño (Aesthetic)
 * Tema: Dark Mode (Modo Oscuro) por defecto.
  * Diseño: Moderno, minimalista y orientado a móvil (primero mobile-first).
   * Componentes: Utiliza Card o contenedores con borderRadius para agrupar los controles de cada habitación.
    * Iconografía: Uso de íconos lucide_icons o material_icons claros (bombillas, cerraduras, Bluetooth).
     * Acento: Utiliza un color primario vibrante (ej. verde esmeralda o azul cian) para indicar el estado activo/conectado/encendido.
     2. Estructura de la Interfaz (Widgets)
     La pantalla debe ser un Scaffold único con la siguiente distribución:
      * App Bar: Título (Control Domótico BT) y un ícono para el estado de la conexión Bluetooth (rojo si desconectado, verde si conectado).
       * Sección de Conectividad (Parte Superior):
          * Un botón principal para Buscar Dispositivos / Conectar.
             * Un Text o indicador que muestre el estado actual de la conexión (ej., "Desconectado", "Conectando...", "Conectado a HC-05").
              * Controles de Iluminación (Grid o Column): Cuatro bloques de control idénticos y claros, uno para cada habitación: Sala de Estar (L1), Cocina (L2), Dormitorio Principal (L3), y Baño (L4).
                 * Contenido de cada bloque:
                      * Nombre de la habitación.
                           * Switch o Toggle grande para Encendido/Apagado.
                                * Slider para controlar la Intensidad (0% a 100%).
                                 * Control de Puerta (Parte Inferior):
                                    * Un ElevatedButton con el texto "ABRIR PUERTA" (posición 180).
                                       * Un ElevatedButton con el texto "CERRAR PUERTA" (posición 0).
                                       3. Requisitos Técnicos y Protocolo de Comunicación
                                       A. Dependencias
                                       La aplicación debe utilizar una biblioteca estándar y bien mantenida para la comunicación serial Bluetooth (ej. flutter_bluetooth_serial, o la que la IA considere más estable para comunicación de bajo nivel).
                                       B. Protocolo de Comando (CRÍTICO)
                                       La aplicación DEBE enviar comandos al Arduino con el formato [Etiqueta]:[Valor]\n, donde \n (salto de línea) es el carácter de terminación.
                                       | Funcionalidad | Etiqueta | Rango de Valor | Conversión | Ejemplo de Comando Enviado |
                                       |---|---|---|---|---|
                                       | Luz 1 (Sala) | L1 | 0 a 255 | % (0-100) \rightarrow PWM (0-255) | L1:150\n (59% aprox.) |
                                       | Luz 2 (Cocina) | L2 | 0 a 255 | % (0-100) \rightarrow PWM (0-255) | L2:255\n (100%) |
                                       | Luz 3 (Dormitorio) | L3 | 0 a 255 | % (0-100) \rightarrow PWM (0-255) | L3:0\n (Apagado) |
                                       | Luz 4 (Baño) | L4 | 0 a 255 | % (0-100) \rightarrow PWM (0-255) | L4:80\n |
                                       | Puerta (Cerrar) | P | 0 | Ángulo | P:0\n |
                                       | Puerta (Abrir) | P | 180 | Ángulo | P:180\n |
                                       Nota sobre la Intensidad: El slider en la UI debe ser de 0 a 100 (porcentaje). El código Flutter debe tomar ese porcentaje P y convertirlo a un valor PWM \mathbf{V = round(P \times 2.55)} antes de enviarlo por Bluetooth.
                                       4. Requisito de Archivo
                                       El código debe ser único y estar en un archivo llamado main.dart, conteniendo la inicialización y el widget principal del UI.
                                       u