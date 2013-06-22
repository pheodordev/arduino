#include <IRremote.h>

#define IR_PIN 4
#define SPEAKER_PIN 5
#define PHOTORES_PIN A0
#define LEFT_BLIND_OPEN_PIN A1
#define LEFT_BLIND_CLOSE_PIN A2
#define RIGHT_BLIND_OPEN_PIN A3
#define RIGHT_BLIND_CLOSE_PIN A4

#define POWER_BTN 16753245
#define CLOSE_BTN 16754775
#define OPEN_BTN 16748655
#define LEFT_BTN 16712445
#define RIGHT_BTN 16761405
#define STOP_BTN 16769055

#define MOTOR_LEFT_EN_PIN 12
#define MOTOR_RIGHT_EN_PIN 11
#define MOTOR_LEFT_1_PIN 10
#define MOTOR_LEFT_2_PIN 9
#define MOTOR_RIGHT_1_PIN 8
#define MOTOR_RIGHT_2_PIN 7

// ID штор
#define ALL_BLINDS 0
#define LEFT_BLIND 1
#define RIGHT_BLIND 2

// ID действий
#define OPEN 1
#define CLOSE -1


// Звуки включения/выключения авто режима
int AUTO_ON_MELODY[] = {900, 370, 1700, 1870};
int AUTO_OFF_MELODY[] = {710, 450, 1410, 1410};

// Лимиты освещения после которых происходит закрытие/открытие
int LIGHT_OPEN_LIMIT = 220;
int LIGHT_CLOSE_LIMIT = 170;

// Время рагирования на изменение освещения
int LIGHT_DETECT_TIME = 180000; // 3 минуты

// Время ожидания в одиночном режиме
int ONLY_TIME_LIMIT = 3000;

// Время включения одиночного режима
unsigned long onlyLeftTime = 0;
unsigned long onlyRightTime = 0;

// Включено/выключено автоматическое открытие/закрытие
boolean autoOn = true;

// Время первого обнаружения нужной освещенности
unsigned long lightDetectedTime = 0;

// Состояние штор (-1 закрыты, 0, 1 открыты)
int leftBlindStatus = 0;
int rightBlindStatus = 0;

// Срабатывала ли сегодня автоматика
boolean todayOpened = false;
boolean todayClosed = false;

IRrecv irrecv(IR_PIN);
decode_results results;

void setup() {
  pinMode(LEFT_BLIND_OPEN_PIN, INPUT);
  pinMode(LEFT_BLIND_CLOSE_PIN, INPUT);
  pinMode(RIGHT_BLIND_OPEN_PIN, INPUT);
  pinMode(RIGHT_BLIND_CLOSE_PIN, INPUT);
  pinMode(SPEAKER_PIN, OUTPUT);
  pinMode(MOTOR_LEFT_EN_PIN, OUTPUT);
  pinMode(MOTOR_RIGHT_EN_PIN, OUTPUT);
  analogWrite(13, 255);
  statusBlind(LEFT_BLIND, HIGH);
  statusBlind(RIGHT_BLIND, HIGH);
  stopBlind(ALL_BLINDS);
  Serial.begin(9600);
  irrecv.enableIRIn();
}

void loop() {
  long time = millis();
  if(irrecv.decode(&results)) {
    long code = results.value;
    if(code == OPEN_BTN) {
      if(getOnly(LEFT_BLIND)) moveBlind(LEFT_BLIND, OPEN);
      if(getOnly(RIGHT_BLIND)) moveBlind(RIGHT_BLIND, OPEN);
    }
    else if(code == CLOSE_BTN) {
      if(getOnly(LEFT_BLIND)) moveBlind(LEFT_BLIND, CLOSE);
      if(getOnly(RIGHT_BLIND)) moveBlind(RIGHT_BLIND, CLOSE);
    }
    else if(code == STOP_BTN) stopBlind(ALL_BLINDS);
    else if(code == LEFT_BTN) onlyLeftTime = time;
    else if(code == RIGHT_BTN) onlyRightTime = time;
    else if(code == POWER_BTN) {
      if(autoOn) {
        autoOn = false;
        analogWrite(13, 0);
        playSignal(AUTO_OFF_MELODY);
      }
      else {
        autoOn = true;
        analogWrite(13, 255);
        playSignal(AUTO_ON_MELODY);
      }
    }
    Serial.print("CODE: ");
    Serial.println(code);
    irrecv.resume();
  }
  if(autoOn) {
    int light = getLight();
    Serial.print("LIGHT: ");
    Serial.println(light);
    if((light < LIGHT_CLOSE_LIMIT || light > LIGHT_OPEN_LIMIT)) {
      if(lightDetectedTime == 0) lightDetectedTime = time;
    }
    else lightDetectedTime = 0;
    if(lightDetectedTime > 0 && time - lightDetectedTime > LIGHT_DETECT_TIME) {
      lightDetectedTime = 0;
      if(light < LIGHT_CLOSE_LIMIT && todayClosed == false) {
        todayClosed = true;
        todayOpened = false;
        moveBlind(ALL_BLINDS, CLOSE);
      }
      else if(light > LIGHT_OPEN_LIMIT && todayOpened == false) {
        todayClosed = false;
        todayOpened = true;
        moveBlind(ALL_BLINDS, OPEN);
      }
    }
  }
  getBlindsStatus();
}

void playSignal(int melody[]) {
  int beats[] = {2, 14, 16, 4};
  for (int i = 0; i < 4; i++) {
    int mel = melody[i];
    int temp = beats[i];
    long tval = temp * 20000;
    
    long temp_steps = 0;
    while(temp_steps < tval) {
        digitalWrite(SPEAKER_PIN, HIGH);
        delayMicroseconds(mel / 2);
        digitalWrite(SPEAKER_PIN, LOW);
        delayMicroseconds(mel / 2);
        temp_steps += mel;
    }
  }
}

int getLight() {
  int sensorValue = analogRead(PHOTORES_PIN);
  sensorValue = constrain(sensorValue, 100, 1000);
  return sensorValue;
}

int getBlindsStatus() {
  /*
  if(analogRead(LEFT_BLIND_CLOSE_PIN) > 700) {
    leftBlindStatus = CLOSE;
    stopBlind(LEFT_BLIND);
  }
  else if(analogRead(LEFT_BLIND_OPEN_PIN) > 700) {
    leftBlindStatus = OPEN;
    stopBlind(LEFT_BLIND);
  }
  else leftBlindStatus = 0;
  if(analogRead(RIGHT_BLIND_CLOSE_PIN) > 700) {
    rightBlindStatus = CLOSE;
    stopBlind(RIGHT_BLIND);
  }
  else if(analogRead(RIGHT_BLIND_OPEN_PIN) > 700) {
    rightBlindStatus = OPEN;
    stopBlind(RIGHT_BLIND);
  }
  else rightBlindStatus = 0;
  */
}

void moveBlind(int blind, int dir) {
  if(blind == LEFT_BLIND || blind == ALL_BLINDS) {
    if(dir == OPEN && leftBlindStatus != OPEN) {
      analogWrite(MOTOR_LEFT_1_PIN, LOW);
      analogWrite(MOTOR_LEFT_2_PIN, 255);
    }
    else if(dir == CLOSE && leftBlindStatus != CLOSE) {
      analogWrite(MOTOR_LEFT_1_PIN, 255);
      analogWrite(MOTOR_LEFT_2_PIN, LOW);
    }
  }
  if(blind == RIGHT_BLIND || blind == ALL_BLINDS) {
    if(dir == OPEN && rightBlindStatus != OPEN) {
      analogWrite(MOTOR_RIGHT_1_PIN, LOW);
      analogWrite(MOTOR_RIGHT_2_PIN, 255);
    }
    else if(dir == CLOSE && rightBlindStatus != CLOSE) {
      analogWrite(MOTOR_RIGHT_1_PIN, 255);
      analogWrite(MOTOR_RIGHT_2_PIN, LOW);
    }
  }
}

void stopBlind(int blind) {
  if(blind == LEFT_BLIND || blind == ALL_BLINDS) {
    analogWrite(MOTOR_LEFT_1_PIN, LOW);
    analogWrite(MOTOR_LEFT_2_PIN, LOW);
  }
  if(blind == RIGHT_BLIND || blind == ALL_BLINDS) {
    analogWrite(MOTOR_RIGHT_1_PIN, LOW);
    analogWrite(MOTOR_RIGHT_2_PIN, LOW);
  }
}

void statusBlind(int blind, int status) {
  digitalWrite(blind == LEFT_BLIND ? MOTOR_LEFT_EN_PIN : MOTOR_RIGHT_EN_PIN, status);
}

boolean getOnly(int blind) {
  long time = millis();
  long onlyLeft = time - onlyLeftTime;
  long onlyRight = time - onlyRightTime;
  if(blind == LEFT_BLIND && (onlyLeft < ONLY_TIME_LIMIT || onlyRight > ONLY_TIME_LIMIT)) return true;
  else if(blind == RIGHT_BLIND && (onlyRight < ONLY_TIME_LIMIT || onlyLeft > ONLY_TIME_LIMIT)) return true;
  return false;
}
