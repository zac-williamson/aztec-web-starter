use dep::aztec::macros::aztec;

mod test;
mod traits;

#[aztec]
pub contract ChessContract {
    use dep::aztec::{
        macros::{functions::{initializer, private, public}, notes::note, storage::storage},
        state_vars::{Map, PublicMutable},
    };
    use fog_of_war_chess::GameState;
    use std::hash::poseidon2::Poseidon2::hash as poseidon2;

    pub struct ContractGameState {
        pub game_state: GameState,
        pub black_initialized: bool,
    }

    impl ContractGameState {
        pub fn hash(self) -> Field {
            poseidon2([self.black_initialized as Field, self.game_state.hash()], 2)
        }
    }

    #[storage]
    struct Storage<Context> {
        counter: PublicMutable<Field, Context>, // used to create game IDs
        pub_game_state: Map<Field, PublicMutable<ContractGameState, Context>, Context>,
    }

    #[public]
    #[initializer]
    fn constructor() {
        storage.counter.write(1);
    }

    // entry point for creating a game. For now creator is always white
    #[private]
    fn create_game_private(encrypt_secret: Field, mask_secret: Field) {
        let secret_hashes: [Field; 2] =
            [poseidon2([encrypt_secret, -1], 2), poseidon2([mask_secret, -1], 2)];

        // init gamestate with the white player's secret hashes
        let mut game_state: GameState = GameState::default();
        game_state.mpc_state.user_encrypt_secret_hashes[0] = secret_hashes[0];
        game_state.mpc_state.user_mask_secret_hashes[0] = secret_hashes[1];

        let mut storage_state = ContractGameState { game_state, black_initialized: false };
        // TODO: if ContractGameState cannot be stored it needs to be emitted as a public event
        ChessContract::at(context.this_address()).create_game_public(storage_state).enqueue(
            &mut context,
        );
    }

    // write the game hash in mutable storage so it can be accessed by both players
    #[public]
    fn create_game_public(game_state: ContractGameState) {
        let counter_val = storage.counter.read();
        storage.pub_game_state.at(counter_val).write(game_state);
        storage.counter.write(counter_val + 1);
    }

    // join a new game as the black player
    #[private]
    fn join_game_private(
        game_id: Field,
        encrypt_secret: Field,
        mask_secret: Field,
        _contract_game_state: ContractGameState,
    ) {
        let secret_hashes = [poseidon2([encrypt_secret, -1], 2), poseidon2([mask_secret, -1], 2)];
        let mut contract_game_state = _contract_game_state;
        assert(contract_game_state.black_initialized == false);
        let mut game_state: GameState = contract_game_state.game_state;

        game_state.mpc_state.user_encrypt_secret_hashes[1] = secret_hashes[0];
        game_state.mpc_state.user_mask_secret_hashes[1] = secret_hashes[1];
        let mut storage_state = ContractGameState { game_state, black_initialized: true };
        ChessContract::at(context.this_address())
            .join_game_public(game_id, contract_game_state, storage_state)
            .enqueue(&mut context);
    }

    #[public]
    fn join_game_public(game_id: Field, old_game: ContractGameState, new_game: ContractGameState) {
        let stored_game = storage.pub_game_state.at(game_id).read();
        assert(stored_game.hash() == old_game.hash());

        storage.pub_game_state.at(game_id).write(new_game);
    }
}
