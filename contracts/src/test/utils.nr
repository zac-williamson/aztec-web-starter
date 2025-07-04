use dep::aztec::{prelude::AztecAddress, test::helpers::test_environment::TestEnvironment};

use crate::ChessContract;

pub unconstrained fn setup() -> (&mut TestEnvironment, AztecAddress, AztecAddress) {
    let mut env = TestEnvironment::new();

    let admin = env.create_account(1);

    let initializer_call_interface = ChessContract::interface().constructor();
    let voting_contract = env.deploy_self("ChessContract").with_public_void_initializer(
        admin,
        initializer_call_interface,
    );

    env.advance_block_by(1);
    (&mut env, voting_contract.to_address(), admin)
}