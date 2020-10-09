import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./Destroyable.sol";

pragma solidity ^0.5.12;

contract AngryBirds is Ownable, Destroyable, IERC721, IERC721Receiver {

    using SafeMath for uint256;

    uint256 public constant maxGen0Birds = 16;
    uint256 public gen0Counter = 0;

    bytes4 internal constant _ERC721Checksum = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    //checksum used to determine if a receiving contract is able to handle ERC721 tokens
    bytes4 private constant _InterfaceIdERC721 = 0x80ac58cd;
    //checksum of function headers that are required in standard interface
    bytes4 private constant _InterfaceIdERC165 = 0x01ffc9a7;
    //checksum of function headers that are required in standard interface

    string private _name;
    string private _symbol;

    struct Bird {
        uint256 genes;
        uint64 birthTime;
        uint32 mumId;
        uint32 dadId;
        uint16 generation;
    }

    Bird[] birdies;

    mapping(uint256 => address) public birdOwner;
    mapping(address => uint256) ownsNumberOfTokens;
    mapping(uint256 => address) public _approval;//which bird is approved to be transfered by an address other than the owner
    mapping(address => mapping (address => bool)) private _operatorApprovals;//approval to handle all tokens of an address by another
    //_operatorApprovals[owneraddress][operatoraddress] = true/false;

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    event Birth(address owner, uint256 birdId, uint256 mumId, uint256 dadId, uint256 genes);

    constructor(string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
    }

    function breed(uint256 _dadId, uint256 _mumId) public returns (uint256){
        require(birdOwner[_dadId] == msg.sender && birdOwner[_mumId] == msg.sender);
        uint256 _newDna = _mixDna(_dadId, _mumId);
        uint256 _newGeneration;
        if (birdies[_dadId].generation <= birdies[_mumId].generation) {
            _newGeneration = birdies[_dadId].generation;
        } else {
            _newGeneration = birdies[_mumId].generation;
        }
        _newGeneration = _newGeneration.add(1);
        return _createBird(_mumId, _dadId, _newGeneration, _newDna, msg.sender);
    }

    function supportsInterface(bytes4 _interfaceId) external pure returns (bool) {
        return (_interfaceId == _InterfaceIdERC721 || _interfaceId == _InterfaceIdERC165);
    }

    function createBirdGen0(uint256 genes) public onlyOwner returns (uint256) {
        require(gen0Counter <= maxGen0Birds, "Maximum number of Birds is reached. No new birds allowed!");
        gen0Counter = gen0Counter.add(1);
        return _createBird(0, 0, 0, genes, msg.sender);
    }

    function _createBird(
        uint256 _mumId,
        uint256 _dadId,
        uint256 _generation,
        uint256 _genes,
        address _owner
    ) internal returns (uint256) {
        Bird memory _bird = Bird({
            genes: _genes,
            birthTime: uint64(now),
            mumId: uint32(_mumId),  //easier to input 256 and later convert to 32.
            dadId: uint32(_dadId),
            generation: uint16(_generation)
        });
        uint256 newBirdId = birdies.push(_bird).sub(1);//want to start with zero.
        emit Birth(_owner, newBirdId, _mumId, _dadId, _genes);
        _transfer(address(0), _owner, newBirdId);//transfer from nowhere. Creation event.
        return newBirdId;
    }

    function getBird(uint256 tokenId) external view returns (
        uint256 genes,
        uint256 birthTime,
        uint256 mumId,
        uint256 dadId,
        uint256 generation) //code looks cleaner when the params appear here vs. in the return statement.
        {
            require(tokenId < birdies.length, "Token ID doesn't exist.");
            Bird storage bird = birdies[tokenId];//saves space over using memory, which would make a copy
            
            genes = bird.genes;
            birthTime = uint256(bird.birthTime);
            mumId = uint256(bird.mumId);
            dadId = uint256(bird.dadId);
            generation = uint256(bird.generation);
        }

    function getAllBirdsOfOwner(address owner) external view returns(uint256[] memory) {
        uint256[] memory allBirdsOfOwner = new uint[](ownsNumberOfTokens[owner]);
        uint256 j = 0;
        for (uint256 i = 0; i < birdies.length; i++) {
            if (birdOwner[i] == owner) {
                allBirdsOfOwner[j] = i;
                j = j.add(1);
            }
        }
        return allBirdsOfOwner;
    }

    function balanceOf(address owner) external view returns (uint256 balance) {
        return ownsNumberOfTokens[owner];
    }

    function totalSupply() external view returns (uint256 total) {
        return birdies.length;
    }

    function name() public view returns (string memory){
        return _name;
    }

    function symbol() public view returns (string memory){
        return _symbol;
    }

    function ownerOf(uint256 tokenId) external view returns (address owner) {
        require(tokenId < birdies.length, "Token ID doesn't exist.");
        return birdOwner[tokenId];
    }

    function transfer(address to, uint256 tokenId) external {
        require(to != address(0), "Use the burn function to burn tokens!");
        require(to != address(this), "Wrong address, try again!");
        require(birdOwner[tokenId] == msg.sender);
        _transfer(msg.sender, to, tokenId);
    }

    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        ownsNumberOfTokens[_to] = ownsNumberOfTokens[_to].add(1);
        birdOwner[_tokenId] = _to;
        
        if (_from != address(0)) {
            ownsNumberOfTokens[_from] = ownsNumberOfTokens[_from].sub(1);
            delete _approval[_tokenId];//when owner changes, approval must be removed.
        }

        emit Transfer(_from, _to, _tokenId);
    }

    function approve(address _approved, uint256 _tokenId) external {
        require(birdOwner[_tokenId] == msg.sender || _operatorApprovals[birdOwner[_tokenId]][msg.sender] == true, "You are not authorized to access this function.");
        _approval[_tokenId] = _approved;
        emit Approval(msg.sender, _approved, _tokenId);
    }

    function setApprovalForAll(address _operator, bool _approved) external {
        require(_operator != msg.sender);
        _operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function getApproved(uint256 _tokenId) external view returns (address) {
        require(_tokenId < birdies.length, "Token doesn't exist");
        return _approval[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return _operatorApprovals[_owner][_operator];
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        require(_from == msg.sender || _approval[_tokenId] == msg.sender || _operatorApprovals[_from][_to], "You are not authorized to use this function");
        require(birdOwner[_tokenId] == _from, "Owner incorrect.");
        require(_to != address(0), "Error: Operation would delete this token permanently");
        require(_tokenId < birdies.length, "Token doesn't exist");
        _transfer(_from, _to, _tokenId);
    }
    function _safeTransfer(address _from, address _to, uint256 _tokenId, bytes memory _data) internal {
        require(_checkERC721Support(_from, _to, _tokenId, _data));
        _transfer(_from, _to, _tokenId);
    }
    
    function _checkERC721Support(address _from, address _to, uint256 _tokenId, bytes memory _data) internal returns(bool) {
        if(!_isContract(_to)) {
            return true;
        }

        bytes4 returnData = IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
        //Call onERC721Received in the _to contract
        return returnData == _ERC721Checksum;
        //Check return value
    }

    function _isContract(address _to) internal view returns (bool) {
        uint32 size;
        assembly{
            size := extcodesize(_to)
        }
        return size > 0;
        //check if code size > 0; wallets have 0 size.
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) public {
        require(_from == msg.sender || _approval[_tokenId] == msg.sender || _operatorApprovals[_from][_to], "You are not authorized to use this function");
        require(birdOwner[_tokenId] == _from, "Owner incorrect.");
        require(_to != address(0), "Error: Operation would delete this token permanently");
        require(_tokenId < birdies.length, "Token doesn't exist");
        _safeTransfer(_from, _to, _tokenId, _data);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public {
        safeTransferFrom(_from, _to, _tokenId, "");
    }

    function _mixDna(uint256 _dadDna, uint256 _mumDna) internal pure returns (uint256){
        //11 22 33 44 55 66 77 88 (dad)
        //88 77 66 55 44 33 22 11 (mum)

        uint256 firstHalf = _dadDna / 100000000; //11 22 33 44
        uint256 secondHalf = _mumDna % 100000000; //44 33 22 11
        return (firstHalf * 100000000) + secondHalf; //11 22 33 44 44 33 22 11
    }

}