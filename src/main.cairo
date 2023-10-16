#[starknet::contract]
mod QuestNft {
    use openzeppelin::token::erc20::interface::{
        IERC20Camel, IERC20CamelDispatcher, IERC20CamelDispatcherTrait
    };
    use starknet::{get_caller_address, ContractAddress, class_hash::ClassHash};
    use custom_uri::{interface::IInternalCustomURI, main::custom_uri_component};
    use quest_nft_contract::interface::IQuestNFT;

    #[storage]
    struct Storage {
        _completed_tasks: LegacyMap<(felt252, felt252, felt252), bool>,
        _starkpath_public_key: felt252,
        Proxy_admin: ContractAddress,
        #[substorage(v0)]
        custom_uri: custom_uri_component::Storage,
        contract_uri: LegacyMap<felt252, felt252>,
        ERC721_name: felt252,
        ERC721_symbol: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CustomUriEvent: custom_uri_component::Event
    }

    component!(path: custom_uri_component, storage: custom_uri, event: CustomUriEvent);

    #[constructor]
    fn constructor(
        ref self: ContractState,
        proxy_admin: ContractAddress,
        token_uri_base: Span<felt252>,
        contract_uri: Span<felt252>,
        starkpath_public_key: felt252,
        full_name: felt252,
        short_name: felt252
    ) {
        self.Proxy_admin.write(proxy_admin);
        self.custom_uri.set_base_uri(token_uri_base);
        self.set_contract_uri(contract_uri);
        self._starkpath_public_key.write(starkpath_public_key);
        self.ERC721_name.write(full_name);
        self.ERC721_symbol.write(short_name);
    }

    #[external(v0)]
    impl QuestNFTImpl of IQuestNFT<ContractState> {
        fn tokenURI(self: @ContractState, tokenId: u256) -> Array<felt252> {
            self.custom_uri.get_uri(tokenId)
        }

        fn contractURI(self: @ContractState) -> Array<felt252> {
            let mut output = ArrayTrait::new();
            let mut i = 0;
            loop {
                let value = self.contract_uri.read(i);
                if value == 0 {
                    break;
                };
                output.append(value);
                i += 1;
            };
            output
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(get_caller_address() == self.Proxy_admin.read(), 'you are not admin');
            // todo: use components
            assert(!new_class_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(new_class_hash).unwrap();
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn set_contract_uri(ref self: ContractState, mut uri: Span<felt252>) {
            // writing end of text
            self.contract_uri.write(uri.len().into(), 0);
            loop {
                match uri.pop_back() {
                    Option::Some(value) => { self.contract_uri.write(uri.len().into(), *value); },
                    Option::None => { break; }
                }
            };
        }
    }
}
