// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
pragma experimental ABIEncoderV2;

     // By @liorabadi between the 25-01-2022 and 26-01-2022 for learning and practising purposes.   

    // Contract factory controlled by the WHO(World Health Organization) where each contract allows the health centers to manage their PCR tests.
    // Verified Ropsten Contract Address: 0x1ed7bc3db7fc505674fcb57cf15f7e062b137016
    // https://ropsten.etherscan.io/address/0x1ed7bc3db7fc505674fcb57cf15f7e062b137016#code
    
    
contract factory_medical{

    // =========== INITIAL DECLARATIONS ===========
    // WHO (World Health Organization) address ---> owner.
    address public WHO;

    // Assign owner to the WHO as the deployer.
    constructor() {
        WHO = msg.sender;
    }

    // Permissions given by to the WHO which are allowed to collect PCR tests. 
    // If true, the address corresponding to the Health Center wil be able to collect samples (create the smart contract)
    mapping (address => bool) public AllowedHealthCenter;
    
    // Relationship between health centers with their contracts.
    mapping (address => address) myCenterContractAddress;

    // Array of Health Centers who requested access.
    address [] requestedAccess;

    // Array of contract addresses storing the allowed health centers.
    address [] public Contract_Health_Centers;

    // Events to Emits
    event NewCenterValidated(address);
    event NewContractCreated(address, address); /// (contract address, owner address)
    event AccessSumission(address);
    
    // Modifier OnlyWHO()
    modifier OnlyWHO() {
        require( msg.sender == WHO, "You don't have permissions to do this.");
        _;
    }

    // =========== MANAGEMENT FUNCTIONS ===========
    //  Validate new HealthCenters
    function ValidateHealthCenter(address _healthCenter) public OnlyWHO(){
        AllowedHealthCenter[_healthCenter] = true;
        emit NewCenterValidated(_healthCenter);
    }

    // Contract Factory for each health Center
    function CreateHealthCenter() public {
        require(AllowedHealthCenter[msg.sender] == true, "This health center is not validated.");
        // Generate a new contract, to do so we need a subaddress.
        
        // IMPORTANT LINE IN HERE
        address newContractHealthCenter = address(new HealthCenter(msg.sender)); // The msg.sender will be the owner of this new HealthCenter contract.
        // By saying (new HealthCenter(parameters)), those parameters are the input for the constructor of that new contract.

        // Store the new contract address in the arrayPointerWinner
        Contract_Health_Centers.push(newContractHealthCenter);

        // Relate the contract address with the health Center
        myCenterContractAddress[msg.sender] = newContractHealthCenter;

        emit NewContractCreated(newContractHealthCenter, msg.sender);
    }

    // Provide a quick way for each Health Center to get their contract address once it is generated.
    function viewMyContractAddress() public view returns(address){
        require (AllowedHealthCenter[msg.sender] , "Your Health Center was not allowed yet.");
        require(myCenterContractAddress[msg.sender] != address(0), "Your contract was not been generated yet.");
        return myCenterContractAddress[msg.sender];    
    }

    // Give the chance to each Center to request access to the WHO.
    function requestAccess() public returns(string memory){
        requestedAccess.push(msg.sender);
        emit AccessSumission(msg.sender);
        return "Your request was properly submitted.";    
    }

    // Allow only the WHO to check the submissions.
    function checkRequests() public view OnlyWHO() returns(address [] memory){
         return requestedAccess;
    }

   
}

// =========== SELF-MANAGE HEALTH CENTER CONTRACT CREATION ===========

contract HealthCenter{

    // =========== INITIAL DECLARATIONS ===========
    address public HealthCenterAddress;
    address public HealthCenterContractAddress;

    constructor (address _address) {
        HealthCenterAddress = _address ;
        HealthCenterContractAddress = address(this);
    }

    // Relate hashed Patient ID with their results and IPFS PDF certificates, respecting the privacy of the patient.
    mapping (bytes32 => CoronavirusResults) patientResults;

    struct CoronavirusResults {
        bool detectedCoronavirus;
        string IPFSResults;
    }

    // Events to trigger
    event newResult(bool, string);

    // OnlyHealthCenter modifier
    modifier OnlyHealthCenter() {
        require(msg.sender == HealthCenterAddress, "You dont have permissions to do this.");
        _;
    }

    // =========== HEALTH CENTER MANAGEMENT ===========
    // Emit the result of a test
    // Sample format of input data (123456ZX, false, QmdWqzkx3pCwzzH49j63MgXPd7tgvVZu1y4EyyM579d7fB).
    function giveResults(string memory _IDPatient, bool _hasCovid, string memory _IPFSCode) public OnlyHealthCenter() {
        bytes32 hashPatient = keccak256(abi.encodePacked(_IDPatient));
       
        patientResults[hashPatient] = CoronavirusResults(_hasCovid, _IPFSCode);
        
        emit newResult(_hasCovid, _IPFSCode);
    }

    // View The results
    function viewMyResults(string memory _PatientID) public view returns(string memory, string memory) {
        bytes32 patientHash = keccak256(abi.encodePacked(_PatientID));
        bytes memory tempBytesPatient = bytes(patientResults[patientHash].IPFSResults);

        require (tempBytesPatient.length != 0, "Your results are not uploaded yet.");
        // Return de boolean como string.
        string memory testResults;
        if ( patientResults[patientHash].detectedCoronavirus == true){
            testResults = "Detected";
        }else {
            testResults = "Non Detected";
        }
        // Return of parameters.
        
        return(testResults, patientResults[patientHash].IPFSResults);
    }
}
