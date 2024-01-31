const Migrations = artifacts.require("Migrations");

module.exports = function (deployer) {
  console.log("migration started...")
  deployer.deploy(Migrations);
};
