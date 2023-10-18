use array::ArrayTrait;
use core::result::ResultTrait;
use option::OptionTrait;
use starknet::{class_hash::Felt252TryIntoClassHash, ContractAddress, SyscallResultTrait};
use traits::TryInto;
use quest_nft_contract::main::QuestNft;
use quest_nft_contract::main::QuestNft::{_completed_tasksContractMemberStateTrait, Task};
use quest_nft_contract::interface::{IQuestNFT, IQuestNFTDispatcher, IQuestNFTDispatcherTrait};
use core::pedersen::pedersen;
use starknet::testing::set_contract_address;

fn deploy(contract_class_hash: felt252, calldata: Array<felt252>) -> ContractAddress {
    let (address, _) = starknet::deploy_syscall(
        contract_class_hash.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap_syscall();
    address
}


fn deploy_contract() -> IQuestNFTDispatcher {
    let mut calldata = array![
        0x123,
        1,
        'http://yolo?id=',
        1,
        'http://yala?id=',
        874739451078007766457464989774322083649278607533249481151382481072868806602,
        'full_name',
        'short',
    ];
    let address = deploy(QuestNft::TEST_CLASS_HASH, calldata);
    IQuestNFTDispatcher { contract_address: address }
}

#[test]
#[available_gas(20000000000)]
fn test_mint() {
    let quest_nft = deploy_contract();
    let token_id: u256 = 1;
    let pub_key_1 = 874739451078007766457464989774322083649278607533249481151382481072868806602;
    set_contract_address(123.try_into().unwrap());
    let (sig_0, sig_1) = (
        2061100561337407258774041771048745591157440934673706922839075200678408277171,
        3170900588566687338732601937828001176165928386276170643990531992121520989722
    );

    quest_nft.mint(token_id, 1, 1, (sig_0, sig_1));
}

#[test]
#[available_gas(20000000000)]
fn test_get_tasks_status() {
    let mut unsafe_state = QuestNft::unsafe_new_contract_state();
    unsafe_state._completed_tasks.write((1, 2, 3), true);
    unsafe_state._completed_tasks.write((4, 5, 6), false);
    unsafe_state._completed_tasks.write((7, 8, 9), true);
    let tasks_status = QuestNft::QuestNFTImpl::get_tasks_status(
        @unsafe_state,
        array![
            Task { quest_id: 1, task_id: 2, user_addr: 3 },
            Task { quest_id: 4, task_id: 5, user_addr: 6 },
            Task { quest_id: 7, task_id: 8, user_addr: 9 }
        ]
            .span()
    );
    assert(tasks_status == array![true, false, true], 'incorrect tasks status');
}
