const Migrations = artifacts.require("Migrations");
const Timelock = artifacts.require("Timelock");

module.exports = function (deployer) {
  deployer.deploy(Migrations);
  // deployer.deploy(Timelock,'0x7dE7e0f02f7229E37501d19482e96E97779f7299');
};
