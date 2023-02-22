//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

contract bimBlockchain {
    // VARIABLES FOR PEERS AND ROLES
    address private Employer;
    address private ARCH_eng;
    address private STRU_eng;
    address private MEP_eng;
    address private KTR;
    address private EndUser;
    uint16 private numPeers = 0;
    bool private isEmployerSet = false;

    struct Peer {                   // struc for peers
        uint16 ID;
        string role;
        bool registered;
        bool authorize_to_approve;
        bool authorize_to_upload;
        bool authorize_to_comment;
    }

    // VARIABLES FOR CHANGE_TRANSACTIONS
    struct changeTXN {              // struc for BIM Change transaction
        uint id;                    // block.number used as ID in this project 
        uint linked_id;
        address owner;              // Originator
        address BIC;                // Ball in Court: Receiver
        string message;
        uint date;
        string CID1;
        string CID2;
        bool isClosed;
    }   

    struct PeerStatus {
        string _peerName;
        uint latest_incoming;
        uint latest_open; 
        uint total_incoming;
        uint total_open; 
    }

    constructor()  {        
        Employer = msg.sender; //who ever deploys this contract will be the Employer
        // register the Employer as 1st Peer
        Peer storage peer = peers[msg.sender];
        peer.role = "Employer"; 
        peer.ID = numPeers +1;
        numPeers +=1;
        peer.registered = true;
        peer.authorize_to_upload = true;
        peer.authorize_to_approve = true;
        peer.authorize_to_comment = true;
        peerList.push(msg.sender);
        Employer = msg.sender;
        isEmployerSet = true;
    }

    mapping (address => Peer) private peers;
    address[] private peerList;

    mapping (uint => changeTXN) private changes;
    uint[] private change_list;
    
    changeTXN private latest_approved_TXN;
    uint[] private list_of_approved_changes;

    uint public test;

    function registerPeer(string memory _role) public {
        require(isEmployerSet,"Employer is NOT registered yet");
        require(msg.sender != Employer, "Employer is already registered");
        require(CheckandSetPeer(_role, msg.sender),"Unknown Role");
        Peer storage peer = peers[msg.sender];
        peer.role = _role; 
        peer.ID = numPeers +1;
        peer.registered = true;
        peer.authorize_to_approve = false; // only employer is authorized to approve
        peer.authorize_to_upload = true;
        peer.authorize_to_comment = true;
        numPeers +=1;
        peerList.push(msg.sender);
    }

    function removePeer(string memory _role) public {
        require(msg.sender == Employer, "Only Employer is authorized to remove peers");
        require(CheckandSetPeer(_role, msg.sender),"Unknown Role");
        peers[getAddressOf(_role)].registered = false;
        peers[getAddressOf(_role)].authorize_to_approve = false;
        peers[getAddressOf(_role)].authorize_to_comment = false;
        peers[getAddressOf(_role)].authorize_to_upload = false;
    }

    function CheckandSetPeer(string memory _role, address _address) private returns (bool) {
    
        if (compareStrings(_role, "Architect")) {
            ARCH_eng = _address;     
            return true;                   
        } else if (compareStrings(_role, "Structure")) {
            STRU_eng = _address;
            return true;
        } else if (compareStrings(_role, "MEP")) {
            MEP_eng = _address;
            return true;
        } else if (compareStrings(_role, "Contractor")) {
            KTR = _address;
            return true;
        } else if (compareStrings(_role, "End-User")) {
            EndUser = _address;
            return true;
        } 
        return false;
    }

    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));                //keccak256 is a hash function
    }

    function getPeers() public view returns (address [] memory) {
        return peerList;
    }

    function getAddressOf(string memory _role) private view returns (address peerAddress) {
        require (isEmployerSet);
        for (uint i; i < peerList.length; i++) {
            if (compareStrings(peers[peerList[i]].role, _role)) {
                return peerList[i];
            }
        }
    }

    function WhoIs(string memory _role) public view returns (Peer memory){
        return peers[getAddressOf(_role)];
    }

    function Upload (string memory _bic, string memory _message, string memory _cid1, string memory _cid2) public { 
        // Check Authorities 
        require(peers[msg.sender].authorize_to_upload,"Not Authorized User");

        // CHeck State
        require(checkStateforUpload(_message));
        
        // Create a design transaction
        changeTXN storage change = changes[block.number];
        change.owner = msg.sender;
        change.BIC = getAddressOf(_bic);
        change.date = block.timestamp;
        change.id = block.number;
        change.message = _message;
        change.CID1 = _cid1;
        change.CID2 = _cid2;
        change.isClosed = false;

        if (compareStrings(_message,"F")){
            change.isClosed = true;
        }

        // Store the change to the change_list
        change_list.push(change.id);
    }

    function Comment (uint _id, string memory _message, string memory _cid1, string memory _cid2) public {
        // Check Authorities 
        require(peers[msg.sender].authorize_to_comment,"Not Authorized User");

        // CHeck State
        require(checkStateforComment(_message));

        // the comment is linked to previously uploaded transaction
        require(changes[_id].id!=0);
        changes[_id].isClosed = true;
        
        // Create new comment-transaction
        changeTXN storage change = changes[block.number];
        change.owner = msg.sender;
        change.linked_id = changes[_id].id;
        change.BIC = changes[_id].owner;
        change.date = block.timestamp;
        change.id = block.number;
        change.message = _message;
        change.CID1 = _cid1;
        change.CID2 = _cid2;
        change.isClosed = true;

        change_list.push(change.id);
    }

    function Approve (uint _id, string memory _message, string memory _cid1, string memory _cid2) public {
        // Check Authorities 
        require(peers[msg.sender].authorize_to_approve,"Not Authorized User");

        // CHeck State
        require(checkStateforApproval(_message));

        // the comment is linked to previously uploaded transaction
        require(changes[_id].id!=0);
        require(compareStrings(changes[_id].message, "G"),"Not Uploaded for Review and Approval");
        changes[_id].isClosed = true;
        
        // Create new comment-transaction
        changeTXN storage change = changes[block.number];
        change.owner = msg.sender;
        change.linked_id = changes[_id].id;
        change.BIC = changes[_id].owner;
        change.date = block.timestamp;
        change.id = block.number;
        change.message = _message;
        change.CID1 = _cid1;
        change.CID2 = _cid2;
        change.isClosed = true;
        change_list.push(change.id);

        if(compareStrings(_message, "A") || compareStrings(_message, "B")){     // in case of approved change
            latest_approved_TXN = change;               //keep a copy of the approved transaction as the latest
            list_of_approved_changes.push(change.id);   //keep the reference (here is block.number) of all approved transactions
        }
    }

    function checkStateforComment(string memory _message) private pure returns (bool) {
        if (compareStrings(_message, "K")) {              // Internal Review: NO Comment
            return true;
        } else if (compareStrings(_message, "L")) {       // Internal Review: Revision Required with Comments
            return true;
        }
        return false;
    }
    function checkStateforApproval(string memory _message) private pure returns (bool) {
        if (compareStrings(_message, "A")) {              // Approve with NO comment
            return true;
        } else if (compareStrings(_message, "B")) {       // Approve with Comment
            return true;
        } else if (compareStrings(_message, "C")) {       // Not Approve - Resubmit with Comments
            return true;
        } else if (compareStrings(_message, "D")) {       // Not Approved - Rejected. New Submission Required.
            return true;
        } 
        return false;
    }
    function checkStateforUpload(string memory _message) private pure returns (bool) {
        if (compareStrings(_message, "F")) {       // for Information 
            return true;
        } else if (compareStrings(_message, "G")) {       // for Review and Approval
            return true;
        } else if (compareStrings(_message, "I")) {       // for Internal Review and Comments 
            return true;
        }
        return false;
    }

    function getRole() public view returns (string memory) {
        require(peers[msg.sender].registered,"Unregistered or deleted peer.");
        return peers[msg.sender].role;
    }

    function getChanges() public view returns (uint[] memory) {
        return change_list;
    }

    function getAllApprovedChanges() public view returns (uint [] memory) {
        return list_of_approved_changes;
    }

    function getLatestApproval() public view returns (changeTXN memory) {
        return latest_approved_TXN;
    }

    function getLatestIncoming() private view returns (uint) {
        uint i = change_list.length-1;
        do  {
            if (changes[change_list[i]].BIC == msg.sender) {
                return change_list[i];
            }
            i--;
        } while (i>=0);
        return 0;
    }

    function getLatestOpen() private view returns (uint) { 
        if (getTotalIncoming()[1] == 0) {
            return 0;
        }
        uint k = change_list.length-1;
        do  {
            if (changes[change_list[k]].BIC == msg.sender && changes[change_list[k]].isClosed == false ) {
                return change_list[k];
            }
            k--;
        } while (k>=0);
        return 0;
    }

    function getTotalIncoming() private view returns (uint[2] memory ) {
    //FOR Forward Search ... 
    uint total_open = 0; 
    uint total_BIC = 0;
        for (uint i=0;i<change_list.length; i++) {
            if (changes[change_list[i]].BIC == msg.sender) {
                total_BIC++;
                if (changes[change_list[i]].isClosed == false) {
                    total_open++;
                }
            }
        } 
        return [total_BIC,total_open];
    }

    function getStatus() public view returns (PeerStatus memory _status) {
        require (change_list.length>0,"No transaction recorded yet.");
        _status._peerName = getRole();
        _status.latest_incoming = getLatestIncoming();
        _status.latest_open = getLatestOpen();
        _status.total_incoming = getTotalIncoming()[0];
        _status.total_open = getTotalIncoming()[1];
        return _status;
    }

    function getNumberofChanges() public view returns (uint) {
        return change_list.length;
    }

    function getChangeID(uint _number) public view returns (uint) {
        return change_list[_number];
    }

    function ShowTXN(uint _id) public view returns (changeTXN memory) {
        require (change_list.length>0,"No transaction recorded yet.");
        return (changes[_id]);
    }
}
