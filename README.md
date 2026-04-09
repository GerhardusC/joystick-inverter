# Joystick Inverter for PortMaster on ArkOS

## Setup

1. Clone the repository down, or download it as a zip folder.
2. Add the `inverter/` directory and `inverter.sh` scripts to the `tools` directory

E.G.
```bash
git clone https://github.com/GerhardusC/joystick-inverter.git
cd joystick-inverter && cp -a inverter/ inverter.sh /roms/tools/
```

In other words, just add `inverter/` and `inverter.sh` to `EASYROMS/tools` on the SD card

## Usage

In the ArkOS emulationstation main menu, selection `Options` -> `tools` -> `inverter`,
and you will be presented with a list of options to interact with the joystick mappings.

### ACTIONS:
- `BOTH:    SWAP`         --> Swaps the left analog stick with the right one
- `BOTH:    SWAP BTNS`    --> Swaps the buttons when the analog sticks are pressed in
- `LEFT:    ROTATE`       --> Corrects X-Y inversion of left analog stick
- `RIGHT:   ROTATE`       --> Corrects X-Y inversion of right analog stick
- `LEFT_X:  INVERT`       --> Inverts the left analog X axis direction
- `LEFT_Y:  INVERT`       --> Inverts the left analog Y axis direction
- `RIGHT_X: INVERT`       --> Inverts the right analog X axis direction
- `RIGHT_Y: INVERT`       --> Inverts the right analog Y axis direction

### REMEMBER TO SAVE:
`SAVE AND EXIT`         --> Writes the changes to `/roms/tools/PortMaster/gamecontrollerdb.txt`

## Manual usage (no device needed)
You can run the perl script in `./inverter/inverter.pl` with the paths to `es_input.cfg` and `gamecontrollerdb.txt` if you want.

e.g.
```bash
perl inverter/inverter.pl /path/to/es_input.cfg /path/to/gamecontroller.txt
```
