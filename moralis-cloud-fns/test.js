/* eslint-disable prettier/prettier */
/* eslint-disable no-undef */
Moralis.Cloud.define("test", async (request) => {
  
    const logger = Moralis.Cloud.getLogger();
    logger.info("Hello World"); 

    let contract;
    try {
        web3 = Moralis.web3ByChain("localdevchain");
        contract = new web3.eth.Contract(Moralis.Web3.abis.erc20, '0x5FbDB2315678afecb367f032d93F642f64180aa3');
        logger.info("here");    
    } catch(e) { 
        logger.info("Error:", JSON.stringify(e));    
    }

    const errors = []
    let name = null;
    let symbol = null;

    try
    {
        name = await contract.methods.name().call();
        logger.info("after name"); 
        symbol = await contract.methods.symbol().call();
        logger.info("after symbol"); 
    }
    catch(e) {
        errors.push(e.message);
    }    

    return {
        // "output": contract.symbol()
        // text": `Hello ${JSON.stringify(request.params)}! `,
        name: name,
        symbol: symbol,
        errors: errors
    }
      
  });