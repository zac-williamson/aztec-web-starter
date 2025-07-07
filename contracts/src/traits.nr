use crate::ChessContract::ContractGameState;
use dep::aztec::protocol_types::{
    traits::{Deserialize, Packable, Serialize},
    utils::arrays::subarray,
};
use fog_of_war_chess::{GameState, RoundMpcState, RoundState, UserOutputState};
use std::embedded_curve_ops::EmbeddedCurvePoint;

type Point = EmbeddedCurvePoint;

global NUM_PARTICIPANTS: u32 = 2;
global NUM_ENTRIES: u32 = 64;
global POINT_FIELD_SIZE: u32 = 3;
global CYPHERTEXT_FIELD_SIZE: u32 = 2;
global SERDE_SIZE: u32 = 1
    + NUM_PARTICIPANTS
    + NUM_PARTICIPANTS
    + NUM_PARTICIPANTS * (NUM_ENTRIES * 2 + 3 * NUM_ENTRIES + NUM_PARTICIPANTS * (3 * NUM_ENTRIES))
    + 1;

impl Eq for ContractGameState {
    fn eq(self, other: Self) -> bool {
        let mut previous_output_states_equal = true;
        for i in 0..NUM_PARTICIPANTS {
            let self_previous_output_state = self.game_state.mpc_state.previous_output_states[i];
            let other_previous_output_state = other.game_state.mpc_state.previous_output_states[i];
            previous_output_states_equal = previous_output_states_equal
                & (
                    self_previous_output_state.ciphertext.data
                        == other_previous_output_state.ciphertext.data
                )
                & (
                    self_previous_output_state.mask_commitments
                        == other_previous_output_state.mask_commitments
                )
                & (
                    self_previous_output_state.user_updated_mask_commitments
                        == other_previous_output_state.user_updated_mask_commitments
                );
        }
        previous_output_states_equal
            & (self.game_state.game_ended == other.game_state.game_ended)
            & (self.game_state.move_count == other.game_state.move_count)
            & (self.game_state.mpc_state.round_number == other.game_state.mpc_state.round_number)
            & (
                self.game_state.mpc_state.user_encrypt_secret_hashes
                    == other.game_state.mpc_state.user_encrypt_secret_hashes
            )
            & (
                self.game_state.mpc_state.user_mask_secret_hashes
                    == other.game_state.mpc_state.user_mask_secret_hashes
            )
            & (self.black_initialized == other.black_initialized)
    }
}

impl Serialize<SERDE_SIZE> for ContractGameState {
    fn serialize(self) -> [Field; SERDE_SIZE] {
        let mut game_state_serialized = [0; _];
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

impl Deserialize<SERDE_SIZE> for ContractGameState {
    fn deserialize(fields: [Field; SERDE_SIZE]) -> Self {
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

impl Packable<SERDE_SIZE> for ContractGameState {
    fn pack(self) -> [Field; SERDE_SIZE] {
        self.serialize()
    }

    fn unpack(fields: [Field; SERDE_SIZE]) -> Self {
        ContractGameState::deserialize(fields)
    }
}
