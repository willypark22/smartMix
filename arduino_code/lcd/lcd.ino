#include "Menus.h"
#include <EEPROM.h>
#include <Wire.h>
#include <string.h>

byte arrowCursor[8] = {
  // custom charactor for the cursor
  B00010,
  B00110,
  B01110,
  B11110,
  B01110,
  B00110,
  B00010,
  B00000
};

byte upArrow[8] = {
  B00000,
  B00100,
  B01110,
  B11111,
  B01110,
  B01110,
  B00000,
  B00000
};

byte downArrow[8] = {
  B00000,
  B00000,
  B01110,
  B01110,
  B11111,
  B01110,
  B00100,
  B00000
};


int outgoingByte;
void setup() {
  // put your setup code here, to run once:
  lcd.createChar(0, arrowCursor);
  lcd.createChar(1, upArrow);
  lcd.createChar(2, downArrow);
  lcd.begin(16, 2);
  lcd.write(byte(0));
  lcd.write(byte(1));
  lcd.write(byte(2));
  pinMode(6,INPUT);
  Serial.begin(9600); // opens serial port with data rate at 9600 bps

  //Master Sender
  Wire.begin(); // join i2c bus (address optional for master)

}

//For sending data to slave Arduino
//char x[] = "123";

// Macros: indicate joystick position
#define NONE 0
#define UP   1
#define DWN  2

// gets y axis input from joystick (analog)
// (get x axis later?)
int getYinput();

// sets position of cursor using joystick input
// to either top (0) or bottom (1)
void Tick_CursorPos();
char cursorPos = 0;

// navigates menu options
enum M_States {M_init, main, choose, create, presets, customs, pourStore, confirmDrink, store, noStoreMenu, storeConfirm, yesDrink, noCustom} M_State;
void Tick_Menu();

// increment and decrement a value (int value) with joystick (used for menu navigation)
enum ID_States {idle, increment, waitRelease, decrement} ID_State;
void Tick_IncDec();
int value = 0;

char data[3]; // data to second
// first,second,third temporarily hold value to put into data string
int first = 0;
int second = 0;
int third = 0;

// variables for EEPROM write/read
int addr = 0; // address to write to EEPROM
// three next values store three drink volume values 
byte valueRead;
byte valueRead2;
byte valueRead3;
byte num;
int address = 0; // address to read from EEPROM

//boolean flag for eeprom access
bool stored = false;

// track if button high, low, being held down
enum Button_States {low, high, wait} Button_State;
void Tick_Button();
char buttonPress = 0;
char buttonHold = 0;

// prints cursor to LCD screen using cursor pos
void cursor() {
  // cursor at top/bottom at col 13 of LCD
  lcd.setCursor(13,0);
  if (!cursorPos) // cursor pos is at top row
    lcd.write(byte(0));
  else            
    lcd.print(" ");
  lcd.setCursor(13,1);
  if (!cursorPos)
    lcd.print(" ");
  else
    lcd.write(byte(0)); // cursor pos is at bottom row
  // hard to read...
}

void upDownArrow() {
  //up arrow
  lcd.setCursor(15,0);
  lcd.write(byte(1));
  
  //down arrow
  lcd.setCursor(15,1);
  lcd.write(byte(2));
}
// preset (hard coded) drinks
char presetDrinks[4][3] = {
  {'1', '2', '3'},
  {'4', '5', '6'},
  {'7', '8', '9'},
  {'6', '5', '4'}
};

void loop() {
    // read button press from pin6
      
    buttonPress = digitalRead(6);

    delay(1); // 1 millisecond period

    // the main state machine
    Tick_Menu();

    // state machines used by Tick_Menu()
    Tick_IncDec();
    Tick_CursorPos();
    Tick_Button();
}

/* inputs: gets joystick up/down input position
 * return: the updated value of char value
 * bahave: int value is used by Tick_Menu SM when creating drink and to choose drink
 *         ensures value only increments once while up position is being held
 */
void Tick_IncDec() {
    // transitions
    switch (ID_State) {
        case idle:
            if (getYinput() == UP) {
                ID_State = increment;
            }
            else if (getYinput() == DWN) {
                ID_State = decrement;
            }
            else {
                ID_State = idle;
            }
            break;
        case increment:
            ID_State = waitRelease;
            break;
        case decrement:
            ID_State = waitRelease;
            break;
        case waitRelease:
            if (getYinput()) {
                ID_State = waitRelease;
            }
            else {
                ID_State = idle;
            }
            break;
        default:
            ID_State = idle;
            break;
    }
    // actions
    switch (ID_State) {
        case increment:
            ++value;
            break;
        case decrement:
            --value;
            break;
        default:
            break;
    }
}

/* inputs: using "value" from Tick_IncDec()
 *         using "cursorPos" from Tick_CursorPos()
 *         using "buttonHold" from Tick_Button() to see if button being held
 * return: prints current menu screen from Menus.h (most LCD writing done here)
 */
void Tick_Menu() {
  static int drindex = 0; // current drink being customized (requesting volume of)
  static int storeCounter = 0; // counts after drink storing confirmed
  static int yesDrinkCounter = 0; // counts after pour drink confirmed
  static int noCustomCounter = 0; // counts seconds for the no custom drink menu
  static int numStoredDrinks = 0;
  switch (M_State) { // begin transitions
    case M_init:
      M_State = main;
      mainMenu();
      break;
    case main:
     stored = false;
      // uses input from Tick_CursorPos
      if (cursorPos && !buttonHold && buttonPress) { //create state
        M_State = create;
        drindex = 0;
        createMenu(drindex, 0);
      }
      else if (!cursorPos && !buttonHold && buttonPress)  { //select state
        M_State = choose;
        chooseMenu();
      }
      else {
        M_State = main;
      }
      break;
    case choose:
      // uses input from Tick_CursorPos
      if (cursorPos && !buttonHold && buttonPress) { //custom drinks state
        drindex = 0;
        M_State = customs;
      }
      else if (!cursorPos && !buttonHold && buttonPress)  { //preset drinks state
        drindex = 0;
        M_State = presets;
        value = 1;
       stored = false;
        choosePresetMenu(1, presetDrinks[0]);
      }
      else {
        M_State = choose;
      }
      break;
    case presets:
      if (!buttonHold && buttonPress) {
        M_State = confirmDrink;
        //storing preset drinks in char data[]
        first = presetDrinks[drindex - 1][0] - '0';
        second = presetDrinks[drindex - 1][1] - '0';
        third = presetDrinks[drindex - 1][2] - '0';
       stored = false;
        confirmDrinkMenu();
      }
      else {
        M_State = presets;
      }
      break;
    case customs:
      //if we want to store even when arduino is off
//      num = EEPROM.read(100);
      if (numStoredDrinks == 0) {
        M_State = noStoreMenu;
        noCustomSaved(); 
      }
      else if (!buttonHold && buttonPress) {
        M_State = confirmDrink;
//        stored = true;
        confirmDrinkMenu();
      }
      else {
        M_State = customs;
      }
      break;
    case create:
      if (drindex < 4) { //once 3 drinks are done
          M_State = create;
      }
      else {
          M_State = pourStore;
          pourStoreMenu();
      }
      break;
    case pourStore:
      if (cursorPos && !buttonHold && buttonPress) {
        M_State = storeConfirm;
        storeConfirmMenu();
      }
      else if (!cursorPos && !buttonHold && buttonPress) {
        M_State = confirmDrink;
        confirmDrinkMenu();
      }
      else {
        M_State = pourStore;
      }
      break;
    case confirmDrink:
      if (!cursorPos && !buttonHold && buttonPress) {
        M_State = yesDrink;
//        sends data when user confirms drink
        
        pouringDrinkYesMenu();
      }
      else if (cursorPos && !buttonHold && buttonPress) {
        M_State = main;
        mainMenu();
      }
      else {
        M_State = confirmDrink;
      }
      break;
    case store:
      if (storeCounter < 1500) {
        M_State = store;
      }
      else {
        storeCounter = 0;
        M_State = main;
        mainMenu();
      }
      break;
    case storeConfirm:
      if (!cursorPos && !buttonHold && buttonPress) {
        M_State = store;
        //store drink to EEPROM
        EEPROM.write(addr, first);
        addr = addr + 1;
        EEPROM.write(addr, second);
        addr = addr + 1;
        EEPROM.write(addr, third);
        addr = addr + 1;
        //if we want to store even when arduino is off
        //EEPROM.update(101, addr);
        if (addr == EEPROM.length()) {
          addr = 0;
        }
        ++numStoredDrinks;
        //if we want to store even when arduino is off
//        EEPROM.update(100, numStoredDrinks);
        storeDrinkYesMenu();
      }
      else if (cursorPos && !buttonHold && buttonPress) {
        M_State = main;
        mainMenu();
      }
      else {
        M_State = storeConfirm;
      }
      break;
    case yesDrink:
      if (yesDrinkCounter < 1500) {
       if (stored) {
         data[0] = valueRead + '0';
         data[1] = valueRead2 + '0';
         data[2] = valueRead3 + '0';
       }
      else {
          data[0] = first + '0';
          data[1] = second + '0';
          data[2] = third + '0';
      }
        
        M_State = yesDrink;
      }
      else {
        Wire.beginTransmission(4500); // transmit to device #9
        Wire.write(data);              // sends one byte
        Wire.endTransmission();    // stop transmitting
        yesDrinkCounter = 0;
        M_State = main;
        mainMenu();
      }
      break;
    case noStoreMenu:
      if (noCustomCounter < 1500) {
        M_State = noStoreMenu;
      }
      else {
        noCustomCounter = 0;
        M_State = main;
        mainMenu();
      }
      break;
    default:
      M_State = M_init;
      break;
  } // end transitions

  switch (M_State) { // begin actions
    case main:
      cursor(); // print cursor to LCD
      // either chooses drink (top position) or create drink (bottom)
      break;
    case choose:
      cursor(); // print cursor to LCD
      // either choose from custom drinks or from preset drinks
      break;
    case presets:
      // range of value limited to the three preset drinks
      value = (value > 4) ? 1 : value;
      value = (value <= 0) ? 4 : value;
      drindex = value;

      choosePresetMenu(drindex, presetDrinks[drindex - 1]);
      break;
    case customs:
      // range of value limited to number of stored drinks
      stored = true;
      value = (value >= numStoredDrinks) ? 0 : value;
      value = (value < 0) ? numStoredDrinks : value;
      drindex = value;
      drindex *= 3;
      // get drink from EEPROM
      // 012, 345, 678 ...
      valueRead  = EEPROM.read(drindex+0);
      valueRead2 = EEPROM.read(drindex+1);
      valueRead3 = EEPROM.read(drindex+2);
//      Serial.print(valueRead, DEC);
//      Serial.print(valueRead2, DEC);
//      Serial.print(valueRead3, DEC);
      chooseCustomMenu(value + 1, valueRead, valueRead2, valueRead3);
      if (numStoredDrinks > 1) {
        upDownArrow();
      }
      
      break;
    case create:
      if (!buttonHold && buttonPress) {
          ++drindex;
          value = 0;
      }
      if (value >= 9) {
        value = 9;
      }
      else if (value <= 0) {
        value = 0;
      }
      //storing drinks into first, second, third
      if (drindex == 1) {
        first = value;
      }
      else if (drindex == 2) {
        second = value;
      }
      else if (drindex == 3) {
        third = value;
      }
      //add if statements to store the value of what the user specified
      createMenu(drindex, value);
      break;
    case pourStore:
      cursor();
      break;
    case confirmDrink:
      cursor();
      break;
    case store:
      // display this screen for 3 seconds
      ++storeCounter;
      break;
    case storeConfirm:
      cursor();
      break;
    case yesDrink:
      // display this screen for 5 seconds
      ++yesDrinkCounter;
      break;
    case noStoreMenu:
      ++noCustomCounter;
      break;
    default:
      break;
  }
}

/* inputs: analog input from A1
 * return: immediate joystick position: up, down, or none (center position)
 */
int getYinput() {
  if (analogRead(A1) > 550) {
    return UP;
  }
  else if ( analogRead(A1) < 450) {
    return DWN;
  }
  else {
    return 0;
  }
}
/* inputs: joystick position input
 * return: store the cursor position
 */
void Tick_CursorPos() {
    if (getYinput() == UP) 
        cursorPos = 0;
    else if (getYinput() == DWN)
        cursorPos = 1;
}

void Tick_Button() {
   switch (Button_State) { //Transitions
        case low:
            if (buttonPress) {
              Button_State = high;
            }
            else {
              Button_State = low;
            }
            break;
        case high:
            Button_State = wait;
            break;
        case wait:
            if (buttonPress) {
              Button_State = wait;
            }
            else {
              Button_State = low;
            }
            break;
        default:
            Button_State = low;
            break;
    }
    switch (Button_State) { //Actions
        case low:
            buttonHold = 0; //not holding
            break;
        case high:
            buttonHold = 1; //holding
            break;
        case wait:
            break;
        default:
            break;
    }
}
