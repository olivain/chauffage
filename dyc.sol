pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

contract OCB {
  address owner;
  uint public nbVoters = 0;

  uint public nbProposals = 0;
  uint public voteDuration = 100; // 20 block * 3s = 1mn
  address[] public votersAddresses;

 uint private PROPOSAL_VOTERS_TYPE = 1;
 uint private PROPOSAL_TEMP_TYPE = 2;


  struct Proposal {
    uint id;
    address proposerAddress;
    uint startingTimestamp;
    uint endingTimestamp;
    uint endingBlock;
    uint genre;
    bool executed;
  }

  struct VoterProposal {
    uint id;
    address proposerAddress;
    address concernedAddress;
    bool voterProposalType; // remove (false) or add (true) ?
    uint endingBlock;
    uint nbVotes;
    uint nbVotesAgree;
    uint nbVotesDisagree;
    bool accepted;
  }

struct StateProposal {
    uint id;
    address proposerAddress;
    uint startingTimestamp;
    uint endingTimestamp;
    uint temperatureCelsius;
    uint endingBlock;
    uint nbVotes;
    uint nbVotesAgree;
    uint nbVotesDisagree;
    bool accepted;
}

struct VoterParams {
  bool auth;
  uint authblock;
}

struct Calendar{
  uint id;
  uint startingTime;
  uint endingTime;
}


//////////////////////////:

event NewVoterProposal (
    uint id,
    address proposerAddress,
    address concernedAddress,
    bool removeOrAdd,
    uint endingBlock
);

event NewStateProposal (
    uint id,
    address proposerAddress,
    uint startingTimestamp,
    uint endingTimestamp,
    uint temperature,
    uint endingBlock
);


  event NewProposal(
    uint id,
    uint blocknb,
    string content,
    bool completed
  );

///////////////////////////

  mapping(uint => Proposal) public proposal;
  mapping(uint => StateProposal) public stateproposal;
  mapping(uint => VoterProposal) public voterproposal;
  mapping(address => VoterParams) public voters;
  mapping(address => uint) public lastVoteByUser;
  mapping(uint => Calendar) public calendar;

  /////////////////

  modifier onlyOwner {
      require(msg.sender == owner);
      _;
   }

  modifier onlyVoter {
      require(voters[msg.sender].auth == true);
      _;
   }

  constructor() public {
    owner = msg.sender;
    address deadaddress = 0x0000000000000000000000000000000000000001;
    // we need to be two to start voting !
    voters[owner] = VoterParams(true, 0);
    voters[deadaddress] = VoterParams(true, 0);
    nbVoters+=2;

    // proposal 0
    proposal[nbProposals] = Proposal(nbProposals, msg.sender, 1, 2, 0, PROPOSAL_TEMP_TYPE, false);
    stateproposal[nbProposals] = StateProposal(nbProposals, msg.sender, 1, 2, 0, 0, 0, 0, 0, false);
    executeProposal(nbProposals);
  }

  ////////////////////////
  
  
  function getLastProposalId() public view returns(uint){
  	return nbProposals;
  }

  function getProposalType(uint id) public view returns(uint) {
    if (proposal[id].genre == PROPOSAL_TEMP_TYPE || proposal[id].genre == PROPOSAL_VOTERS_TYPE) {
      return proposal[id].genre;
    } else {
      revert("this proposal does not exists");
    }
  }

  function getNumbersOfVoters() public view returns(uint nb){
    return nbVoters;
  }

  function getLastVoteForUser(address who) public view returns(uint){
    return lastVoteByUser[who];
  }

  function getTempProposal(uint id) public view returns(StateProposal memory) {
    return stateproposal[id];
  }

  function getVoterProposal(uint id) public view returns(VoterProposal memory) {
    return voterproposal[id];
  }

  function addVoter(address addy, uint bn) private {
     voters[addy].auth = true;
     voters[addy].authblock = bn;
  }

 function removeVoter(address addy, uint bn) private {
    voters[addy].auth = false;
     voters[addy].authblock = bn;
  }

  function createStateProposal(uint starting, uint ending, uint temp) public onlyVoter {
    require(proposal[nbProposals].endingBlock < block.number, "le dernier vote n'est pas termine"); // last vote must be over
    require(proposal[nbProposals].executed==true, "le dernier vote n'a pas ete enregistre");

    nbProposals++;
    uint endingblock = block.number + voteDuration;
    proposal[nbProposals] = Proposal(nbProposals, msg.sender, starting, ending, endingblock, PROPOSAL_TEMP_TYPE, false);
    stateproposal[nbProposals] = StateProposal(nbProposals, msg.sender, starting, ending, temp, endingblock, 0, 0, 0, false);

    emit NewStateProposal(nbProposals, msg.sender, starting, ending, temp, endingblock);
  }


  function createVoterProposal(address voteraddress, bool removeOrAdd) public onlyVoter {
    require(proposal[nbProposals].endingBlock < block.number, "le dernier vote n'est pas termine"); // last vote must be over
    require(voters[voteraddress].auth != removeOrAdd, "address is already set to required value"); // address is not already set to the proposed value
    require(proposal[nbProposals].executed==true, "le dernier vote n'a pas ete enregistre");

    nbProposals++;
    uint endingblock = block.number + voteDuration;
    proposal[nbProposals] = Proposal(nbProposals, msg.sender, 0, 0, endingblock, PROPOSAL_VOTERS_TYPE, false);
    voterproposal[nbProposals] = VoterProposal(nbProposals, msg.sender, voteraddress, removeOrAdd, endingblock, 0, 0, 0, false);

    if(removeOrAdd == true) {
      addVoter(voteraddress,endingblock);
    } else if(removeOrAdd == false) {
      removeVoter(voteraddress,endingblock);
    } 
    
    emit NewVoterProposal(nbProposals, msg.sender, voteraddress, removeOrAdd, endingblock);
  }


  function voteForProposal(uint id, bool vote) public onlyVoter {
    require(proposal[id].endingBlock > block.number, "trop tard ! le vote est deja ferme");
    require(lastVoteByUser[msg.sender] < id, "Non ! vous avez deja vote pour cette proposition");
    require(proposal[id].executed==false, "le dernier vote a deja ete execute!");

    if(proposal[id].genre == PROPOSAL_TEMP_TYPE) {

      if(vote==true) {
         stateproposal[id].nbVotesAgree += 1;
      } else if(vote==false) {
         stateproposal[id].nbVotesDisagree += 1;
      }
      
      stateproposal[id].nbVotes +=1;


    } else if(proposal[id].genre == PROPOSAL_VOTERS_TYPE) {

      if(vote==true) {
         voterproposal[id].nbVotesAgree += 1;
      } else if(vote==false) {
         voterproposal[id].nbVotesDisagree += 1;
      }
    voterproposal[id].nbVotes+=1;

    }

    lastVoteByUser[msg.sender] = id;
    
  }

  function executeProposal(uint id) public {

    require(proposal[id].executed == false, "le vote a deja ete execute");
    require(proposal[id].endingBlock < block.number, "le vote n'est pas encore termine.");
    
    uint fiftyPercent = nbVoters/2; // une division de int est toujours arrondie au superieur avec Solidity (pas de float autorise)

    if(proposal[id].genre == PROPOSAL_VOTERS_TYPE){ // vote pr la gestion des voteurs

        address addy = voterproposal[id].concernedAddress; // addresse concernee

          if(voterproposal[id].nbVotes >= fiftyPercent) { // au moins la moitie des voteurs ont vote

              if(voterproposal[id].nbVotesAgree > voterproposal[id].nbVotesDisagree){
                
                if(voterproposal[id].voterProposalType == false) {//retirer une addy de la liste
                      voters[addy].auth = false;
                      nbVoters-=1;
                  } else  if(voterproposal[id].voterProposalType == true) {//retirer une addy de la liste
                      voters[addy].auth = true;
                      nbVoters+=1;
                  }

                  voterproposal[id].accepted = true;
              } else if(voterproposal[id].nbVotesAgree <= voterproposal[id].nbVotesDisagree){
                  voters[addy].auth = false;
                  voterproposal[id].accepted = false;
              }

          } else { // not enough voters
              stateproposal[id].accepted = false;
            }
          
        } else if(proposal[id].genre == PROPOSAL_TEMP_TYPE) {

              if(stateproposal[id].nbVotes >= fiftyPercent) {

                if(stateproposal[id].nbVotesAgree > stateproposal[id].nbVotesDisagree){
                  stateproposal[id].accepted = true;
                } else if(stateproposal[id].nbVotesAgree <= stateproposal[id].nbVotesDisagree){
                  stateproposal[id].accepted = false;
                }
            } else { // not enough voters
              stateproposal[id].accepted = false;
            }
        }

    proposal[id].executed = true;
  }

function getContractOwner() public view returns (address) {
    return owner;
  }
  

}
