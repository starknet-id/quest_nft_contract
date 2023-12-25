#[starknet::contract]
mod QuestNft {
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;
    use openzeppelin::access::ownable::interface::IOwnable;
    use quest_nft_contract::interface::IQuestNFT;
    use starknet::{ContractAddress, ClassHash, get_caller_address, get_block_timestamp};
    use openzeppelin::{
        account, access::ownable::OwnableComponent,
        upgrades::{UpgradeableComponent, interface::IUpgradeable},
        token::erc721::{
            ERC721Component, erc721::ERC721Component::InternalTrait as ERC721InternalTrait
        },
        introspection::{src5::SRC5Component, dual_src5::{DualCaseSRC5, DualCaseSRC5Trait}}
    };
    use core::pedersen::pedersen;
    use ecdsa::check_ecdsa_signature;
    use custom_uri::{interface::IInternalCustomURI, main::custom_uri_component};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: custom_uri_component, storage: custom_uri, event: CustomUriEvent);


    // add an owner
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly =
        ERC721Component::ERC721MetadataCamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        _completed_tasks: LegacyMap<(felt252, felt252, felt252), bool>,
        _starkpath_public_key: felt252,
        contract_uri: LegacyMap<felt252, felt252>,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        custom_uri: custom_uri_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        onMint: on_mint,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        CustomUriEvent: custom_uri_component::Event
    }

    #[derive(Drop, Serde)]
    struct Task {
        quest_id: felt252,
        task_id: felt252,
        user_addr: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct on_mint {
        timestamp: u64,
        #[key]
        address: ContractAddress,
        #[key]
        task_id: felt252,
        #[key]
        quest_id: felt252
    }


    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        token_uri_base: Span<felt252>,
        contract_uri: Span<felt252>,
        starkpath_public_key: felt252,
        full_name: felt252,
        short_name: felt252
    ) {
        self.ownable.initializer(owner);
        self.set_contract_uri(contract_uri);
        self._starkpath_public_key.write(starkpath_public_key);
        self.erc721.initializer(full_name, short_name);
        self.custom_uri.set_base_uri(token_uri_base);
    }

    #[external(v0)]
    impl QuestNft of IQuestNFT<ContractState> {
        fn mint(
            ref self: ContractState,
            tokenId: u256,
            quest_id: felt252,
            task_id: felt252,
            sig: (felt252, felt252)
        ) {
            let caller = get_caller_address();

            // bind user, quest and reward together
            let hashed = pedersen(
                pedersen(
                    pedersen(pedersen(tokenId.low.into(), tokenId.high.into()), quest_id), task_id
                ),
                caller.into()
            );

            // ensure the mint has been whitelisted by starkpath
            let starkpath_public_key = self._starkpath_public_key.read();
            let (r, s) = sig;
            assert(
                check_ecdsa_signature(hashed, starkpath_public_key, r, s) == true,
                'invalid signature'
            );

            // check if this task has been completed
            let is_blacklisted = self._completed_tasks.read((quest_id, task_id, caller.into()));
            assert(is_blacklisted == false, 'blacklisted task');

            // blacklist that reward
            self.erc721._mint(caller, tokenId);
            self._completed_tasks.write((quest_id, task_id, caller.into()), true);
            // emit event
            self
                .emit(
                    Event::onMint(
                        on_mint {
                            timestamp: get_block_timestamp(),
                            address: caller,
                            task_id: task_id,
                            quest_id: quest_id,
                        }
                    )
                );
        }

        fn get_tasks_status(self: @ContractState, mut tasks: Span<Task>) -> Array<bool> {
            let mut output = ArrayTrait::new();
            loop {
                match tasks.pop_front() {
                    Option::Some(current_task) => {
                        output
                            .append(
                                self
                                    ._completed_tasks
                                    .read(
                                        (
                                            *current_task.quest_id,
                                            *current_task.task_id,
                                            *current_task.user_addr
                                        )
                                    )
                            );
                    },
                    Option::None => { break; }
                }
            };
            output
        }

        fn getTokenURI(self: @ContractState, tokenId: u256) -> Array<felt252> {
            self.custom_uri.get_uri(tokenId)
        }

        fn getContractURI(self: @ContractState) -> Array<felt252> {
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

        fn setBaseTokenURI(ref self: ContractState, token_uri: Span<felt252>) {
            assert(get_caller_address() == self.ownable.owner(), 'you must be admin');
            self.custom_uri.set_base_uri(token_uri);
        }

        fn setContractURI(ref self: ContractState, contractURI: Span<felt252>) {
            assert(get_caller_address() == self.ownable.owner(), 'you must be admin');
            self.set_contract_uri(contractURI);
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable._upgrade(new_class_hash);
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
