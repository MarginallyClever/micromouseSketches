// read four analog distance sensors and send the values to serial.
// Dan Royer (dan@marginallyclever.com)
// 2016-05-14

void setup() {
  // put your setup code here, to run once:
  Serial.begin(57600);
}


void loop() {
  // put your main code here, to run repeatedly:
  Serial.print(analogRead(2));  Serial.print("\t");
  Serial.print(analogRead(3));  Serial.print("\t");
  Serial.print(analogRead(4));  Serial.print("\t");
  Serial.print(analogRead(5));  Serial.print("\n");
  delay(5);
}
