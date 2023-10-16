use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait IQuestNFT<TContractState> {
    fn mint(ref self: TContractState, tokenId: u256, quest_id: felt252, task_id: felt252, sig: (felt252, felt252));

    fn tokenURI(self: @TContractState, tokenId: u256) -> Array<felt252>;

    fn contractURI(self: @TContractState) -> Array<felt252>;

    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
