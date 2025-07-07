use dep::aztec::macros::aztec;

mod test;

#[aztec]
pub contract ChessContract {
    use dep::aztec::{
        macros::{functions::{initializer, private, public}, notes::note, storage::storage},
        protocol_types::{traits::{Deserialize, Packable, Serialize}, utils::arrays::subarray},
        state_vars::{Map, PublicMutable},
    };
    use fog_of_war_chess::{GameState, RoundMpcState, RoundState, UserOutputState};
    use std::embedded_curve_ops::EmbeddedCurvePoint;
    use std::hash::poseidon2::Poseidon2::hash as poseidon2;

    type Point = EmbeddedCurvePoint;

    global NUM_PARTICIPANTS: u32 = 2;
    global NUM_ENTRIES: u32 = 64;

    pub struct ContractGameState {
        pub game_state: GameState,
        pub black_initialized: bool,
    }

    impl Serialize<1 + NUM_PARTICIPANTS + NUM_PARTICIPANTS + NUM_PARTICIPANTS * (NUM_ENTRIES * 2 + 3 * NUM_ENTRIES + NUM_PARTICIPANTS * (3 * NUM_ENTRIES)) + 1> for ContractGameState {
        fn serialize(
            self,
        ) -> [Field; 1 + NUM_PARTICIPANTS + NUM_PARTICIPANTS + NUM_PARTICIPANTS * (NUM_ENTRIES * 2 + 3 * NUM_ENTRIES + NUM_PARTICIPANTS * (3 * NUM_ENTRIES)) + 1] {
            let mut game_state_serialized = [0; _];
            let POINT_FIELD_SIZE: u32 = 3;
            let CYPHERTEXT_FIELD_SIZE: u32 = 2;
            let mut offset = 0;
            game_state_serialized[offset] = self.game_state.mpc_state.round_number as Field;
            offset += 1;
            for i in 0..NUM_PARTICIPANTS {
                game_state_serialized[offset + i] =
                    self.game_state.mpc_state.user_encrypt_secret_hashes[i];
                game_state_serialized[offset + NUM_PARTICIPANTS + i] =
                    self.game_state.mpc_state.user_mask_secret_hashes[i];
            }
            offset += 2 * NUM_PARTICIPANTS;

            for i in 0..NUM_PARTICIPANTS {
                let previous_output_state = self.game_state.mpc_state.previous_output_states[i];
                for j in 0..NUM_ENTRIES * CYPHERTEXT_FIELD_SIZE {
                    game_state_serialized[offset + j] = previous_output_state.ciphertext.data[j];
                }
                offset += NUM_ENTRIES * CYPHERTEXT_FIELD_SIZE;

                for j in 0..NUM_ENTRIES {
                    game_state_serialized[offset + j * POINT_FIELD_SIZE] =
                        previous_output_state.mask_commitments[j].x;
                    game_state_serialized[offset + j * POINT_FIELD_SIZE + 1] =
                        previous_output_state.mask_commitments[j].y;
                    game_state_serialized[offset + j * POINT_FIELD_SIZE + 2] =
                        previous_output_state.mask_commitments[j].is_infinite as Field;
                }
                offset += NUM_ENTRIES * POINT_FIELD_SIZE;

                for k in 0..NUM_PARTICIPANTS {
                    let user_updated_mask_commitment =
                        previous_output_state.user_updated_mask_commitments[k];
                    for l in 0..NUM_ENTRIES {
                        game_state_serialized[offset + l * POINT_FIELD_SIZE] =
                            user_updated_mask_commitment[l].x;
                        game_state_serialized[offset + l * POINT_FIELD_SIZE + 1] =
                            user_updated_mask_commitment[l].y;
                        game_state_serialized[offset + l * POINT_FIELD_SIZE + 2] =
                            user_updated_mask_commitment[l].is_infinite as Field;
                    }
                    offset += NUM_ENTRIES * POINT_FIELD_SIZE;
                }
            }
            game_state_serialized[offset] = self.black_initialized as Field;
            game_state_serialized
        }
    }

    impl Deserialize<1 + NUM_PARTICIPANTS + NUM_PARTICIPANTS + NUM_PARTICIPANTS * (NUM_ENTRIES * 2 + 3 * NUM_ENTRIES + NUM_PARTICIPANTS * (3 * NUM_ENTRIES)) + 1> for ContractGameState {
        fn deserialize(
            fields: [Field; 1 + NUM_PARTICIPANTS + NUM_PARTICIPANTS + NUM_PARTICIPANTS * (NUM_ENTRIES * 2 + 3 * NUM_ENTRIES + NUM_PARTICIPANTS * (3 * NUM_ENTRIES)) + 1],
        ) -> Self {
            let POINT_FIELD_SIZE: u32 = 3;
            let CYPHERTEXT_FIELD_SIZE: u32 = 2;
            let mut offset = 0;
            let game_ended = fields[offset] as bool;
            offset += 1;
            let move_count = fields[offset];
            offset += 1;
            let round_number = fields[offset] as u32;
            offset += 1;
            let user_encrypt_secret_hashes = subarray(fields, offset);
            offset += NUM_PARTICIPANTS;
            let user_mask_secret_hashes = subarray(fields, offset);

            let previous_output_states = [UserOutputState::<64, 2>::default(); 2];

            for i in 0..NUM_PARTICIPANTS {
                let mut previous_output_state = previous_output_states[i];
                for j in 0..NUM_ENTRIES * CYPHERTEXT_FIELD_SIZE {
                    previous_output_state.ciphertext.data[j] = fields[offset + j];
                }
                offset += NUM_ENTRIES * CYPHERTEXT_FIELD_SIZE;

                let mut mask_commitments = previous_output_state.mask_commitments;
                for j in 0..NUM_ENTRIES {
                    mask_commitments[j] = Point {
                        x: fields[offset + j * POINT_FIELD_SIZE],
                        y: fields[offset + j * POINT_FIELD_SIZE + 1],
                        is_infinite: fields[offset + j * POINT_FIELD_SIZE + 2] as bool,
                    };
                }
                offset += NUM_ENTRIES * POINT_FIELD_SIZE;

                let mut user_updated_mask_commitments =
                    previous_output_state.user_updated_mask_commitments;
                for k in 0..NUM_PARTICIPANTS {
                    for l in 0..NUM_ENTRIES {
                        user_updated_mask_commitments[k][l] = Point {
                            x: fields[offset + l * POINT_FIELD_SIZE],
                            y: fields[offset + l * POINT_FIELD_SIZE + 1],
                            is_infinite: fields[offset + l * POINT_FIELD_SIZE + 2] as bool,
                        };
                    }
                    offset += NUM_ENTRIES * POINT_FIELD_SIZE;
                }
            }

            let black_initialized = fields[offset] as bool;

            ContractGameState {
                game_state: GameState {
                    game_ended: game_ended,
                    move_count: move_count,
                    mpc_state: RoundMpcState {
                        round_number: round_number,
                        user_encrypt_secret_hashes: user_encrypt_secret_hashes,
                        user_mask_secret_hashes: user_mask_secret_hashes,
                        previous_output_states: previous_output_states,
                    },
                },
                black_initialized: black_initialized,
            }
        }
    }

    impl Packable<1 + NUM_PARTICIPANTS + NUM_PARTICIPANTS + NUM_PARTICIPANTS * (NUM_ENTRIES * 2 + 3 * NUM_ENTRIES + NUM_PARTICIPANTS * (3 * NUM_ENTRIES)) + 1> for ContractGameState {
        fn pack(
            self,
        ) -> [Field; 1 + NUM_PARTICIPANTS + NUM_PARTICIPANTS + NUM_PARTICIPANTS * (NUM_ENTRIES * 2 + 3 * NUM_ENTRIES + NUM_PARTICIPANTS * (3 * NUM_ENTRIES)) + 1] {
            self.serialize()
        }

        fn unpack(
            fields: [Field; 1 + NUM_PARTICIPANTS + NUM_PARTICIPANTS + NUM_PARTICIPANTS * (NUM_ENTRIES * 2 + 3 * NUM_ENTRIES + NUM_PARTICIPANTS * (3 * NUM_ENTRIES)) + 1],
        ) -> Self {
            ContractGameState::deserialize(fields)
        }
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
