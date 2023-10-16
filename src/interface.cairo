use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait IQuestNFT<TContractState> {
    fn tokenURI(self: @TContractState, tokenId: u256) -> Array<felt252>;

    fn contractURI(self: @TContractState) -> Array<felt252>;

    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
