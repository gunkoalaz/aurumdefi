# aurumdefi
AurumDeFi project is the lending platform originate in REI chain

this project is soft fork from Venus protocol
The code is modified and rearrange. Smart contract is compiled with Solidity version ^0.8.0

the solidity source code is in src/contracts

Comptroller  is seperated to 3 part
1. Comptroller
2. ComptrollerStorage :: stored the state variables
3. ComptrollerCalculation :: stored the complex calculating function

vToken is changed to LendToken :: LendToken is the Token that can interact with the Comptroller
To take any action in LendToken contract including transfer, mint, burn, liquidate other LendToken, the contract caller must has permit from comptroller.
Thus the comptroller is the core contract that make decision and allowed the LendToken to take action.

AurumPriceOracle is used to read the price feed data of underlying tokens prices and Gold price
AurumInterestRateModel is calculating contract to return the borrowsRatePerSeconds, and supplyRatePerSeconds

ARM is the governance token of platform
AURUM is the synthetic token modified from VAI. It's not pegged with dollar, but instead pegged with Gold price in 'dollar per troy ounces'
