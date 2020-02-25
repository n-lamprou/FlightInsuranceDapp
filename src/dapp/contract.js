import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.initialAirline = null;
        this.airlines = [];
        this.passengers = [];
        this.future = 1893456000;
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];
            this.initialAirline = accts[2];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    getRegisteredAirlines(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .getRegisteredAirlines()
            .call({ from: self.owner}, callback);
    }

    getRegisteredFlightCodes(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .getRegisteredFlightCodes()
            .call({ from: self.owner}, callback);
    }

    registerAirline(airline, callback) {
       let self = this;
       let payload = {
            airline: airline
        }
       self.flightSuretyApp.methods
            .registerAirline(payload.airline)
            .send({ from: self.airlines[0], gas: 1000000}, (error, result) => {
                callback(error, result);

            });
    }

    addFunds(funds, callback){
        let self = this;
        const fundsWei = self.web3.utils.toWei(funds, "ether");
        self.flightSuretyApp.methods
            .addFunds()
            .send({ from: self.airlines[0], value: fundsWei, gas: 1000000}, (error, result) => {
            callback(error, result);
        });
    }

    registerFlight(flight, callback) {
       let self = this;
       let payload = {
            flight: parseInt(flight),
            timestamp: this.future
        }
       self.flightSuretyApp.methods
            .registerFlight(payload.flight, payload.timestamp)
            .send({ from: self.airlines[0], gas: 1000000}, (error, result) => {
                callback(error, result);
            });
    }

    buyInsurance(flight, callback) {
       let self = this;
       let payload = {
            flight: parseInt(flight),
            timestamp: this.future
        }
       const insuranceWei = self.web3.utils.toWei('1', "ether");
       self.flightSuretyApp.methods
            .buyInsurance(self.airlines[0], payload.flight, payload.timestamp)
            .send({ from: self.passengers[0], value: insuranceWei, gas: 1000000}, (error, result) => {
                callback(error, result);
            });
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: this.future//Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }

    withdrawFunds(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .withdrawFunds()
            .send({ from: self.passengers[0]}, (error, result) => {
                callback(error, result);
            });
    }
}