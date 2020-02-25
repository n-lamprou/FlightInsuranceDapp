pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => uint256) authorizedContracts;
    mapping (address => bool) private registeredAirlines;
    address[] private registeredAirlineList;
    mapping (address => uint) private airlineFunds;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    mapping(bytes32 => Flight) private flights;
    uint8[] private registeredFlights;

    struct FlightInsurance {
        address[] passengers;
        mapping(address => uint) insuredValue;
        mapping(address => bool) isPaid;
    }


    mapping(address => uint) private passengerBalance;
    mapping(bytes32 => FlightInsurance) private flightInsuranceTracker;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor(address initialAirline) public
    {
        contractOwner = msg.sender;
        registeredAirlines[initialAirline] = true;
        registeredAirlineList.push(initialAirline);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier isCallerAuthorized()
    {
        require(authorizedContracts[msg.sender] == 1, "Caller is not authorized");
        _;
    }



    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() public view isCallerAuthorized returns(bool)
    {
        return operational;
    }

    function isAirlineRegistered(address airline) public view isCallerAuthorized returns(bool)
    {
        return registeredAirlines[airline];
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus(bool mode) external requireContractOwner
    {
        operational = mode;
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(address newAirline) external isCallerAuthorized returns(bool)
    {
        require(!registeredAirlines[newAirline], "Airline already registered");
        registeredAirlines[newAirline] = true;
        registeredAirlineList.push(newAirline);
        return registeredAirlines[newAirline];
    }

    function getRegisteredAirlines() external view isCallerAuthorized returns(address[])
    {
        return registeredAirlineList;
    }

    function addFunds(address airline, uint funds) external requireIsOperational isCallerAuthorized
    {
        airlineFunds[airline] = airlineFunds[airline].add(funds);
    }

    function getAirlineFunds(address airline) external view requireIsOperational isCallerAuthorized returns(uint)
    {
        return (airlineFunds[airline]);
    }


    function registerFlight(uint8 flight_code, uint8 statusCode, uint256 timestamp, address airline) external isCallerAuthorized
    {

        bytes32 flight_key = getFlightKey(airline, flight_code, timestamp);
        require(!flights[flight_key].isRegistered, "Flight is already registered.");
        flights[flight_key] = Flight({
                                        isRegistered: true,
                                        statusCode: statusCode,
                                        updatedTimestamp: timestamp,
                                        airline: airline
                                });
        registeredFlights.push(flight_code);
    }

    function getRegisteredFlightCodes() requireIsOperational isCallerAuthorized returns(uint8[])
    {
        return registeredFlights;
    }

    function isFlightRegistered(bytes32 flight_key) requireIsOperational isCallerAuthorized returns (bool)
    {
        return flights[flight_key].isRegistered;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buyInsurance(address passenger, address airline, bytes32 flight_key, uint insurance) external requireIsOperational isCallerAuthorized
    {
        flightInsuranceTracker[flight_key].passengers.push(passenger);
        flightInsuranceTracker[flight_key].insuredValue[passenger] = insurance;
        flightInsuranceTracker[flight_key].isPaid[passenger] = false;
    }

    function getInsuranceDetails(bytes32 flight_key, address passenger) external view requireIsOperational isCallerAuthorized returns (uint insurance)
    {
        insurance = flightInsuranceTracker[flight_key].insuredValue[passenger];
        return insurance;
    }

    function getInsuranceDetails2(bytes32 flight_key) external view requireIsOperational isCallerAuthorized returns (address[])
    {
        return (flightInsuranceTracker[flight_key].passengers);
    }

    /**
     *  @dev Credits payouts to insurees
    */

    function creditInsurees(bytes32 flight_key) external requireIsOperational isCallerAuthorized
    {
        for(uint c=0; c < flightInsuranceTracker[flight_key].passengers.length; c++) {
            address passenger = flightInsuranceTracker[flight_key].passengers[c];
            uint amountPaidIn = flightInsuranceTracker[flight_key].insuredValue[passenger];
            bool paid = flightInsuranceTracker[flight_key].isPaid[passenger];
            if (!paid){
                uint amountPaidOut = amountPaidIn.mul(15).div(10);
                flightInsuranceTracker[flight_key].isPaid[passenger] = true;
                passengerBalance[passenger] = passengerBalance[passenger].add(amountPaidOut);
            }
        }
    }


    function getPassengerBalance(address passenger) public view requireIsOperational isCallerAuthorized returns(uint)
    {
        return passengerBalance[passenger];
    }


    function withdrawFunds(address passenger) external requireIsOperational isCallerAuthorized
    {
        uint funds = passengerBalance[passenger];
        passengerBalance[passenger] = 0;
        passenger.transfer(funds);
    }



    function getFlightKey(address airline, uint8 flight, uint256 timestamp) pure internal returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable
    {
        getRegisteredFlightCodes();
    }

    function authorizeContract(address appContract) external requireContractOwner
    {
        authorizedContracts[appContract] = 1;
    }

    function deauthorizeContract(address appContract) external requireContractOwner
    {
        delete authorizedContracts[appContract];
    }


}

