pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

/**
 * Extremely simple, NOT FOR PRODUCTION, simulation for supply chain shipment notifications. 
 * 
 * The mock shipment scenario is that there are several shipping center locations registered as "suppliers". 
 * Each supplier is registered by the authority that owns this contract. Suppliers record receipt of shipment
 * to show progress along a route to a final destination. 
 * 
 * Anyone can witness seeing a package along the route to verify that a supplier did, in fact, receive shipment. 
 * Obviously the more witnesses there are, the more credible the supplier record. Witnesses can only witness a shipment 
 * once for any item.
 * 
 * There are many holes in this scenario and should never be used for real world shipment tracking. 
 * Some things that are glossed over or missing in this contract:
 *    - Shipment details would need to be recorded first, including expected checkpoints along a route
 *    - Supplier checkpoints would probably stake ETH or tokens as insurance that they are accurately recording shipment receipts 
 *    - While witnesses could be used to slash a supplier's stack, they could be gamed through a sybil attack in collusion with a supplier
 *    - An obvious verification check would be a supplier later in the route recording receipt. The previous supplier not having recorded shipment
 *      could be slashed in that case. Suppliers, however, could collude to avoid slashing.
 */
contract SupplyChainDemo {
    
    bytes32 constant NULL = "";
    
    //emitted when a new supplier address is registered
    event SupplierRegistered(uint256 supplierID, address supplier, string details);
    
    //emitted when a supplier receives shipment 
    event ShipmentReceived(uint256 indexed itemID,  address indexed receiver, bytes32 hash, string metadata);
    
    //emitted when anyone witnesses receipt of shipment along a supply route
    event ShipmentWitnessed(uint256 indexed itemID, uint256 supplierID, bytes32 witnessNameHash);
    
 
    //contract owner
    address public owner;
    
    //unique ID for each supplier
    uint256 supplierID;
    
    //record for a specific supplier.
    struct SupplierRecord {
        bytes32 supplierMetadata;
        uint256 witnessCount;
    }
    
    //record from a witness for a specific supplier
    struct WitnessRecord {
        bytes32 nameHash;
        uint256 supplier;
    }
    
    //record of shipment receipt
    struct ShipmentTracking {
        
        //information for each supplier
        mapping(uint256 => SupplierRecord) supplierRecords;
        
        //record that a particular address witnessed receipt from a supplier. Addresses can only witness once.
        //This is open to sybil attack.
        mapping(address => WitnessRecord) witnessRecords;
    }
    
    
    //suppliers keyed by their public address
    mapping(address => uint256) public suppliersByAddress;
    
    //all shipment metadata received keyted by itemID
    mapping(uint256 => ShipmentTracking) receivedShipments;
    
    
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
        ShipmentTracking storage history = receivedShipments[itemID];
        SupplierRecord storage rec = history.supplierRecords[supplier];
        
        require(rec.supplierMetadata == NULL, "Shipment already received by supplier");
        rec.supplierMetadata = hash;
        emit ShipmentReceived(itemID, msg.sender, hash, metadata);
    }
    
    /**
     * Witness the receipt of shipment by a supplier 
     */
    function witnessShipment(uint256 itemID, uint256 _supplierID, bytes32 witnessNameHash) public {
        ShipmentTracking storage history = receivedShipments[itemID];
        WitnessRecord storage wit = history.witnessRecords[msg.sender];
        require(wit.nameHash == NULL, "Witness already registered for item");
        SupplierRecord storage rec = history.supplierRecords[_supplierID];
        rec.witnessCount++;
        wit.nameHash = witnessNameHash;
        wit.supplier = _supplierID;
        emit ShipmentWitnessed(itemID, _supplierID, witnessNameHash);
    }
    
    /**
     * Get any recorded metadata for a shipment by a supplier 
     */
    function getSupplierMetadata(uint256 itemID, uint256 _supplierID) public view returns(bytes32) {
        ShipmentTracking storage history = receivedShipments[itemID];
        SupplierRecord storage rec = history.supplierRecords[_supplierID];
        return rec.supplierMetadata;
    }
    
    /**
     * Get number of witnesses for a shipment and supplier 
     */
    function getSupplierWitnessCount(uint256 itemID, uint256 _supplierID) public view returns(uint256) {
        ShipmentTracking storage history = receivedShipments[itemID];
        SupplierRecord storage rec = history.supplierRecords[_supplierID];
        return rec.witnessCount;
    }
    
    /**
     * Get recorded witness data for an item and specific witness address.
     */
    function getWitnessInfo(uint256 itemID, address witness) public view returns(bytes32, uint256) {
        ShipmentTracking storage history = receivedShipments[itemID];
        WitnessRecord storage rec = history.witnessRecords[witness];
        return (rec.nameHash, rec.supplier);
    }
}