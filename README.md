# ufo

Ultra-low Frequency Oscillator

This is a script for the Monome Norns that uses the International Space Station (ISS) as a low-frequency oscillator, with a period of about 90 minutes. It grabs data from the [Where The ISS At? API](https://wheretheiss.at/), and maps the location of the ISS over the Earth to sound.

The ISS orbits Earth every 90 minutes or so, and so if you track its latitude and longitude then you'll get a sine wave for the former, and a ramp wave for the latter.

The script generates a internal supersaw (ISS) drone composed by [Jonathan Synder](https://llllllll.co/u/jaseknighter/). The latitude of the ISS is mapped to filter cutoff and modulation depth. The longitude is mapped to reverb absorption. Finally, the detune parameter of the supersaw is mapped to the distance between the ISS and the location specified in the `localLat` and `localLon` parameters at the top of the `ufo.lua` file, which you should replace with your own latitude and longitude coordinates to personalise the script.

Additionally, the script generates a trio of voltages that it spits out through the Crow module, which connects to Norns over USB. You can then send those voltages wherever you want in your Eurorack system to modulate your patches with rocket science.

## Crow

- out 1: latitude (-5-5V)
- out 2: longitude (0-10V)
- out 3: distance from your position to ISS (0-10V) - only if enabled in script

Requires an internet connection.

## Changelog

### v1.0

Initial release
