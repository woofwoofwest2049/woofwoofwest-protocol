// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IBaby {
    struct WoofBaby {
        uint8 gender;   //0: Male, 1: Female
        uint8 race;     //0: Dog, 1: Cat
        uint8 quality; 
        uint8 feedCount;
        uint32 lastFeedTime;
        uint32 tokenId;
        uint16[3] woofMintProbability;
    }

    function mint(address _account, uint32 _woofTokenId) external returns(uint32 _babyTokenId);
    function burn(uint32 _tokenId) external;
    function updateTokenTraits(WoofBaby memory _w) external;
    function getTokenTraits(uint256 _tokenId) external view returns (WoofBaby memory);
}