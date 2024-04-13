use arbiter_engine::{agent::Agent, world::World};
use dfmm_kit::{
    behaviors::{
        creator::{self, Creator},
        deployer::Deployer,
        token_admin::{self, TokenAdmin},
    },
    pool::{
        constant_sum::{ConstantSumAllocationData, ConstantSumParams, ConstantSumPool},
        BaseConfig,
    },
    TokenData,
};
use ethers::types::U256 as eU256;
use tracing::Level;
use tracing_subscriber::FmtSubscriber;

pub const WAD: eU256 = eU256([1_000_000_000_000_000_000, 0, 0, 0]);
pub const DEPLOYER: &str = "deployer";
pub const TOKEN_ADMIN: &str = "token_admin";
pub const CREATOR: &str = "creator";

pub const TOKEN_X_NAME: &str = "Token X";
pub const TOKEN_X_SYMBOL: &str = "TKNX";
pub const TOKEN_X_DECIMALS: u8 = 18;

pub const TOKEN_Y_NAME: &str = "Token Y";
pub const TOKEN_Y_SYMBOL: &str = "TKNY";
pub const TOKEN_Y_DECIMALS: u8 = 18;

pub const PRICE: eU256 = WAD;
pub const RESERVE_X: eU256 = WAD;
pub const RESERVE_Y: eU256 = WAD;

pub fn log() {
    tracing::subscriber::set_global_default(
        FmtSubscriber::builder()
            .with_max_level(Level::DEBUG)
            .pretty()
            .finish(),
    )
    .unwrap();
}

pub fn spawn_deployer(world: &mut World) {
    world.add_agent(Agent::builder(DEPLOYER).with_behavior(Deployer {}));
}

pub fn spawn_token_admin(world: &mut World) {
    let token_x = TokenData {
        name: TOKEN_X_NAME.to_owned(),
        symbol: TOKEN_X_SYMBOL.to_owned(),
        decimals: TOKEN_X_DECIMALS,
        address: None,
    };
    let token_y = TokenData {
        name: TOKEN_Y_NAME.to_owned(),
        symbol: TOKEN_Y_SYMBOL.to_owned(),
        decimals: TOKEN_Y_DECIMALS,
        address: None,
    };
    let data = token_admin::Config {
        token_data: vec![token_x, token_y],
    };
    world.add_agent(
        Agent::builder(TOKEN_ADMIN).with_behavior(TokenAdmin::<token_admin::Config> { data }),
    );
}

pub fn spawn_creator(world: &mut World) {
    world.add_agent(Agent::builder(CREATOR).with_behavior(Creator::<
        creator::Config<ConstantSumPool>,
    > {
        token_admin: TOKEN_ADMIN.to_owned(),
        data: creator::Config {
            params: ConstantSumParams { price: PRICE },
            token_list: vec![TOKEN_X_NAME.to_owned(), TOKEN_Y_NAME.to_owned()],
            base_config: BaseConfig {
                name: "Test Pool".to_string(),
                symbol: "TP".to_string(),
                swap_fee: 10000.into(),
                controller_fee: 0.into(),
            },
            allocation_data: ConstantSumAllocationData {
                reserve_x: RESERVE_X,
                reserve_y: RESERVE_Y,
            },
        },
    }));
}
