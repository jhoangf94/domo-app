#include <Servo.h>

// PIN ASSIGNMENTS TO AVOID TIMER CONFLICTS (Servo uses Timer 1, which affects pins 9 and 10)

// LEDs (PWM PINS)
// We use pins controlled by Timer 0 (pins 5, 6) or Timer 2 (pin 3, 11)
const int pinLedL1 = 5;   // PWM Pin (L1: Sala de Estar) - MOVIDO DEL PIN 9 AL PIN 5
const int pinLedL2 = 6;   // PWM Pin (L2: Cocina) - MOVIDO DEL PIN 10 AL PIN 6
const int pinLedL3 = 11;  // PWM Pin (L3: Dormitorio Principal)
const int pinLedL4 = 3;   // PWM Pin (L4: Baño)

// SERVO PIN (Non-PWM is fine, but 4 is used for signal)
const int pinServomotor = 4; 

// BLUETOOTH HC-05 (Software Serial)
// Using pins 7 and 8 to avoid conflicts with timers and PWM
const int pinBluetoothRx = 7; // RX (Recibe datos del TX del HC-05)
const int pinBluetoothTx = 8; // TX (Transmite datos al RX del HC-05)

// Create Servo object
Servo puertaServo;

// Software Serial library (required for pins 7 and 8)
#include <SoftwareSerial.h>
SoftwareSerial BTSerial(pinBluetoothRx, pinBluetoothTx); // RX, TX

// Buffer to store the incoming command (e.g., "L1:255")
String commandString = "";

void setup() {
  // Setup serial communication with the PC (for debug)
  Serial.begin(9600);
  Serial.println("System Ready. Waiting for BT connection...");

  // Setup serial communication with the Bluetooth module
  // Note: Standard baud rate for HC-05 is 9600
  BTSerial.begin(9600);

  // Initialize LED pins as outputs
  pinMode(pinLedL1, OUTPUT);
  pinMode(pinLedL2, OUTPUT);
  pinMode(pinLedL3, OUTPUT);
  pinMode(pinLedL4, OUTPUT);

  // Attach the servo to the signal pin
  puertaServo.attach(pinServomotor);
  // Initial position (closed)
  puertaServo.write(170);
}

void loop() {
  // 1. Read incoming data from Bluetooth
  while (BTSerial.available()) {
    char incomingChar = BTSerial.read();

    // End of a command is when the newline character '\n' is received
    if (incomingChar == '\n') {
      // Process the complete command
      processCommand(commandString);
      // Clear the buffer for the next command
      commandString = "";
    } else if (incomingChar != '\r') {
      // Ignore carriage return '\r' and append the rest to the buffer
      commandString += incomingChar;
    }
  }

  // Small delay to allow the loop to repeat
  delay(20); 
}

// Function to parse and execute the command
void processCommand(String command) {
  // Convert command to uppercase to simplify parsing
  command.toUpperCase();

  // Find the separator (:) to split the command and value
  int separatorIndex = command.indexOf(':');

  if (separatorIndex == -1) {
    Serial.println("Invalid command: " + command);
    return;
  }

  // Extract the identifier (L1, L2, L3, L4, P)
  String target = command.substring(0, separatorIndex);
  
  // Extract the value (0 to 255 for LEDs, 0 to 180 for Servo)
  String valueString = command.substring(separatorIndex + 1);
  int value = valueString.toInt();

  // --- Control Logic ---
  if (target == "L1") {
    // PWM on Pin 5 (Timer 0)
    analogWrite(pinLedL1, value); 
  } else if (target == "L2") {
    // PWM on Pin 6 (Timer 0)
    analogWrite(pinLedL2, value);
  } else if (target == "L3") {
    // PWM on Pin 11 (Timer 2)
    analogWrite(pinLedL3, value);
  } else if (target == "L4") {
    // PWM on Pin 3 (Timer 2)
    analogWrite(pinLedL4, value); 
  } else if (target == "P") {
    // Move the servo
    // The value should be between 0 and 180
    puertaServo.write(value);
  }

  // Optional: print processed command to the serial monitor
  Serial.print("Command OK: ");
  Serial.print(target);
  Serial.print(" = ");
  Serial.println(value);
}