const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = async (deployer) => {

    let initialAirline = '0x0C5b753dA07bb54a9A55BcF43909127d80565342';
    await deployer.deploy(FlightSuretyData, initialAirline)
        .then(() => {
            return deployer.deploy(FlightSuretyApp, FlightSuretyData.address)
                    .then(() => {
                        let config = {
                            localhost: {
                                url: 'http://localhost:7545',
                                dataAddress: FlightSuretyData.address,
                                appAddress: FlightSuretyApp.address
                            }
                        }
                        fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                        fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                    });
        });

    let dataContract = await FlightSuretyData.deployed();
    let appContract = await FlightSuretyApp.deployed();
    await dataContract.authorizeContract(appContract.address);
}