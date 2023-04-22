# Monocle FPGA

**The pre-built binary and project file is available on the [releases page](https://github.com/brilliantlabsAR/monocle-fpga/releases).**

If you're using the Brilliant REPL, the FPGA update should be automatically suggested.

## Building manually

This repository contains a [StreamLogic](https://streamlogic.io) generated project designed to run on the Monocle hardware. It can be built using the GoWin EDA, and SteamLogic command line utility.

If you want to customize your own version, try it out on SteamLogic [here](https://fpga.streamlogic.io/monocle/).

### Steps:

- Download and install the [GoWin EDA](https://www.gowinsemi.com/en/support/home/).

- Apply for a free (standard edition) licence from the GoWin website. 

- Install the StreamLogic command line utility:

  ```python
  pip install sxlogic
  ```

- Build the project:

  ```sh
  python -m sxlogic.monocle build monocle-fpga.tgz
  ```

- The final `.bin` file can be found inside the folder `monocle-fpga-build/hw/impl/pnr/`

- Upload the file to your Monocle using the [Brilliant WebREPL](https://repl.brilliant.xyz/).

---

If you're looking to build a totally custom FPGA application. Check out the [`old-rtl`](https://github.com/brilliantlabsAR/monocle-fpga/tree/old-rtl) branch.