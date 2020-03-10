pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

/**
 * Extremely simple, NOT FOR PRODUCTION, simulation for supply chain shipment notifications. 
 */
contract SupplyChainDemo {
    
    //emitted when a new supplier address is registered
    event SupplierRegistered(uint256 supplierID, address supplier, string details);
    
    //emitted when a supplier receives shipment 
    event ShipmentReceived(uint256 indexed itemID,  address indexed receiver, bytes32 hash, string metadata);
    
    
    //contract owner
    address public owner;
    
    //unique ID for each supplier
    uint256 supplierID;
    
    //suppliers keyed by their public address
    mapping(address => uint256) public suppliersByAddress;
    
    //all shipment metadata received
    mapping(uint256 => mapping(uint256 => bytes32)) public receivedShipments;
    
    //create contract 
    constructor() public {
        owner = msg.sender;
        addSupplier(msg.sender, "owner");
    }
    
    
    //only allowed if a registered supplier calls function
    modifier onlySuppliers() {
        if(suppliersByAddress[msg.sender] != 0x0 || msg.sender == owner) _;
    }
    
    //only allowed by contract owner
    modifier ownerOnly() {
        if(msg.sender == owner) _;
    }
    
    
    /**
     * Authorize a supplier address so they can record shipment details 
     */
    function addSupplier(address supplier, string memory details) public ownerOnly {
        uint256 id = supplierID + 1;
        supplierID++;
        suppliersByAddress[supplier] = id;
        emit SupplierRegistered(id, supplier, details);
    }
    
    /**
     * Record shipment details. Only suppliers can call this function
     */
    function recordShipmentReceived(uint256 itemID, string memory metadata) public {
        require(msg.sender == owner || suppliersByAddress[msg.sender] != 0x0, "Unauthorized to record shipments");
        
        bytes32 hash = keccak256(bytes(metadata));
        uint256 supplier = suppliersByAddress[msg.sender];
        mapping(uint256 => bytes32) storage history = receivedShipments[itemID];
        require(history[supplier] == 0x0, "Shipment already received by supplier");
        history[supplier] =  hash;
        //receivedShipments[itemID] = history;
        emit ShipmentReceived(itemID, msg.sender, hash, metadata);
    }
}