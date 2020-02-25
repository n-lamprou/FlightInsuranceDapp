
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });

        contract.getRegisteredAirlines((error, result) => {
            console.log(error,result);
            display('Registered Airlines', '', [ { label: 'Number of Registered Airlines', error: error, value: result.count} ]);
        });

        contract.getRegisteredFlightCodes((error, result) => {
            console.log(error,result);
            display('Registered Flights', '', [ { label: 'Registered Flights', error: error, value: result.flights} ]);
        });
    

        // User-submitted transaction

        DOM.elid('submit-register-airline').addEventListener('click', () => {
            let airline = DOM.elid('airline-address').value;
            // Write transaction
            contract.registerAirline(airline, (error, result) => {
                console.log(error, result);
                display('Airline Registration', 'Register a new airline', [ { label: '', error: error, value: result} ]);
            });
        });

        DOM.elid('submit-add-funds').addEventListener('click', () => {
            let funds = DOM.elid('airline-funds').value;
            // Write transaction
            contract.addFunds(funds, (error, result) => {
                console.log(error, result);
                display('Add Funds', 'Add airline funds to participate', [ { label: '', error: error, value: result} ]);
            });
        });

        DOM.elid('submit-register-flight').addEventListener('click', () => {
            let flight = DOM.elid('flight-code').value;
            // Write transaction
            contract.registerFlight(flight, (error, result) => {
                console.log(error, result);
                display('Flight Registration', 'Register a new flight', [ { label: '', error: error, value: result} ]);
            });
        });

        DOM.elid('submit-buy-insurance').addEventListener('click', () => {
            let flight = DOM.elid('flight-insured').value;
            // Write transaction
            contract.buyInsurance(flight, (error, result) => {
                console.log(error, result);
                display('Passenger Insurance', 'Buy flight insurance', [ { label: '', error: error, value: result} ]);
            });
        });

        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        });

        DOM.elid('submit-withdraw').addEventListener('click', () => {
            // Write transaction
            contract.withdrawFunds((error, result) => {
                display('Fund Withdrawl', 'Withdraw insured funds', [ { label: '', error: error, value: result} ]);
            });
        });
    
    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







