use dep::aztec::macros::aztec;

mod test;


#[aztec]
pub contract ChessContract {
use fog_of_war_chess::{GameState};
    use dep::aztec:: macros::{
        functions::{initializer, private, public}, 
        storage::storage,
        notes::note
    };
    use dep::aztec::protocol_types::{ traits::{Deserialize, Packable, Serialize}};
    use dep::aztec::prelude::{AztecAddress, Map, PublicMutable};
    use std::hash::poseidon2::Poseidon2::hash as poseidon2;


    #[derive(Serialize)]
    pub struct ContractGameState{
        pub game_state: GameState,
        pub black_initialized: bool
    }

    impl ContractGameState {
        pub fn hash(self) -> Field {
            poseidon2([self.black_initialized as Field, self.game_state.hash()], 2)
        }
    }

    #[storage]
    struct Storage<Context> {
        counter: PublicMutable<Field, Context>,// used to create game IDs
        // TODO: I want this to be Map<Field, PublicMutable<ContractGameState, Context>, Context>,
        pub_game_state_hashes: Map<Field, PublicMutable<Field, Context>, Context>,
    }

    #[public]
    #[initializer]
    fn constructor() {
        storage.counter.write(1);
    }

    // entry point for creating a game. For now creator is always white
    #[private]
    fn create_game_private(encrypt_secret: Field, mask_secret: Field)
    {
        let secret_hashes: [Field; 2] = [poseidon2([encrypt_secret, -1], 2), poseidon2([mask_secret, -1], 2)];
        
        // init gamestate with the white player's secret hashes
        let mut game_state: GameState = GameState::default();
        game_state.mpc_state.user_encrypt_secret_hashes[0] = secret_hashes[0];
        game_state.mpc_state.user_mask_secret_hashes[0] = secret_hashes[1];

        let mut storage_state: ContractGameState = ContractGameState{
            game_state,
            black_initialized: false
        };
        // TODO: if ContractGameState cannot be stored it needs to be emitted as a public event
        ChessContract::at(context.this_address()).create_game_public(storage_state.hash()).enqueue(
            &mut context,
        );
    }

    // write the game hash in mutable storage so it can be accessed by both players
    #[public]
    fn create_game_public(game_state_hash: Field)
    {
        let counter_val = storage.counter.read();
        storage.pub_game_state_hashes.at(counter_val).write(game_state_hash);
        storage.counter.write(counter_val + 1);
    }

    // join a new game as the black player
    #[private]
    fn join_game_private(game_id: Field, encrypt_secret: Field, mask_secret: Field, _contract_game_state: ContractGameState)
    {
        let secret_hashes: [Field; 2] = [poseidon2([encrypt_secret, -1], 2), poseidon2([mask_secret, -1], 2)];
        let mut contract_game_state = _contract_game_state;
        let old_game_hash = contract_game_state.hash();
        assert(contract_game_state.black_initialized == false);
            let mut game_state: GameState = contract_game_state.game_state;

        game_state.mpc_state.user_encrypt_secret_hashes[1] = secret_hashes[0];
        game_state.mpc_state.user_mask_secret_hashes[1] = secret_hashes[1];
        let mut storage_state: ContractGameState = ContractGameState{
            game_state,
            black_initialized: true
        };
        let mut new_game_hash = storage_state.hash();
        ChessContract::at(context.this_address()).join_game_public(game_id, old_game_hash, new_game_hash).enqueue(
            &mut context,
        );

    }

    #[public]
    fn join_game_public(game_id: Field, old_game_hash: Field, new_game_hash: Field)
    {
        let lhs = storage.pub_game_state_hashes.at(game_id).read();
        assert(lhs == old_game_hash);

        storage.pub_game_state_hashes.at(game_id).write(new_game_hash);

    }

    // #[private]
    // fn cast_vote(candidate: Field) {
    //     let msg_sender_npk_m_hash = get_public_keys(context.msg_sender()).npk_m.hash();

    //     let secret = context.request_nsk_app(msg_sender_npk_m_hash); // get secret key of caller of function
    //     let nullifier = std::hash::pedersen_hash([context.msg_sender().to_field(), secret]); // derive nullifier from sender and secret
    //     context.push_nullifier(nullifier);
    //     ChessContract::at(context.this_address()).add_to_tally_public(candidate).enqueue(
    //         &mut context,
    //     );
    //     add_to_tally_public(candidate);
    // }

    // #[public]
    // #[internal]
    // fn add_to_tally_public(candidate: Field) {
    //     // assert(storage.vote_ended.read() == false, "Vote has ended"); // assert that vote has not ended
    //     // let new_tally = storage.tally.at(candidate).read() + 1;
    //     // storage.tally.at(candidate).write(new_tally);
    // }

    // #[public]
    // fn end_vote() {
    //     // assert(storage.admin.read().eq(context.msg_sender()), "Only admin can end votes"); // assert that caller is admin
    //     // storage.vote_ended.write(true);
    // }

    // #[utility]
    // unconstrained fn get_vote(candidate: Field) -> Field {
    //     // storage.tally.at(candidate).read()
    // }
}