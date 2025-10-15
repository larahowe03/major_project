EESchema Schematic File Version 3
LIBS:power
LIBS:device
LIBS:transistors
LIBS:conn
LIBS:linear
LIBS:regul
LIBS:74xx
LIBS:cmos4000
LIBS:adc-dac
LIBS:memory
LIBS:xilinx
LIBS:microcontrollers
LIBS:dsp
LIBS:microchip
LIBS:analog_switches
LIBS:motorola
LIBS:texas
LIBS:intel
LIBS:audio
LIBS:interface
LIBS:digital-audio
LIBS:philips
LIBS:display
LIBS:cypress
LIBS:siliconi
LIBS:opto
LIBS:atmel
LIBS:contrib
LIBS:valves
LIBS:camera_side_breakout-cache
EELAYER 26 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 1 1
Title ""
Date ""
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L CONN_02X09 P101
U 1 1 58102111
P 3350 2400
F 0 "P101" H 3350 2900 50  0000 C CNN
F 1 "CONN_02X09" V 3350 2400 50  0000 C CNN
F 2 "Pin_Headers:Pin_Header_Straight_2x09" H 3350 1200 50  0001 C CNN
F 3 "" H 3350 1200 50  0000 C CNN
	1    3350 2400
	1    0    0    -1  
$EndComp
$Comp
L CONN_02X10 P102
U 1 1 581021B7
P 3450 4250
F 0 "P102" H 3450 4800 50  0000 C CNN
F 1 "CONN_02X10" V 3450 4250 50  0000 C CNN
F 2 "Pin_Headers:Pin_Header_Straight_2x10" H 3450 3050 50  0001 C CNN
F 3 "" H 3450 3050 50  0000 C CNN
	1    3450 4250
	1    0    0    -1  
$EndComp
Text Notes 2900 3200 0    60   ~ 0
Camera Side, Inverted Mounting
Wire Wire Line
	3100 2000 3000 2000
Wire Wire Line
	3100 2100 3000 2100
Wire Wire Line
	3100 2200 3000 2200
Wire Wire Line
	3100 2300 3000 2300
Wire Wire Line
	3100 2400 3000 2400
Wire Wire Line
	3100 2500 3000 2500
Wire Wire Line
	3100 2600 3000 2600
Wire Wire Line
	3100 2700 3000 2700
Wire Wire Line
	3100 2800 3000 2800
Wire Wire Line
	3600 2000 3700 2000
Wire Wire Line
	3600 2100 3700 2100
Wire Wire Line
	3600 2200 3700 2200
Wire Wire Line
	3600 2300 3700 2300
Wire Wire Line
	3600 2400 3700 2400
Wire Wire Line
	3600 2500 3700 2500
Wire Wire Line
	3600 2600 3700 2600
Wire Wire Line
	3600 2700 3700 2700
Wire Wire Line
	3600 2800 3700 2800
Text Label 3000 2000 2    60   ~ 0
RESET
Text Label 3700 2000 0    60   ~ 0
PWDN
Text Label 3000 2100 2    60   ~ 0
D1
Text Label 3700 2100 0    60   ~ 0
D0
Text Label 3000 2200 2    60   ~ 0
D3
Text Label 3700 2200 0    60   ~ 0
D2
Text Label 3000 2300 2    60   ~ 0
D5
Text Label 3700 2300 0    60   ~ 0
D4
Text Label 3000 2400 2    60   ~ 0
D7
Text Label 3700 2400 0    60   ~ 0
D6
Text Label 3000 2500 2    60   ~ 0
PCLK
Text Label 3700 2500 0    60   ~ 0
XCLK
Text Label 3000 2600 2    60   ~ 0
VSYNC
Text Label 3700 2600 0    60   ~ 0
HREF
Text Label 3000 2700 2    60   ~ 0
SIOC
Text Label 3700 2700 0    60   ~ 0
SIOD
Text Label 3000 2800 2    60   ~ 0
3V3
Text Label 3700 2800 0    60   ~ 0
GND
Wire Wire Line
	3200 3800 3100 3800
Wire Wire Line
	3700 3800 3800 3800
Wire Wire Line
	3200 3900 3100 3900
Wire Wire Line
	3200 4000 3100 4000
Wire Wire Line
	3200 4100 3100 4100
Wire Wire Line
	3200 4200 3100 4200
Wire Wire Line
	3200 4300 3100 4300
Wire Wire Line
	3200 4400 3100 4400
Wire Wire Line
	3200 4500 3100 4500
Wire Wire Line
	3200 4600 3100 4600
Wire Wire Line
	3200 4700 3100 4700
Wire Wire Line
	3700 3900 3800 3900
Wire Wire Line
	3700 4000 3800 4000
Wire Wire Line
	3700 4100 3800 4100
Wire Wire Line
	3700 4200 3800 4200
Wire Wire Line
	3700 4300 3800 4300
Wire Wire Line
	3700 4400 3800 4400
Wire Wire Line
	3700 4500 3800 4500
Wire Wire Line
	3700 4600 3800 4600
Wire Wire Line
	3700 4700 3800 4700
Text Label 3100 3800 2    60   ~ 0
GND
Text Label 3800 3800 0    60   ~ 0
GND
Text Label 3800 4700 0    60   ~ 0
GND
Text Label 3100 4700 2    60   ~ 0
3V3
Text Label 3100 3900 2    60   ~ 0
RESET
Text Label 3100 4000 2    60   ~ 0
D1
Text Label 3100 4100 2    60   ~ 0
D3
Text Label 3100 4200 2    60   ~ 0
D5
Text Label 3100 4300 2    60   ~ 0
D7
Text Label 3100 4400 2    60   ~ 0
PCLK
Text Label 3100 4500 2    60   ~ 0
VSYNC
Text Label 3100 4600 2    60   ~ 0
SIOC
Text Label 3800 3900 0    60   ~ 0
PWDN
Text Label 3800 4000 0    60   ~ 0
D0
Text Label 3800 4100 0    60   ~ 0
D2
Text Label 3800 4200 0    60   ~ 0
D4
Text Label 3800 4300 0    60   ~ 0
D6
Text Label 3800 4400 0    60   ~ 0
XCLK
Text Label 3800 4500 0    60   ~ 0
HREF
Text Label 3800 4600 0    60   ~ 0
SIOD
$Comp
L C C101
U 1 1 59FCB06D
P 4600 2550
F 0 "C101" H 4715 2596 50  0000 L CNN
F 1 "C" H 4715 2505 50  0000 L CNN
F 2 "Capacitors_SMD:C_0805" H 4638 2400 50  0001 C CNN
F 3 "" H 4600 2550 50  0001 C CNN
	1    4600 2550
	1    0    0    -1  
$EndComp
Text Label 4600 2300 2    60   ~ 0
3V3
Text Label 4600 2800 0    60   ~ 0
GND
Wire Wire Line
	4600 2300 4600 2400
Wire Wire Line
	4600 2700 4600 2800
$EndSCHEMATC
