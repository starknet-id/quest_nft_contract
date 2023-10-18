use starknet::{ContractAddress, ClassHash};
use quest_nft_contract::main::QuestNft::Task;

#[starknet::interface]
trait IQuestNFT<TContractState> {
    fn mint(
        ref self: TContractState,
        tokenId: u256,
        quest_id: felt252,
        task_id: felt252,
        sig: (felt252, felt252)
    );

    fn get_tasks_status(self: @TContractState, tasks: Span<Task>) -> Array<bool>;

    fn tokenURI(self: @TContractState, tokenId: u256) -> Array<felt252>;

    fn contractURI(self: @TContractState) -> Array<felt252>;

    fn setBaseTokenURI(ref self: TContractState, tokenURI: Span<felt252>);

    fn setContractURI(ref self: TContractState, contractURI: Span<felt252>);

    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
