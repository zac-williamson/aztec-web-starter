use dep::aztec::macros::aztec;


#[aztec]
pub contract Counter {
    use aztec::macros::{functions::{initializer, private, utility}, storage::storage};
    use aztec::prelude::{AztecAddress, Map};
    use aztec::protocol_types::traits::ToField;
    use easy_private_state::EasyPrivateUint;
    use value_note::balance_utils;

    #[storage]
    struct Storage<Context> {
        counters: Map<AztecAddress, EasyPrivateUint<Context>, Context>,
    }

    #[initializer]
    #[private]
    fn initialize(headstart: u64) {
        let counters = storage.counters;
        let sender = context.msg_sender();
        counters.at(sender).add(headstart, sender, sender);
    }

    #[private]
    fn increment() {
        let sender = context.msg_sender();
        unsafe {
            dep::aztec::oracle::debug_log::debug_log_format(
                "Incrementing counter for owner {0}",
                [sender.to_field()],
            );
        }
        let counters = storage.counters;
        counters.at(sender).add(1, sender, sender);
    }

    #[utility]
    unconstrained fn get_counter(sender: AztecAddress) -> Field {
        let counters = storage.counters;
        balance_utils::get_balance(counters.at(sender).set)
    }
}
