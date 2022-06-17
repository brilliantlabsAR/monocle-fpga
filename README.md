# Monocle FPGA

The FPGA is synthesized using the GoWin toolchain. In order to synthesize the code, you will need to download the FPGA synthesis and Plae/Route tool from the [GoWin site](https://www.gowinsemi.com/en/support/home/). This requires registration on their site followed by applying for a license.

## FPGA Bitstream Generation and Programmiong Process
Once this is complete, follow the steps below to synthesize the code for the FPGA:
1. Open the synth/fpgas_proj.gprj file under the GoWin GUI.
2. Right click on Synthesis in the Process window and click on 1Synthesize`. This will synthesize your design and prepare it for place and route. Check for any errors, there should be none.
3. Right click on "Place & Route" under the Process window and click on `Run`. This will place and route the FPGA and create a bitstream for programming.
4. Right click on `Program Device` in the `Process` window and click on `Run`. This will bring up the programmer.
5. Confirm that the Device field is set to `GW1N-9C`, change `Operation` to `Embedded Flash Mode`, Operation to `embFlash Erase,Program`. Confirm that the `synth/impl/pnr/fpga_proj.fs` is selected in the `FS File`.
6. Connect the GoWin programming cable. Click on the `USB Cable Setting` box. This isnt obviously a button but is right next to the green right arrow. This brings up the cable setting dialog box.
7. Click on Query to check for a valid programmer. This should find the GoWin programmer on the USB port. Select the right `Port`, either Channel 0 or 1. This could cause the FPGA to be not found if you select the wrong port. Click on Save.
8. Click on the Green right arrow to program your device. This should complete without errors.

## Common Issues:
1. On step 8 above, you get an `Error: ID code mismatch`. 
  - FPGA is powered off. Ensure that the FPGA is powered on by bringing the Monocle out of its low power saving mode when the FPGA is powered off.
  - Wrong Port selected in Step 7 above. Change to the right port and repeat.
