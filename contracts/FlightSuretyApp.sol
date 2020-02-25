pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint private constant FUNDING_THRESHOLD = 10 ether;
    uint8 private constant MULTIPARTY_CONSENSUS_THRESHOLD = 4;
    uint8 private constant MULTIPARTY_CONSENSUS_PERCENTAGE = 50;
    uint private constant MAX_INSURANCE = 1 ether;

    mapping(address => address[]) private registrationVotes;

    address private contractOwner;          // Account used to deploy contract

    FlightSuretyData _flightSuretyData;
 
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
        require(_flightSuretyData.isOperational(), "Contract is currently not operational");
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

    modifier requireAirlineIsRegistered()
    {
        require(_flightSuretyData.isAirlineRegistered(msg.sender) == true, "Caller is not registered airline");
        _;
    }

    modifier requireSufficientFunds()
    {
        bool hasFunds = false;
        uint funds = _flightSuretyData.getAirlineFunds(msg.sender);
        if(funds >= FUNDING_THRESHOLD)
            hasFunds = true;
        require(hasFunds == true, "Minimum funds of 10 ether required");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address dataContract) public
    {
        contractOwner = msg.sender;
        _flightSuretyData = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()  public view returns(bool)
    {
        return _flightSuretyData.isOperational();
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline(address airline) external requireIsOperational requireAirlineIsRegistered requireSufficientFunds returns (bool success)
    {
        address[] memory airlines = _flightSuretyData.getRegisteredAirlines();
        uint airlines_count = airlines.length;
        success = false;
        if (airlines_count < MULTIPARTY_CONSENSUS_THRESHOLD) {
            success = _flightSuretyData.registerAirline(airline);
        }
        else {

            // Check that no double voting occurs
            bool isDuplicate = false;
            for(uint c=0; c<registrationVotes[airline].length; c++) {
                if (registrationVotes[airline][c] == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }
            require(!isDuplicate, "Caller has already voted to register this airline.");

            registrationVotes[airline].push(msg.sender);
            uint numVotes = registrationVotes[airline].length;
            uint consensus = numVotes.mul(100).div(airlines_count);

            if (consensus >= MULTIPARTY_CONSENSUS_PERCENTAGE){
                success = _flightSuretyData.registerAirline(airline);
            }
        }
        return (success);
    }

    function getRegisteredAirlines() external view requireContractOwner requireIsOperational returns (uint256 count, address[] airlines)
    {
        airlines = _flightSuretyData.getRegisteredAirlines();
        count = airlines.length;
        return (count, airlines);
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight(uint8 flight_code, uint256 timestamp) external requireIsOperational requireAirlineIsRegistered requireSufficientFunds
    {
        require(timestamp >= block.timestamp, "Flight timetstamp must be in the future");
        _flightSuretyData.registerFlight(flight_code, STATUS_CODE_UNKNOWN, timestamp, msg.sender);
    }

    function getRegisteredFlightCodes() external view requireIsOperational returns(uint256 count, uint8[] flights)
    {
        flights = _flightSuretyData.getRegisteredFlightCodes();
        count = flights.length;
        return (count, flights);
    }

    function addFunds() public payable requireIsOperational requireAirlineIsRegistered
    {
        address(_flightSuretyData).transfer(msg.value);
        _flightSuretyData.addFunds(msg.sender, msg.value);
    }


    function buyInsurance(address airline, uint8 flight, uint256 timestamp) public payable requireIsOperational
    {
         bytes32 flight_key = getFlightKey(airline, flight, timestamp);
         require(_flightSuretyData.isFlightRegistered(flight_key) == true, "Flight is not registered");
         require(msg.value <= MAX_INSURANCE, "Maximum insurance limit exceeded");
         address(_flightSuretyData).transfer(msg.value);
        _flightSuretyData.buyInsurance(msg.sender, airline, flight_key, msg.value);
    }

    function withdrawFunds() public requireIsOperational
    {
       uint balance = _flightSuretyData.getPassengerBalance(msg.sender);
       require(balance > 0, "No funds available to withdraw");
       _flightSuretyData.withdrawFunds(msg.sender);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus(address airline, uint8 flight, uint256 timestamp, uint8 statusCode) public requireIsOperational
    {
         if(statusCode == STATUS_CODE_LATE_AIRLINE) {
             bytes32 flight_key = getFlightKey(airline, flight, timestamp);
             _flightSuretyData.creditInsurees(flight_key);
         }

    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline, uint8 flight, uint256 timestamp) external requireIsOperational
    {

        //bytes32 flight_key = getFlightKey(airline, flight, timestamp);
        //require(_flightSuretyData.isFlightRegistered(flight_key) == true, "Flight is not registered");

        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, uint8 flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, uint8 flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, uint8 flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle() external payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes() view external returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(uint8 index, address airline, uint8 flight, uint256 timestamp, uint8 statusCode) external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey(address airline, uint8 flight, uint256 timestamp) pure public returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}


contract FlightSuretyData {
    function isOperational() public view returns(bool);
    function isAirlineRegistered(address airline) public view returns (bool);
    function registerAirline(address airline) external returns (bool);
    function getRegisteredAirlines() external view returns(address[]);
    function registerFlight(uint8 flight_code, uint8 statusCode, uint256 timestamp, address airline) external;
    function getRegisteredFlightCodes() returns(uint8[]);
    function addFunds(address airline, uint funds) external;
    function getAirlineFunds(address airline) external view returns (uint);
    function isFlightRegistered(bytes32 flight_key) returns (bool);
    function buyInsurance(address passenger, address airline, bytes32 flight_key, uint insurance) external;
    function creditInsurees(bytes32 flight_key) external;
    function withdrawFunds(address passenger) external;
    function getPassengerBalance(address passenger) public view returns(uint);
}