# ufo

Ultra-low Frequency Oscillator

This is a script for the Monome Norns that uses the International Space Station as a low-frequency oscillator, with a period of about 90 minutes.

The ISS orbits Earth every 90 minutes or so, and so if you track its latitude and longitude then you'll get a sine wave for the former, and a ramp wave for the latter.

The script grabs data from the [Where The ISS At? API](https://wheretheiss.at/), and maps the resulting data to a pair of voltages that it spits out through the Crow module, which connects to Norns over USB. You can then send those voltages wherever you want.

Crow
-> out 1&2: latitude (-5-5V)
-> out 3&4: longitude (0-10V)

Requires an internet connection.
