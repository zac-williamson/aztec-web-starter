use crate::test::utils;
use dep::aztec::oracle::{execution::get_block_number, storage::storage_read};
use dep::aztec::protocol_types::storage::map::derive_storage_slot_in_map;

use crate::ChessContract;


#[test]
unconstrained fn test_initializer() {
    let (_, voting_contract_address, admin) = utils::setup();

    let block_number = get_block_number();
    let counter_slot = ChessContract::storage_layout().counter.slot;
    let counter_storage_value = storage_read(voting_contract_address, counter_slot, block_number);
    assert(counter_storage_value == 1, "Vote ended should be false");
}