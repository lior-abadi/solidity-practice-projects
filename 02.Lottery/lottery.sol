// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Lottery is ERC20, AccessControl {
    
    // -------------------------- INITIAL DECLARATIONS --------------------------
    // @dev As known regarding EVM compiling, grouping declarations by variable type in order to save gas.

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");


    address public owner;
    address public contractAddress;

    uint256 public tokenprice;

    
    constructor(uint256 _initialSupply) ERC20("Lottoken", "Lotto") {
        owner = msg.sender;
        contractAddress = address(this);

        _mint(contractAddress, _initialSupply * 10 ** decimals()); // Token with 18 decimals.

        _grantRole(DEFAULT_ADMIN_ROLE, owner); 
        _grantRole(MINTER_ROLE, owner);
    }

    // -------------------------- CLIENT VIEW FUNCTIONS --------------------------
    // View the current token balance of who sends.
    function getMyTokenBalance() public view returns(uint){
        return balanceOf(msg.sender);
    }

    function availableTokens() public view returns(uint){
        return balanceOf(contractAddress);
    }

    function contractEtherBalance() public view returns(uint){
        return contractAddress.balance;
    }

    // -------------------------- TOKEN MANAGEMENT -------------------------------

    // Ownership and logistics of products:
    // Contract:    Tokens <---> Ether liquidity.
    // Owner:       Tokens <---> Tickets liquidity.
    // Customer:    Ether  <---> Tokens <---> Tickets (Customer <----> Contract <----> Owner)

    event TokensBought(uint, address);

    // Inyect tokens into the contract only callable by the owner.
    function GenerateTokens(address _addressTo, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(_addressTo, amount * 10 ** decimals());
    }

    // Set a token price. Callable by the owner.
    function setTokenPrice(uint _newEtherPrice3decimals) public onlyRole(DEFAULT_ADMIN_ROLE) {
        //If 1 Token = 1 Ether is wanted, should _newEtherPrice3decimals = 100 so the tokenprice equals 1 ether (1 * 10^18 wei).
        // 1 Token = 1 Ether, easy for examples and 1:1 ratio is awesome for critical economies as Carlos Maul said.
        tokenprice = _newEtherPrice3decimals * ( 10**16 wei); 
    }
    // Function used inside the project to convert the tokens to ether.
    function tokenPrice(uint256 _numTokens) public view returns(uint256){
        require(tokenprice != 0, "A token value must be set by the Admin.");   
        return _numTokens * tokenprice;
    }

    // Buy lottery tokens to play the lottery (Ether ---> Tokens)
    function BuyTokens(uint _numTokens) public payable {
        uint totalCost = tokenPrice(_numTokens); // Output in WEI.
        //Check if the sender has ether balance to pay.
        require (msg.value >= totalCost, "Not enough ether to pay for this amount of tokens." );

        // Check if there are enough tokens in the contract.
        uint contractBalance = balanceOf(contractAddress);
        require (contractBalance >= _numTokens *10 ** decimals(), "There are not enough Lottery tokens to satisfy this request.");

        // Securely return the ether excess the sender may pay by mistake.
        uint returnExcess = msg.value - totalCost;
        payable(msg.sender).transfer(returnExcess);

        // The lottery transfers the tokens to the client.
        _transfer(contractAddress, msg.sender, _numTokens *10**decimals());

        emit TokensBought(_numTokens, msg.sender);
       
    }
        // See the Jackpot balance
        function jackpotBalance() public view returns(uint) {
            return balanceOf(owner);
        }

        // -------------------------- LOTTERY DECLARATIONS -------------------------------
        // Ticket price (expressed in tokens)
        uint public TicketPrice = 5;

        // Relationship between the person who buys the tickets and its numbers.
        mapping (address => uint [] ) ticketNumbers;

        // Relationship required to assign winning number with the winner.
        mapping (uint => address) DNA_Ticket;

        // Random numbers.
        uint randNonce = 0;

        // Generated tickets (so far).
        uint [] tickets_bought_globally;

        event winner_ticket(uint);
        event ticket_bought(uint, address);
        event cash_out_tokens(uint, address);

        // -------------------------- LOTTERY MANAGEMENT -------------------------------

        //  Buy tickets with tokens. The tokens paid go to the jackpot.
        function buyTickets(uint _amount) public{
            uint totalTicketCost = _amount * TicketPrice * 10 ** decimals(); // [Ticket] * [Tokens / Ticket] *[TokensToDecimal] OK units checked.
            require ( balanceOf(msg.sender) >= totalTicketCost, "You need more tokens to buy this amount of tickets.");

            // Sending the tokens to the jackpot. The jackpot will be stored in the Owner address.
            _transfer(msg.sender, owner, totalTicketCost);

            // Generating tickets to the customer. (Possible numbers 0-9999)
            for(uint i = 0; i< _amount; i++){
                uint randomNumber = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % 10000; // The %10000 takes the last 4 digits.
                randNonce++;
                
                // Checks if the number is already on the list.
                bool changedNumber = false;
                uint randomNumberTwo;
                for (uint j = 0; j<tickets_bought_globally.length; j++){

                    if (tickets_bought_globally[j] == randomNumber){
                       randomNumberTwo = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % 10000; // The %10000 takes the last 4 digits.
                       j = 0;
                       changedNumber = true;
                    }
                }

                // Saving the correct number inside the concerning variables.               
                if (changedNumber) {
                    // If true, means that the number was changed.
                    // Saving the ticket data into the customer and into the global ticket list variable.
                    ticketNumbers[msg.sender].push(randomNumberTwo);
                    // Save the number in the global list.
                    tickets_bought_globally.push(randomNumberTwo);
                    // Save the DNA of the Ticket to its customer in case of winning.
                    DNA_Ticket[randomNumberTwo] = msg.sender;
                    emit ticket_bought(randomNumberTwo, msg.sender);
                } else {
                    // If false, means that the number was not changed.
                    // Saving the ticket data into the customer and into the global ticket list variable.
                    ticketNumbers[msg.sender].push(randomNumber);
                    // Save the number in the global list.
                    tickets_bought_globally.push(randomNumber);
                    // Save the DNA of the Ticket to its customer in case of winning.
                    DNA_Ticket[randomNumber] = msg.sender;
                    emit ticket_bought(randomNumber, msg.sender);
                }
            }       
        }

        // View the amount of tickets a person holds.
        function MyTickets() public view returns(uint [] memory){
            return ticketNumbers[msg.sender];
        }


        // Pick a winning ticket transparently.
        function picWinner() public onlyRole(DEFAULT_ADMIN_ROLE) returns(address){
            require( tickets_bought_globally.length > 0, "There are no tickets bought for this raffle." );

            // We must pick randomly a winner number among the myLength amount of tickets.
            uint myLength = tickets_bought_globally.length;
            uint arrayPointerWinner = uint (uint(keccak256(abi.encodePacked(block.timestamp))) % myLength); // If there are 3 digits instead of 4, the pointer adjusts itself.
            uint winnerNumber = tickets_bought_globally[arrayPointerWinner];

            emit winner_ticket(winnerNumber);

            // Send the tokens from the Jackpot to the winner.
            _transfer(owner, DNA_Ticket[winnerNumber], jackpotBalance());

            return DNA_Ticket[winnerNumber];
        }

        // Setting Cash Out Commission (a %)
        uint public commission_percentage = 0;
        function setCommision(uint _newCommission) public onlyRole(DEFAULT_ADMIN_ROLE){
            commission_percentage = _newCommission;
        }

        // Cashing out the tokens for ether. (Tokens ---> Ether). 
        function CashOut(uint _TokensToCashOut, uint _tipForTheLotto) public payable returns(string memory){
            
            require(balanceOf(msg.sender) >= _TokensToCashOut * 10 ** decimals(), "You do not own that amount of tokens.");
            require(balanceOf(msg.sender) > _tipForTheLotto  * 10 ** decimals(), "Thanks for being that generous, but you dont own that amount of tokens." );
            require(_TokensToCashOut >= _tipForTheLotto, "You can't donate more tokens than the amount you are willing to cash-out.");
            require( _TokensToCashOut > 0, "You need to cash out more than zero tokens.");

            // We need to substract the amount of tokens from the client to the contract (make them available for future exchanges Ether --> Token)
            uint finalTokensAmount = _TokensToCashOut-_tipForTheLotto;
            _transfer(msg.sender, contractAddress, _TokensToCashOut * 10 ** decimals());

            // We need to transfer the ethers from the Contract to the Client minus commission. Conversion Token --> Ether.
            uint tokensToTansform = finalTokensAmount - finalTokensAmount * commission_percentage / 100;
            uint tokensToEther = tokenPrice(tokensToTansform)  ;
            payable(msg.sender).transfer(tokensToEther);
            
            string memory cashOutLog;
            if( _tipForTheLotto < 0){
                cashOutLog = "The tokens have been successfuly exchanged.";
            } else{
                cashOutLog = "The tokens have been successfuly exchanged. Thank you for the tip!";
            }

            emit cash_out_tokens(finalTokensAmount, msg.sender);
            return cashOutLog;
        }

        // -------------------------- WITHDRAW ETH TO THE OWNER  -------------------------------
        function withdrawAllEther() external onlyRole(DEFAULT_ADMIN_ROLE) {
            (bool success, ) = msg.sender.call{value: address(this).balance}("");
            require(success, "Failed to send ether");
        }

        
        // -------------------------- WITHDRAW TOKENS TO THE OWNER  -------------------------------
        function withdrawTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
            require (balanceOf(contractAddress) > 0, "There are no tokens available in the contract.");
            _transfer(contractAddress, owner, balanceOf(contractAddress));
        }



}

