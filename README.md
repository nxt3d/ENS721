# ENS 721 Registry using ERC721 and Controllers

This registry design uses ERC-721 as the NFT standard. It allows owners of names to upgrade controllers, enabling new features and bug fixes in the future. It is not possible to upgrade the registry to a different NFT standard to ensure all names remain part of the same single NFT collection, even after a name is upgraded to a new controller. The design supports multiple controllers including a root controller and a controller that supports burning fuses similarly to the NameWrapper on L1 Ethereum.

Along with the approval types in ERC-721, the design introduces a new type of approval — operator approvals limited to single tokens. It is also possible to clear all operator token approvals with a single function call. However, the registry's use of ERC-721 deviates from the standard by reverting all calls to balanceOf. ENS does not use this function in the protocol, and implementing it would waste gas.

When considering the differences between ERC-1155 and ERC-721, there are several advantages to ERC-721. The first advantage is that ERC-721 includes "unsafe" transfer functions, saving gas whenever a name is transferred or when creating a subname. ERC-721 is also an older, more established NFT standard, and natively includes an ownerOf() function, which is necessary for the ENS protocol.

It is also possible to limit safe transfers, which could be used in reentrancy attacks. For additional safety, the registry allows for pausing all safe transfer functions, leaving "unsafe" transfers as immutable methods. Safe transfer methods can potentially be exploited in reentrancy attacks, including not just reentrancy into the same contract but reentrancy across contracts as well.

Currently, the ENS 721 Registry is in an early stage of development, with significant parts of the code uncompleted, missing tests, and the code is un-audited. The code is open source, and issues and pull requests are welcome.