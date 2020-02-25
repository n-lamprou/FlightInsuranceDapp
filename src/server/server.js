import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);


// Watch contract events
const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;
const ALL_CODES = [0,10,20,30,40,50];

const ORACLES_COUNT = 40;

let registeredOracles= {};

web3.eth.getAccounts().then((accounts) => {

     flightSuretyApp.methods.REGISTRATION_FEE().call().then(fee => {
      for(let a=19; a<ORACLES_COUNT; a++) {
        flightSuretyApp.methods.registerOracle()
        .send({from: accounts[a], value: fee, gas:1000000 })
        .then(result=>{
          flightSuretyApp.methods.getMyIndexes().call({from: accounts[a]})
          .then(result =>{
            registeredOracles[accounts[a]] = result;
            console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`)
          })
        })
        .catch(error => {
          console.log("Error while registering oracles: " + accounts[a] +  " Error: " + error);
        });
      }
     })
});


flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error){
        console.log(error);
    }
    else{
        const index = event.returnValues.index;
        const airline = event.returnValues.airline;
        const flight = event.returnValues.flight;
        const timestamp = event.returnValues.timestamp;

        for(let oracle in registeredOracles)
        {
            let oracleIndexes = registeredOracles[oracle];
            if(oracleIndexes.includes(index))
            {
                let StatusCode = ALL_CODES[Math.floor(Math.random() * ALL_CODES.length)]
                //let statusCode = STATUS_CODE_LATE_AIRLINE; // Always pay back for testing
                flightSuretyApp.methods.submitOracleResponse(index, airline, flight, timestamp, statusCode)
                .send({from: oracle, gas:1000000})
                .then(result =>{
                    console.log("Oracle " + oracle + " response: " + statusCode);
                });
            }
        }
    }
});



const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


