#[starknet::contract]
mod Identity {
    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[constructor]
    fn constructor(ref self: ContractState) {}
}
