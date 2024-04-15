use bindings::dfmm::DFMM;

use self::pool::BaseConfig;
use super::*;
use crate::{
    behaviors::{deployer::DeploymentData, token_admin::Response},
    pool::Pool,
};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Creator<S: State> {
    pub token_admin: String,
    pub data: S::Data,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Config<P: PoolType> {
    pub base_config: BaseConfig,
    pub params: P::Parameters,
    pub allocation_data: P::AllocationData,
    pub token_list: Vec<String>,
}

impl<P: PoolType> State for Config<P> {
    type Data = Self;
}

#[async_trait::async_trait]
impl<P> Behavior<()> for Creator<Config<P>>
where
    P: PoolType + Send + Sync + 'static,
    P::StrategyContract: Send,
    P::SolverContract: Send,
{
    type Processor = ();
    async fn startup(
        &mut self,
        client: Arc<ArbiterMiddleware>,
        mut messager: Messager,
    ) -> Result<Option<(Self::Processor, EventStream<()>)>> {
        // Receive the `DeploymentData` from the `Deployer` agent and use it to get the
        // contracts.
        let deployment_data = messager.get_next::<DeploymentData>().await?.data;
        let (strategy_contract, solver_contract) =
            P::get_contracts(&deployment_data, client.clone());
        let dfmm = DFMM::new(deployment_data.dfmm, client.clone());

        // Get the intended tokens for the pool and do approvals.
        let mut tokens = Vec::new();
        for tkn in self.data.token_list.drain(..) {
            messager
                .send(
                    To::Agent(self.token_admin.clone()),
                    TokenAdminQuery::AddressOf(tkn.clone()),
                )
                .await
                .unwrap();
            let token = ArbiterToken::new(
                messager.get_next::<eAddress>().await.unwrap().data,
                client.clone(),
            );
            messager
                .send(
                    To::Agent(self.token_admin.clone()),
                    TokenAdminQuery::MintRequest(MintRequest {
                        token: tkn,
                        mint_to: client.address(),
                        mint_amount: 100_000_000_000,
                    }),
                )
                .await
                .unwrap();
            assert_eq!(
                messager.get_next::<Response>().await.unwrap().data,
                Response::Success
            );
            token
                .approve(dfmm.address(), MAX)
                .send()
                .await
                .unwrap()
                .await
                .unwrap();

            tokens.push(token);
        }
        debug!("creating pool...");
        // Create the pool.
        let pool = Pool::<P>::new(
            self.data.base_config.clone(),
            self.data.params.clone(),
            self.data.allocation_data.clone(),
            strategy_contract,
            solver_contract,
            dfmm,
            tokens,
        )
        .await?;

        debug!("Pool created!\n {:#?}", pool);

        let pool_creation = PoolCreation::<P> {
            id: pool.id,
            params: self.data.params.clone(),
            allocation_data: self.data.allocation_data.clone(),
        };
        messager.send(To::All, pool_creation).await.unwrap();
        Ok(None)
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, Eq, PartialEq)]
pub struct PoolCreation<P: PoolType> {
    pub id: eU256,
    pub params: P::Parameters,
    pub allocation_data: P::AllocationData,
}
