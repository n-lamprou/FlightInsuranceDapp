
let Test = require('../config/testConfig.js');
let BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  let config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeContract(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyApp.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline, {from: config.flightSuretyApp.address});

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });


  it('(airline) second airline can register an Airline using registerAirline() by registered & funded airline', async () => {

    // ARRANGE
    let newAirline = accounts[2];
    await config.flightSuretyApp.addFunds({from: config.firstAirline, value: web3.utils.toWei('12', "ether")});

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }

    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline, {from: config.flightSuretyApp.address});

    // ASSERT
    assert.equal(result, true, "Airline should be able to register another airline if it has provided funding");

  });


  it('(airline) 5th airline cannot be registered by single airline', async () => {

    // ARRANGE

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(accounts[3], {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(accounts[4], {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(accounts[5], {from: config.firstAirline});
    }
    catch(e) {
        console.log(e);
    }

    let result2 = await config.flightSuretyData.isAirlineRegistered.call(accounts[2], {from: config.flightSuretyApp.address});
    let result3 = await config.flightSuretyData.isAirlineRegistered.call(accounts[3], {from: config.flightSuretyApp.address});
    let result4 = await config.flightSuretyData.isAirlineRegistered.call(accounts[4], {from: config.flightSuretyApp.address});
    let result5 = await config.flightSuretyData.isAirlineRegistered.call(accounts[5], {from: config.flightSuretyApp.address});

    let total = await config.flightSuretyData.getRegisteredAirlines.call({from: config.flightSuretyApp.address});

    // ASSERT
    assert.equal(result2, true, "Airline should be able to register one airline if it has provided funding");
    assert.equal(result3, true, "Airline should be able to register two airline if it has provided funding");
    assert.equal(result4, true, "Airline should be able to register three airline if it has provided funding");
    assert.equal(result5, false, "Multiconsenus requirement should prevent 5 airline from being registered");
    assert.equal(total.length, 4, "4 airlines should have successfully been registered");

  });


  it('(airline) 5th airline can be registered when 3 registered airline vote for it', async () => {

    // ARRANGE
    await config.flightSuretyApp.addFunds({from: accounts[2], value: web3.utils.toWei('12', "ether")});
    await config.flightSuretyApp.addFunds({from: accounts[3], value: web3.utils.toWei('12', "ether")});

    // ACT
    // Also register airline from second account (2/4 = 50%)
    await config.flightSuretyApp.registerAirline(accounts[5], {from: accounts[2]});

    let result5 = await config.flightSuretyData.isAirlineRegistered.call(accounts[5], {from: config.flightSuretyApp.address});

    let total = await config.flightSuretyData.getRegisteredAirlines.call({from: config.flightSuretyApp.address});

    // ASSERT

    assert.equal(result5, true, "Multiconsenus requirement should allow 5th airline to be being registered");
    assert.equal(total.length, 5, "5 airlines should have successfully been registered");
  });


  it('(passenger) Passenger can buy insurance for registered flight', async () => {

    // ARRANGE
    await config.flightSuretyApp.registerFlight(123, 1893456000, {from: accounts[1]});

    // ACT
    await config.flightSuretyApp.buyInsurance(accounts[1], 123, 1893456000, {from: accounts[10], value: 1000000});
    let flight_key = await config.flightSuretyApp.getFlightKey.call(accounts[1], 123, 1893456000);
    let insurance = await config.flightSuretyData.getInsuranceDetails.call(flight_key, accounts[10], {from: config.flightSuretyApp.address});
    // ASSERT

    assert.equal(insurance, 1000000, "Incorrect stored insurance value");
  });

  it('(passenger) Passenger receives correct payback when flight delayed', async () => {

    // ARRANGE
    await config.flightSuretyApp.buyInsurance(accounts[1], 123, 1893456000, {from: accounts[11], value: web3.utils.toWei('1', "ether")});
    //let flight_key = await config.flightSuretyApp.getFlightKey.call(accounts[1], 123, 1893456000);

    // ACT
    //await config.flightSuretyData.creditInsurees(flight_key, {from: config.flightSuretyApp.address});
    await config.flightSuretyApp.processFlightStatus(accounts[1], 123, 1893456000, 20, {from: accounts[11]});

    // ASSERT
    let payback = new BigNumber(await config.flightSuretyData.getPassengerBalance.call(accounts[11], {from: config.flightSuretyApp.address}));
    let expected_payback = web3.utils.toWei('1500', "milli");


    assert.equal(payback, expected_payback, "Incorrect stored insurance value");
  });

  it('(passenger) Passenger can withdraw funds from contract', async () => {

    // ARRANGE
    let initFunds = await config.flightSuretyData.getPassengerBalance.call(accounts[11], {from: config.flightSuretyApp.address});
    let initBalance = await web3.eth.getBalance(accounts[11]);

    // ACT
    await config.flightSuretyApp.withdrawFunds({from: accounts[11]});

    // ASSERT
    let finFunds = await config.flightSuretyData.getPassengerBalance.call(accounts[11], {from: config.flightSuretyApp.address});
    let finBalance = await web3.eth.getBalance(accounts[11]);

    assert.equal(initFunds, web3.utils.toWei('1500', "milli"), "Incorrect initial funds value");
    assert.equal(finFunds, 0, "Incorrect final funds value");
    assert(finBalance>initBalance, 'Incorrect funds withdrawn')
  });


});
