# Bench_Automation

## lab_tools

`lab_tools` is a MATLAB class for communicating with bench equipment such as function generators and oscilloscopes over serial and VISA interfaces. It is designed to streamline lab automation and measurement tasks in engineering and prototyping environments.

## Features

- Auto-detects connected function generators and oscilloscopes
- Supports multiple waveform types and SCPI-compatible commands
- Reads and writes parameters such as frequency, amplitude, and waveform type
- Controls oscilloscope autoset, calibration, averaging, and x-scale
- Captures screenshots from supported scopes and saves them as `.gif`
- Built-in device error checking and reset functionality

## Supported Equipment

### Function Generators

- **AFG-2225**
  - Supported waveforms: `"SIN"`, `"RAMP"`, `"SQU"`
- **Instek Function Generators**
  - Supported waveforms: `"SIN"`, `"TRI"`, `"SQR"`

### Oscilloscopes

- Tested with **Rohde & Schwarz** models
- Other SCPI-compatible scopes may work
- Supported auto-measurement types include:
  - `FREQ`, `PER`, `AMPL`, `MEAN`, `RMS`, `PHAS`, `HIGH`, `LOW`, etc.
- Supported average counts: 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024

## Example Scripts

Example usage scripts are provided in the `scripts/` directory. These scripts demonstrate how to configure instruments, perform measurements, and save data.

## Authors

- Sahaj Singh: [@SatireSage](https://github.com/SatireSage)
- Bryce Leung: [@Bryce-Leung](https://github.com/Bryce-Leung)

## License

This project is licensed under the MIT License.

