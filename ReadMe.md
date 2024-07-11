# RLS Career Overhaul

## Overview

The RLS Career Overhaul mod enhances various aspects of BeamNG.drive, including police interactions, the economy, parcel and vehicle deliveries, insurance, garage space, and dealerships. This mod aims to provide a more immersive and challenging career experience.

## Features

### Police

- **Roaming Police**: Enabled roaming police that will pull you over.
- **Play as Police**: Drive a police vehicle (any vehicle with a police siren) to play as police. If suspects are not spawning, exit and re-enter your police vehicle.
- **Earn Money**: Earn money from escaping as a suspect or catching suspects as police.
- **Troubleshooting**: If police are not spawning, go into free roam, spawn traffic with police, and return to career mode.
- **Message for Police Role**: Added a message stating if you are a cop.

### Economy

- **Increased Ticket Prices**: Higher prices for speed camera and red-light camera tickets.
- **Adjusted Speed Trap Pricing**: Speed trap pricing has been adjusted.
- **Speed Traps**: Speed traps are now connected to insurance.
- **Adjusted Redlight Camera Pricing**: Redlight camera pricing has been adjusted.
- **Redlight Camera**: Redlight cameras are now connected to insurance.

### Parcel Deliveries

- **Increased Cargo**: More cargo available and increased spawn rate.
- **Adjusted Prices**: Adjusted price calculations and added heavier cargo.

### Vehicle Deliveries

- **Increased Deliveries**: More deliveries available with increased rewards.

### Insurance

- **Dynamic Rates**: Insurance rates are now dynamic and based on the amount the insurance has to pay.
- **Deductible Changes**: Deductible is now a percentage of your insured vehicle value, ranging from 0.5% to 10%.
- **Repair Times**: Repair times range from 2 minutes to 30 minutes.
- **Renewal Range**: Renewal range is a multiplier that is cheaper for longer periods.
- **Cheapest Option**: Insurance will always be the cheapest option now.
- **Detailed Insurance Logs**: Added detailed insurance logs.
- **Test Drives Affect Insurance**: Test drives now affect your daily driver insurance.

#### Insurance Policies

Each policy has specific perks with customizable parameters:

- **Paint Repair**:
  - Choices: true, false
  - Premium Influence: 150, 0
- **Repair Time**:
  - Choices: 120, 300, 600, 1800 seconds
  - Premium Influence: 300, 100, 25, 10
- **Deductible**:
<<<<<<< Updated upstream
  - Choices: 1.5%, 2.5%, 5%, 10%
=======
  - Choices: 5%, 10%, 15%, 25%
>>>>>>> Stashed changes
  - Premium Influence: 300, 200, 125, 50
- **Renewal**:
  - Choices: 25000, 50000, 100000, 150000 km
  - Premium Influence: 1, 1.5, 2, 2.5
- **Roadside Assistance**:
  - Choices: true, false
  - Premium Influence: 110, 0

#### Policy Score

- **Dynamic Calculation**: The policy score is now based on how much the insurance has to pay divided by an interval determined by your repair time selection.
- **Impact of Deductible**: If you have a lower deductible percentage, insurance will have to cover more, making your score go up faster.
- **Impact of Repair Time**: Faster repair times will also make your insurance score go up.
- **Score Multiplier**: The rate increase is multiplied by your score, meaning higher insurance scores result in more significant increases.
- **Policy Score Deduction**: The deduction is now 10% of the score, making insurance go down faster.
- **Renewal Term**: The rate at which the policy score deduction occurs is based on the renewal term. Every term without an accident will reduce your policy score.
- **Minimum Policy Score**: The minimum policy score is now 0.5, allowing for cheaper insurance if you never use it or get caught by police.

This new system encourages safer driving and careful management of insurance coverage to maintain lower costs.

### Garage Space

- **Increased Space**: Garage space increased to 15 slots.

### Dealerships

- **Reworked Dealerships**: Car dealerships and categories have been reworked.
- **Increased Inventory**: More cars available at each dealership.
- **Faster Refresh**: Cars refresh more quickly in dealerships.
- **Wider Price Range**: Vehicles now have a wider range of prices, making it possible to get a good deal and sell a car for a profit.
- **Vehicle Valuation and Depreciation**: Vehicles are valued and depreciate differently, making them not as cheap due to still being fully functional.

#### Dealership Lore

- **Belasco Auto**: Specializes in new and lightly used reasonably priced cars.
- **Rich's Motor Company**: Sells expensive/exotic cars, rare trims of classic cars, and high-end race cars.
- **Jefferson Motors**: Focuses on cheaper classic cars, race cars, and custom cars, positioning itself as a custom shop.
- **Quarryside Auto Sales**: Expanded into used cheap trucks and SUVs to stay relevant.
- **Commercial Vehicle Sales**: Offers retired service/police vehicles and commercial/fleet vehicles.

### Test Drive

- **Dynamic Repair Cost**: Test drive repair cost is now dynamic based on the vehicle.

### Starting Capital

- **Increased Starting Capital**: Starting capital has been increased from 13,500 to 25,500.

## Installation

1. **Download the Mod**:
   - Click on the green "Code" button and select "Download ZIP".

2. **Extract the Contents**:
   - Extract the downloaded ZIP file to a folder on your computer.

3. **Compress the Mod**:
   - Ensure the mod's contents are compressed into a single ZIP file. Exclude the `.gitignore` and `README.md` files to keep the mod clean and focused on game-relevant files.

4. **Move to Mods Folder**:
   - Navigate to your BeamNG.drive mods folder. The default path is `%AppData%\BeamNG.drive\0.32\mods`. Note that `0.32` is the current version and might be different for your game.
   - Copy the compressed ZIP file into the `mods` folder.

5. **Enable the Mod**:
   - Launch BeamNG.drive.
   - Go to the game settings and enable the RLS Career Overhaul mod.

## Conclusion

The RLS Career Overhaul mod provides a comprehensive enhancement to the career mode, making it more engaging and challenging. Enjoy the new features and improvements!

### Notes

For installing the mod directly from GitHub, compress the mod's contents into a single ZIP file (excluding the `.gitignore` and `README.md` files) and place the compressed file into the mods folder of BeamNG.drive. This ensures the mod functions correctly and appears in the game's Mod Manager.

For more detailed instructions, you can refer to the official [BeamNG Documentation](https://documentation.beamng.com/tutorials/mods/installing-mods/) and [Steam Community Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2918556246) on how to manually install mods.