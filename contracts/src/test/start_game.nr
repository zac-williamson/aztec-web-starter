use crate::test::utils;
use dep::aztec::{
    oracle::{execution::get_block_number, storage::storage_read},
    protocol_types::traits::{Deserialize, Serialize},
};
use fog_of_war_chess::GameState;

use crate::ChessContract;
use crate::ChessContract::ContractGameState;

#[test]
unconstrained fn test_serde() {
    let contract_game_state =
        ContractGameState { game_state: GameState::default(), black_initialized: false };
    let serialized = contract_game_state.serialize();
    let deserialized: ContractGameState = ContractGameState::deserialize(serialized);
    assert(
        contract_game_state == deserialized,
        "Deserialized game state should match the original",
    );
}

#[test]
unconstrained fn test_initializer() {
    let (_, chess_contract_address, _admin) = utils::setup();

    let block_number = get_block_number();
    let counter_slot = ChessContract::storage_layout().counter.slot;
    let counter_storage_value = storage_read(chess_contract_address, counter_slot, block_number);
    assert(counter_storage_value == 1, "Counter storage value should be one after initialization");
}
